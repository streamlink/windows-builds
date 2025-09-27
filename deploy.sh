#!/usr/bin/env bash
set -euo pipefail

[[ -n "${CI:-}" && -n "${GITHUB_REPOSITORY:-}" && "${GITHUB_REF:-}" =~ ^refs/tags/ && -n "${RELEASES_API_KEY:-}" ]] || exit 1

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(readlink -f "${0}")")
FILES=("${@}")

declare -A DEPS=(
  [curl]=curl
  [jq]=jq
)

# ----

SELF=$(basename "$(readlink -f "${0}")")
log() {
  echo "[${SELF}]" "${@}"
}
err() {
  log >&2 "${@}"
  exit 1
}

for dep in "${!DEPS[@]}"; do
  command -v "${dep}" >/dev/null 2>&1 || err "Missing dependency: ${DEPS["${dep}"]}"
done

[[ $# == 0 ]] && err "Missing file(s)"

# ----

TAG="${GITHUB_REF/#refs\/tags\//}"
CURL_OPTIONS=(
  -H "Accept: application/vnd.github.v3+json"
  -H "User-Agent: ${GITHUB_REPOSITORY}"
  -H "Authorization: token ${RELEASES_API_KEY}"
)
GH_API="https://api.github.com/repos/${GITHUB_REPOSITORY}"
GH_UPLOAD="https://uploads.github.com/repos/${GITHUB_REPOSITORY}"
CHANGELOG="${ROOT}/CHANGELOG.md"
BODY="${ROOT}/.github/release-body.md"


get_release_id() {
  curl -fsSL \
    -X GET \
    "${CURL_OPTIONS[@]}" \
    "${GH_API}/releases/tags/${TAG}" \
    | jq -re ".id"
}

create_release() {
  local data body changelog
  changelog="$(awk '/^##/{show=0}$1 && show;/^## '"${TAG//./\\.}"' /{show=1}' "${CHANGELOG}")"
  # shellcheck disable=SC2016
  body="$(env -i \
    TAG="${TAG%-*}" \
    CHANGELOG="${changelog}" \
    envsubst '$TAG $CHANGELOG' \
    < "${BODY}"
  )"
  data="$(jq -cnR \
    --arg tag_name "${TAG}" \
    --arg name "${GITHUB_REPOSITORY} ${TAG}" \
    --arg body "${body}" \
    '{
      "tag_name": $tag_name,
      "name": $name,
      "body": $body
    }'
  )"
  curl -fsSL \
    -X POST \
    "${CURL_OPTIONS[@]}" \
    -d "${data}" \
    "${GH_API}/releases" \
    | jq -re ".id"
}

upload_assets() {
  local release_id="${1}"
  for path in "${FILES[@]}"; do
    local file
    file="$(basename "${path}")"
    log "Uploading ${file}"
    sha256sum "${path}"
    curl -fsSL \
      -X POST \
      "${CURL_OPTIONS[@]}" \
      -H "Content-Type: application/octet-stream" \
      --data-binary "@${path}" \
      --url-query "name=${file}" \
      "${GH_UPLOAD}/releases/${release_id}/assets" \
      >/dev/null
  done
}

deploy() {
  log "Getting release ID for tag ${TAG}"
  local release_id
  release_id="$(get_release_id 2>/dev/null || true)"

  if [[ -z "${release_id}" ]]; then
    log "Creating new release for tag ${TAG}"
    release_id="$(create_release)"
  fi

  if [[ -z "${release_id}" ]]; then
    err "Missing release ID"
  fi

  log "Uploading assets to release ${release_id}"
  upload_assets "${release_id}"

  log "Done"
}

deploy
