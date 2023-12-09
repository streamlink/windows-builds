#!/usr/bin/env bash
set -eo pipefail

BUILDNAME="${1}"
GITREPO="${2}"
GITREF="${3}"
OPT_DEPSPEC=("${@}")
OPT_DEPSPEC=("${OPT_DEPSPEC[@]:3}")

declare -A DEPS=(
  [jq]=jq
  [yq]=yq
  [mktemp]=mktemp
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

get_deps() {
  pushd "${TEMP}"

  log "Downloading wheels"
  python -m pip install \
    --disable-pip-version-check \
    --root-user-action=ignore \
    --isolated \
    --no-cache-dir \
    --check-build-dependencies \
    --ignore-installed \
    --only-binary=:all: \
    --implementation="${implementation}" \
    --python-version="${pythonversion}" \
    --platform="${platform}" \
    --target=. \
    --dry-run \
    --report=report.json \
    "git+file://${DIR_REPO}@${gitref}" \
    "${dependency_override[@]}" \
    "${OPT_DEPSPEC[@]}"

  log "Generating lockfile for build ${BUILDNAME}"
  yq -y -C \
    '
      [
       .install[]
       | select(.is_direct != true)
       | .download_info.archive_info.hash |= sub("^(?<hash>[^=]+)="; "\(.hash):")
       | {
         key: .metadata.name,
         value: "\(.metadata.version) --hash=\(.download_info.archive_info.hash)"
       }
      ]
      | sort_by(.key | ascii_upcase)
      | from_entries
      | {"dependencies": .}
    ' \
    report.json
}


build() {
  get_sources
  get_deps
}

build
