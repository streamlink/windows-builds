#!/usr/bin/env bash
set -eo pipefail

# Generate dependency lockfiles for specific installer builds (see config.json),
# as Streamlink doesn't have its own dependency lockfiles, eg. via pipenv.
# The lockfiles are split into sdist and wheel sections, because
# pynsist requires us to build wheels for packages where no wheels are available.
#
# Unfortunately, pip 22 still hasn't implemented any kind of features for building lockfiles,
# like the proposed `pip resolve` command or the `pip download --resolve --dry-run` args,
# so generating lockfiles for different platforms requires ugly workarounds like this one.
#
# Streamlink's Linux AppImage lockfile generator script at least can make use of native
# python environments inside docker containers when resolving packages for the different
# target platforms. This script unfortunately can not and relies on the `pip download`
# command with specific platform filter arguments set and calculating the rest manually.


BUILDNAME="${1}"
GITREPO="${2}"
GITREF="${3}"
OPT_DEPSPEC=("${@}")
OPT_DEPSPEC=("${OPT_DEPSPEC[@]:3}")

declare -A DEPS=(
  [gawk]=gawk
  [jq]=jq
  [yq]=yq
  [mktemp]=mktemp
  [pip]=pip
  [sha256sum]=sha256sum
)

PACKAGES_IGNORE=(
  streamlink
)

PIP_ARGS=(
  --isolated
  --disable-pip-version-check
  --no-cache-dir
)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(readlink -f "${0}")")
CONFIG="${ROOT}/config.yml"


# ----


SELF=$(basename "$(readlink -f "${0}")")
log() {
  echo "[${SELF}] $@"
}
err() {
  log >&2 "$@"
  exit 1
}


for dep in "${!DEPS[@]}"; do
  command -v "${dep}" 2>&1 >/dev/null || err "Missing dependency: ${DEPS["${dep}"]}"
done

CONFIGJSON=$(cat "${CONFIG}")

yq -e ".builds[\"${BUILDNAME}\"]" >/dev/null <<< "${CONFIGJSON}" \
  || err "Unsupported build name"

read -r gitrepo gitref \
  < <(yq -r '.git | "\(.repo) \(.ref)"' <<< "${CONFIGJSON}")
read -r implementation pythonversion platform \
  < <(yq -r ".builds[\"${BUILDNAME}\"] | \"\(.implementation) \(.pythonversion) \(.platform)\"" <<< "${CONFIGJSON}")

gitrepo="${GITREPO:-${gitrepo}}"
gitref="${GITREF:-${gitref}}"

dependency_override=($(yq -r ".builds[\"${BUILDNAME}\"].dependency_override[]" <<< "${CONFIGJSON}"))


# ----


TEMP=$(mktemp -d) && trap "rm -rf '${TEMP}'" EXIT || exit 255

DIR_REPO="${TEMP}/source.git"


get_sources() {
  log "Getting sources"
  git \
    -c advice.detachedHead=false \
    clone \
    "${gitrepo}" \
    "${DIR_REPO}"

  log "Commit information"
  GIT_PAGER=cat git \
    -C "${DIR_REPO}" \
    log \
    -1 \
    --pretty=full \
    "${gitref}"
}

remove_ignored_packages() {
  log "Removing ignored packages"
  ( shopt -s nullglob; set -x; rm -f -- ${PACKAGES_IGNORE[@]/%/-*}; )
}

# Generating a valid lockfile requires the following steps
# 1. Get all sdist tarballs and all wheels for the input packages and their dependencies
#    while filtering wheels by the target platform.
# 2. Calculate checksums of all downloads.
# 3. Ignore input+unrelated packages.
# 4. Check if there are version string mismatches between sdist and wheel package downloads, and prefer sdist in that case.
#    The reason for that is that Streamlink's pycountry dependency for example does not publish wheels except for old releases.
#    The assumtion is that packages always release sdist tarballs on pypi, and that those source distributions of packages
#    without wheels don't require platform specific build processes when building the wheels later on.
# 5. Output sorted lockfile JSON data with package names, versions and checksums.
get_deps() {
  pushd "${TEMP}"

  log "Downloading sdists"
  pip download \
    "${PIP_ARGS[@]}" \
    --no-binary=:all: \
    "git+file://${DIR_REPO}@${gitref}" \
    "${dependency_override[@]}" \
    "${OPT_DEPSPEC[@]}"
  remove_ignored_packages

  log "Downloading wheels"
  pip download \
    "${PIP_ARGS[@]}" \
    --only-binary=:all: \
    --implementation="${implementation}" \
    --python-version="${pythonversion}" \
    --platform="${platform}" \
    "git+file://${DIR_REPO}@${gitref}" \
    "${dependency_override[@]}" \
    "${OPT_DEPSPEC[@]}"
  remove_ignored_packages

  log "Generating lockfile for build ${BUILDNAME}"
  sha256sum * \
    | gawk '
      function output(type, name, version, hash) {
        print "{\"type\": \"" type "\", \"name\": \"" name "\", \"requirement\": \"" version " --hash=sha256:" hash "\"}"
      }
      match($2, /^(.+)-([^-]+)\.tar\.gz$/, m) {
        sdists[m[1]] = m[2]
        sdist_hashes[m[1]] = $1
      }
      match($2, /^([^-]+)-([^-]+)-.+\.whl$/, m) {
        wheels[m[1]] = m[2]
        wheel_hashes[m[1]] = $1
      }
      END {
        for (pkg in sdists) {
          _pkg = pkg
          gsub(/-/, "_", _pkg)
          if (sdists[pkg] == wheels[_pkg]) {
            continue
          }
          delete wheels[_pkg]
          output("sdist", pkg, sdists[pkg], sdist_hashes[pkg])
        }
        for (pkg in wheels) {
          output("wheel", pkg, wheels[pkg], wheel_hashes[pkg])
        }
      }
    ' \
    | jq -ns '
      inputs as $data
      | {
        sdists: (
            [$data[] | select(.type == "sdist")]
          | sort_by(.name)
          | [.[] | {key: .name, value: .requirement}] | from_entries
        ),
        wheels: (
            [$data[] | select(.type == "wheel")]
          | sort_by(.name)
          | [.[] | {key: .name, value: .requirement}] | from_entries
        )
      }
    ' \
    | yq -y -C '{"dependencies": .}'
}


build() {
  get_sources
  get_deps
}

build
