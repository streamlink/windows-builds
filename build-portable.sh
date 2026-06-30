#!/usr/bin/env bash
# shellcheck disable=SC2016

set -euo pipefail

BUILDNAME="${1:-}"
GITREPO="${2:-}"
GITREF="${3:-}"

declare -A DEPS=(
  [curl]=curl
  [git]=git
  [jq]=jq
  [yq]=yq
  [pip]=pip
  [unzip]=unzip
)

GIT_FETCHDEPTH=300

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(readlink -f "${0}")")
CONFIG="${ROOT}/config.yml"
CONFIG_PORTABLE="${ROOT}/portable.yml"
DIR_CACHE="${ROOT}/cache"
DIR_DIST="${ROOT}/dist"


# ----


SELF=$(basename "$(readlink -f "${0}")")
log() {
  echo "[${SELF}]" "${@}"
}
err() {
  log >&2 "${@}"
  exit 1
}

[[ "${CI:-}" ]] || [[ "${VIRTUAL_ENV:-}" ]] || err "Can only be built in a virtual environment"

for dep in "${!DEPS[@]}"; do
  command -v "${dep}" >/dev/null 2>&1 || err "${DEPS["${dep}"]} is required to build the installer. Aborting."
done

[[ -f "${CONFIG}" ]] \
  || err "Missing config file: ${CONFIG}"
CONFIGJSON=$(cat "${CONFIG}")

if [[ -n "${BUILDNAME}" ]]; then
  yq -e --arg b "${BUILDNAME}" '.builds[$b]' >/dev/null 2>&1 <<< "${CONFIGJSON}" \
    || err "Invalid build name"
else
  BUILDNAME=$(yq -r '.builds | keys | first' <<< "${CONFIGJSON}")
fi

read -r appname apprel \
  < <(yq -r '.app | "\(.name) \(.rel)"' <<< "${CONFIGJSON}")
read -r gitrepo gitref \
  < <(yq -r '.git | "\(.repo) \(.ref)"' <<< "${CONFIGJSON}")
read -r implementation pythonversion platform pythonplatform \
  < <(yq -r --arg b "${BUILDNAME}" '.builds[$b] | "\(.implementation) \(.pythonversion) \(.platform) \(.pythonplatform)"' <<< "${CONFIGJSON}")
read -r _pythonversionfull pythonfilename pythonurl pythonsha256 \
  < <(yq -r --arg b "${BUILDNAME}" '.builds[$b].pythonembed | "\(.version) \(.filename) \(.url) \(.sha256)"' <<< "${CONFIGJSON}")

gitrepo="${GITREPO:-${gitrepo}}"
gitref="${GITREF:-${gitref}}"


# ----


# shellcheck disable=SC2064
TEMP=$(mktemp -d) && trap "rm -rf '${TEMP}'" EXIT || exit 255

DIR_REPO="${TEMP}/source.git"
DIR_BUILD="${TEMP}/build"
DIR_ASSETS="${TEMP}/assets"
DIR_BIN="${DIR_BUILD}/bin"
DIR_PKGS="${DIR_BUILD}/pkgs"

mkdir -p \
  "${DIR_CACHE}" \
  "${DIR_DIST}" \
  "${DIR_BUILD}" \
  "${DIR_ASSETS}" \
  "${DIR_BIN}" \
  "${DIR_PKGS}"


get_sources() {
  log "Getting sources"
  mkdir -p "${DIR_REPO}"
  pushd "${DIR_REPO}"

  # TODO: re-investigate and optimize this
  git clone --depth 1 "${gitrepo}" .
  git fetch origin --depth "${GIT_FETCHDEPTH}" "${gitref}:branch"
  git ls-remote --tags --sort=version:refname 2>&- \
    | awk "END{printf \"+%s:%s\\n\",\$2,\$2}" \
    | git fetch origin --depth="${GIT_FETCHDEPTH}"
  git -c advice.detachedHead=false checkout --force branch
  git fetch origin --depth="${GIT_FETCHDEPTH}" --update-shallow

  log "Commit information"
  git describe --tags --long --dirty
  git --no-pager log -1 --pretty=full

  popd
}

