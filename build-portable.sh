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

PIP_ARGS=(
  --isolated
  --disable-pip-version-check
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
read -r implementation pythonversion platform \
  < <(yq -r --arg b "${BUILDNAME}" '.builds[$b] | "\(.implementation) \(.pythonversion) \(.platform)"' <<< "${CONFIGJSON}")
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

  git clone --depth 1 "${gitrepo}" .
  git fetch origin --depth "${GIT_FETCHDEPTH}" "${gitref}"
  git -c advice.detachedHead=false checkout --force "${gitref}"
  git ls-remote --tags --sort=version:refname 2>&- \
    | awk "END{printf \"+%s:%s\\n\",\$2,\$2}" \
    | git fetch origin --depth="${GIT_FETCHDEPTH}"
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
  unzip -q "${DIR_CACHE}/${pythonfilename}" -d "${DIR_BUILD}/Python"
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
  log "Installing wheels"
  pip install \
    "${PIP_ARGS[@]}" \
    --require-hashes \
    --only-binary=:all: \
    --platform="${platform}" \
    --python-version="${pythonversion}" \
    --implementation="${implementation}" \
    --no-deps \
    --target="${DIR_PKGS}" \
    --no-compile \
    --requirement=/dev/stdin \
    < <(yq -r --arg b "${BUILDNAME}" '.builds[$b].dependencies | to_entries[] | "\(.key)==\(.value)"' <<< "${CONFIGJSON}")

  log "Installing app"
  pip install \
    "${PIP_ARGS[@]}" \
    --no-cache-dir \
    --platform="${platform}" \
    --python-version="${pythonversion}" \
    --implementation="${implementation}" \
    --no-deps \
    --target="${DIR_PKGS}" \
    --no-compile \
    --upgrade \
    "${DIR_REPO}"

  log "Removing unneeded dist files"
  ( set -x; rm -r "${DIR_PKGS:?}/bin" "${DIR_PKGS}"/*.dist-info/direct_url.json; )
  sed -i -E \
    -e '/^.+\.dist-info\/direct_url\.json,sha256=/d' \
    -e '/^\.\.\/\.\.\//d' \
    "${DIR_PKGS}"/*.dist-info/RECORD
}

build_portable() {
  log "Reading version string"
  local versionstring versionplain versionmeta version

  versionstring="$(PYTHONPATH="${DIR_PKGS}" python -c "from importlib.metadata import version;print(version('${appname}'))")"
  versionplain="${versionstring%%+*}"
  versionmeta="${versionstring##*+}"

  # Not a custom git reference (assume that only tagged releases are used as source)
  # Use plain version string with app release number and no abbreviated commit ID
  if [[ -z "${GITREF}" ]]; then
    version="${versionplain}-${apprel}"

  # Custom ref -> tagged release (no build metadata in version string)
  # Add abbreviated commit ID to the plain version string to distinguish it from regular releases, set 0 as app release number
  elif [[ "${versionstring}" != *+* ]]; then
    version="${versionplain}-0-g$(git -c core.abbrev=7 -C "${DIR_REPO}" rev-parse --short HEAD)"

  # Custom ref -> arbitrary untagged commit (version string includes build metadata)
  # Translate into correct format
  else
    version="${versionplain}-${versionmeta/./-}"
  fi

  log "Updating modification times"
  local mtime
  [[ "${SOURCE_DATE_EPOCH:-}" ]] && mtime="@${SOURCE_DATE_EPOCH}" || mtime=now
  find "${DIR_BUILD}" -exec touch --no-dereference "--date=${mtime}" '{}' '+'

  log "Packaging portable build"
  local dist="${appname}-${version}-${BUILDNAME}"
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
