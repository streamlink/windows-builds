#!/usr/bin/env bash
set -eo pipefail

BUILDNAME="${1}"
GITREPO="${2}"
GITREF="${3}"

declare -A DEPS=(
  [curl]=curl
  [git]=git
  [jq]=jq
  [pip]=pip
  [unzip]=unzip
)

DISTS_IGNORE=(
  setuptools
)

PIP_ARGS=(
  --isolated
  --disable-pip-version-check
)

GIT_FETCHDEPTH=300

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(readlink -f "${0}")")
CONFIG="${ROOT}/config.json"
CONFIG_PORTABLE="${ROOT}/portable.json"
DIR_CACHE="${ROOT}/cache"
DIR_DIST="${ROOT}/dist"
DIR_FILES="${ROOT}/files"


# ----


SELF=$(basename "$(readlink -f "${0}")")
log() {
  echo "[${SELF}] ${@}"
}
err() {
  log >&2 "${@}"
  exit 1
}

[[ "${CI}" ]] || [[ "${VIRTUAL_ENV}" ]] || err "Can only be built in a virtual environment"

for dep in "${!DEPS[@]}"; do
  command -v "${dep}" 2>&1 >/dev/null || err "${DEPS["${dep}"]} is required to build the installer. Aborting."
done

[[ -f "${CONFIG}" ]] \
  || err "Missing config file: ${CONFIG}"
CONFIGJSON=$(cat "${CONFIG}")

[[ -n "${BUILDNAME}" ]] \
  && jq -e ".builds[\"${BUILDNAME}\"]" 2>&1 >/dev/null <<< "${CONFIGJSON}" \
  || err "Invalid build name"

read -r appname apprel \
  < <(jq -r '.app | "\(.name) \(.rel)"' <<< "${CONFIGJSON}")
read -r gitrepo gitref \
  < <(jq -r '.git | "\(.repo) \(.ref)"' <<< "${CONFIGJSON}")
read -r implementation pythonversion platform \
  < <(jq -r ".builds[\"${BUILDNAME}\"] | \"\(.implementation) \(.pythonversion) \(.platform)\"" <<< "${CONFIGJSON}")
read -r pythonversionfull pythonfilename pythonurl pythonsha256 \
  < <(jq -r ".builds[\"${BUILDNAME}\"].pythonembed | \"\(.version) \(.filename) \(.url) \(.sha256)\"" <<< "${CONFIGJSON}")

gitrepo="${GITREPO:-${gitrepo}}"
gitref="${GITREF:-${gitref}}"


# ----


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
  git \
    -c advice.detachedHead=false \
    clone \
    --depth="${GIT_FETCHDEPTH}" \
    -b "${gitref}" \
    "${gitrepo}" \
    "${DIR_REPO}"

  log "Commit information"
  GIT_PAGER=cat git \
    -C "${DIR_REPO}" \
    log \
    -1 \
    --pretty=full
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
      < <(jq -r ".assets[\"${assetname}\"] | \"\(.filename) \(.url) \(.sha256)\"" <<< "${CONFIGJSON}")
    if ! [[ -f "${DIR_CACHE}/${filename}" ]]; then
      log "Downloading asset: ${assetname}"
      curl -SLo "${DIR_CACHE}/${filename}" "${url}"
    fi
    log "Checking asset: ${assetname}"
    sha256sum -c - <<< "${sha256} ${DIR_CACHE}/${filename}"
  done < <(jq -r ".builds[\"${BUILDNAME}\"].assets[]" <<< "${CONFIGJSON}")
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
      < <(jq -r ".assets[\"${assetname}\"] | \"\(.type) \(.filename) \(.sourcedir) \(.targetdir)\"" <<< "${CONFIGJSON}")
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
    done < <(jq -r ".assets[\"${assetname}\"].files[] | \"\(.from) \(.to)\"" <<< "${CONFIGJSON}")
  done < <(jq -r ".builds[\"${BUILDNAME}\"].assets[]" <<< "${CONFIGJSON}")
}

prepare_files() {
  log "Copying license file with file extension"
  install -v "${DIR_REPO}/LICENSE" "${DIR_BUILD}/LICENSE.txt"
}

prepare_executables() {
  log "Preparing executables"
  TZ=UTC python ./build-portable-commands.py \
    --target="${DIR_BIN}" \
    --bitness="$([[ "${platform}" == "win_amd64" ]] && echo 64 || echo 32)"
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
    < <(jq -r ".builds[\"${BUILDNAME}\"].dependencies.wheels | to_entries[] | \"\(.key)==\(.value)\"" <<< "${CONFIGJSON}")

  log "Installing sdists"
  pip install \
    "${PIP_ARGS[@]}" \
    --require-hashes \
    --no-binary=:all: \
    --no-deps \
    --target="${DIR_PKGS}" \
    --no-compile \
    --requirement=/dev/stdin \
    < <(jq \
      -r \
      --arg keys "$(echo "${DISTS_IGNORE[*]}")" \
      ".builds[\"${BUILDNAME}\"].dependencies.sdists | delpaths(\$keys | split(\" \") | map([.])) | to_entries[] | \"\(.key)==\(.value)\"" \
      <<< "${CONFIGJSON}"
    )

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
  ( set -x; rm -r "${DIR_PKGS}/bin" "${DIR_PKGS}"/*.dist-info/direct_url.json; )
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
    local _commit="$(cd "${DIR_REPO}" && git -c core.abbrev=7 rev-parse --short HEAD)"
    version="${versionplain}-0-g${_commit}"

  # Custom ref -> arbitrary untagged commit (version string includes build metadata)
  # Translate into correct format
  else
    version="${versionplain}-${versionmeta/./-}"
  fi

  log "Updating modification times"
  local mtime
  [[ "${SOURCE_DATE_EPOCH}" ]] && mtime="@${SOURCE_DATE_EPOCH}" || mtime=now
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