get_python() {
  local filepath="${DIR_CACHE}/${pythonfilename}"
  if ! [[ -f "${filepath}" ]]; then
    log "Downloading Python"
    curl -SLo "${filepath}" "${pythonurl}"
  fi
  log "Checking Python"
  sha256sum -c - <<< "${pythonsha256} ${filepath}"
}

get_assets() {
  local assetname
  while read -r assetname; do
    local filename url sha256
    read -r filename url sha256 \
      < <(yq -r --arg a "${assetname}" '.assets[$a] | "\(.filename) \(.url) \(.sha256)"' <<< "${CONFIGJSON}")
    if ! [[ -f "${DIR_CACHE}/${filename}" ]]; then
      log "Downloading asset: ${assetname}"
      curl -SLo "${DIR_CACHE}/${filename}" "${url}"
    fi
    log "Checking asset: ${assetname}"
    sha256sum -c - <<< "${sha256} ${DIR_CACHE}/${filename}"
  done < <(yq -r --arg b "${BUILDNAME}" '.builds[$b].assets[]' <<< "${CONFIGJSON}")
}

prepare_python() {
  log "Preparing Python"
  unzip "${DIR_CACHE}/${pythonfilename}" -d "${DIR_BUILD}/Python"
}

prepare_assets() {
  log "Preparing assets"
  local assetname
  while read -r assetname; do
    log "Preparing asset: ${assetname}"
    local type filename sourcedir targetdir
    read -r type filename sourcedir targetdir \
      < <(yq -r --arg a "${assetname}" '.assets[$a] | "\(.type) \(.filename) \(.sourcedir) \(.targetdir)"' <<< "${CONFIGJSON}")
    case "${type}" in
      zip)
        mkdir -p "${DIR_ASSETS}/${assetname}"
        unzip "${DIR_CACHE}/${filename}" -d "${DIR_ASSETS}/${assetname}"
        sourcedir="${DIR_ASSETS}/${assetname}/${sourcedir}"
        ;;
      *)
        sourcedir="${DIR_CACHE}"
        ;;
    esac
    while read -r from to; do
      install -vDT "${sourcedir}/${from}" "${DIR_BUILD}/${targetdir}/${to}"
    done < <(yq -r --arg a "${assetname}" '.assets[$a].files[] | "\(.from) \(.to)"' <<< "${CONFIGJSON}")
  done < <(yq -r --arg b "${BUILDNAME}" '.builds[$b].assets[]' <<< "${CONFIGJSON}")
}

prepare_files() {
  log "Copying license file with file extension"
  install -v "${DIR_REPO}/LICENSE" "${DIR_BUILD}/LICENSE.txt"
}

prepare_executables() {
  log "Preparing executables"
  TZ=UTC python ./build-portable-commands.py --config="${CONFIG_PORTABLE}" --target="${DIR_BIN}"
}

