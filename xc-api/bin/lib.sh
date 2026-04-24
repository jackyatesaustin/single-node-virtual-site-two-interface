#!/usr/bin/env bash

set -euo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "==> $*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command not found: ${cmd}"
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    die "Required environment variable not set: ${name}"
  fi
}

slugify() {
  local value="$1"
  value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "${value}" | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
  printf '%s' "${value}"
}

mktemp_json() {
  mktemp "${TMPDIR:-/tmp}/xc-api.XXXXXX.json"
}

xc_api_base() {
  printf '%s' "${VOLT_API_URL%/}"
}

xc_auth_args() {
  if [[ -n "${VOLT_API_TOKEN:-}" ]]; then
    printf '%s\n' \
      "--header" \
      "Authorization: APIToken ${VOLT_API_TOKEN}"
    return 0
  fi

  if [[ -n "${VOLT_API_P12_FILE:-}" && -n "${VES_P12_PASSWORD:-}" ]]; then
    printf '%s\n' \
      "--cert-type" \
      "P12" \
      "--cert" \
      "${VOLT_API_P12_FILE}:${VES_P12_PASSWORD}"
    return 0
  fi

  die "Set VOLT_API_TOKEN or VOLT_API_P12_FILE with VES_P12_PASSWORD."
}

xc_api_request() {
  local method="$1"
  local path="$2"
  local body_file="${3:-}"

  local args=(
    --silent
    --show-error
    --fail-with-body
    --request "${method}"
    --header "Content-Type: application/json"
    --header "X-Volterra-Useragent: xc-api-bash-script"
  )

  while IFS= read -r arg; do
    args+=("${arg}")
  done < <(xc_auth_args)

  if [[ -n "${body_file}" ]]; then
    args+=(--data "@${body_file}")
  fi

  args+=("$(xc_api_base)${path}")
  curl "${args[@]}"
}

xc_resource_exists() {
  local path="$1"
  xc_api_request GET "${path}" >/dev/null 2>&1
}

xc_upsert_object() {
  local namespace="$1"
  local collection="$2"
  local resource_name="$3"
  local payload="$4"

  local collection_path="/config/namespaces/${namespace}/${collection}"
  local resource_path="${collection_path}/${resource_name}"
  local payload_file

  payload_file="$(mktemp_json)"
  printf '%s\n' "${payload}" > "${payload_file}"

  if xc_resource_exists "${resource_path}"; then
    log "Replacing ${collection}/${resource_name}"
    xc_api_request PUT "${resource_path}" "${payload_file}" >/dev/null
  else
    log "Creating ${collection}/${resource_name}"
    xc_api_request POST "${collection_path}" "${payload_file}" >/dev/null
  fi

  rm -f "${payload_file}"
}