install_pkgs() {
  log "Installing packages"
  (
    set -x
    # Install dependencies first
    # workaroundception:
    # 1. uv (currently) doesn't let us reliably sync venvs for foreign platforms and/or different python versions,
    #    which means that we need to use good old pip, but uv's pip install interface can't be used, because it doesn't support
    #    setting --platform, --python-version and --implementation for choosing the right wheels from the package index,
    #    so we need to export the lockfile into the requirements.txt format, which pip understands
    #    https://docs.astral.sh/uv/reference/cli/#uv-sync--python-platform
    #    https://docs.astral.sh/uv/reference/cli/#uv-python-install
    # 2. pip 26.1 however STILL doesn't support environment markers for resolving dependencies, as the exported lockfile
    #    is platform agnostic, meaning dependencies with os_name=="nt" markers will be ignored by pip
    #    https://github.com/pypa/pip/issues/11664
    # 3. Therefore use uv's pip compile interface in order to resolve the right dependencies using uv's --python-platform
    #    argument, which is not available in uv export or uv sync
    #    https://github.com/astral-sh/uv/issues/17226
    #
    # ----
    #
    # 1. Translate uv.lock into requirements.txt
    # 2. Resolve platform-specific and python-version-specific dependencies
    # 3. Install them using pip (only wheels) and also choose a target dir, so we can skip setting up a temp venv
    uv export \
      --no-config \
      --verbose \
      --project "${DIR_REPO}" \
      --no-managed-python \
      --no-cache \
      --format requirements-txt \
      --frozen \
      --no-emit-project \
      --no-dev \
      --all-extras \
    | uv pip compile \
      --no-config \
      --verbose \
      --no-cache \
      --python-platform="${pythonplatform}" \
      --python-version="${pythonversion}" \
      --generate-hashes \
      - \
    > "${TEMP}/requirements.txt"
    pip install \
      --disable-pip-version-check \
      --no-cache-dir \
      --require-hashes \
      --only-binary=:all: \
      --platform="${platform}" \
      --python-version="${pythonversion}" \
      --implementation="${implementation}" \
      --no-deps \
      --target="${DIR_PKGS}" \
      --no-compile \
      --requirement="${TEMP}/requirements.txt"

    # Install the main application with its pinned build dependencies, using the same procedure as above
    uv export \
      --no-config \
      --verbose \
      --project "${DIR_REPO}" \
      --no-managed-python \
      --no-cache \
      --format requirements-txt \
      --frozen \
      --only-dev \
    | uv pip compile \
      --no-config \
      --verbose \
      --no-cache \
      --python-platform="${pythonplatform}" \
      --python-version="${pythonversion}" \
      --generate-hashes \
      - \
    > "${TEMP}/build-requirements.txt"
    pip install \
      --disable-pip-version-check \
      --use-feature inprocess-build-deps \
      --no-cache-dir \
      --platform="${platform}" \
      --python-version="${pythonversion}" \
      --implementation="${implementation}" \
      --no-deps \
      --target="${DIR_PKGS}" \
      --no-compile \
      --build-constraint="${TEMP}/build-requirements.txt" \
      "${DIR_REPO}"
  )

  log "Removing unneeded dist files"
  rm -rv "${DIR_PKGS:?}/bin" "${DIR_PKGS}"/*.dist-info/direct_url.json
  sed -i -E \
    -e '/^.+\.dist-info\/direct_url\.json,sha256=/d' \
    -e '/^\.\.\/\.\.\//d' \
    "${DIR_PKGS}"/*.dist-info/RECORD
}

build_portable() {
  log "Reading version string"

  local versionstring version
  versionstring="$(PYTHONPATH="${DIR_PKGS}" python -c "from importlib.metadata import version;print(version('${appname}'))")"

  # custom gitrefs that point to a tag should use the same file name format as builds from untagged commits
  if [[ -n "${GITREF}" && "${versionstring}" != *+* ]]; then
    local _commit
    _commit="$(git -C "${TEMP}/source.git" -c core.abbrev=7 rev-parse --short HEAD)"
    version="${versionstring%%+*}+0.g${_commit}"
  else
    version="${versionstring}"
  fi

  log "Updating modification times"
  local mtime
  [[ "${SOURCE_DATE_EPOCH:-}" ]] && mtime="@${SOURCE_DATE_EPOCH}" || mtime=now
  find "${DIR_BUILD}" -exec touch --no-dereference "--date=${mtime}" '{}' '+'

  log "Packaging portable build"
  local dist="${appname}-${version}-${apprel}-${BUILDNAME}"
  (
    cd "${TEMP}"
    mv "${DIR_BUILD}" "${dist}"
    find "./${dist}" \
      | LC_ALL=C sort \
      | TZ=UTC zip \
        --quiet \
        --latest-time \
        -9 \
        -X \
        -@ \
        "${DIR_DIST}/${dist}.zip"
  )
  sha256sum "${DIR_DIST}/${dist}.zip"
}


build() {
  log "Building ${BUILDNAME}, using git reference ${gitref}"
  get_sources
  get_python
  get_assets
  prepare_executables
  prepare_python
  prepare_assets
  prepare_files
  install_pkgs
  build_portable
  log "Success!"
}

build
