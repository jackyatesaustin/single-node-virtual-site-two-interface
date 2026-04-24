#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  upsert-http-lbs.sh -f <config.json>

Required environment variables:
  VOLT_API_URL        Base XC API URL, e.g. https://tenant.console.ves.volterra.io/api
  Either:
    VOLT_API_TOKEN            API token used for Authorization: APIToken
  Or:
    VOLT_API_P12_FILE         Path to XC API credential P12 file
    VES_P12_PASSWORD          Password for the P12 file

Required tools:
  curl
  jq

Config JSON format:
{
  "tenant_name": "my-tenant",
  "namespace": "system",
  "virtual_site": {
    "name": "my-vsite",
    "namespace": "system"
  },
  "defaults": {
    "origin_server_type": "private_ip",
    "origin_port": 80,
    "endpoint_selection": "LOCALPREFERED",
    "loadbalancer_algorithm": "LB_OVERRIDE"
  },
  "applications": {
    "external-app": {
      "domains": ["app.example.com"],
      "listener_port": 80,
      "origin_server_value": "10.10.1.10",
      "advertise_network": "SITE_NETWORK_OUTSIDE"
    }
  }
}
EOF
}

CONFIG_FILE=""

while getopts ":f:h" opt; do
  case "${opt}" in
    f) CONFIG_FILE="${OPTARG}" ;;
    h)
      usage
      exit 0
      ;;
    :)
      die "Option -${OPTARG} requires an argument."
      ;;
    *)
      usage
      die "Unknown option: -${OPTARG}"
      ;;
  esac
done

[[ -n "${CONFIG_FILE}" ]] || {
  usage
  die "Missing -f <config.json>."
}

require_command curl
require_command jq
[[ -f "${CONFIG_FILE}" ]] || die "Config file not found: ${CONFIG_FILE}"
require_env VOLT_API_URL
if [[ -z "${VOLT_API_TOKEN:-}" ]]; then
  require_env VOLT_API_P12_FILE
  require_env VES_P12_PASSWORD
fi

tenant_name="$(jq -r '.tenant_name' "${CONFIG_FILE}")"
namespace="$(jq -r '.namespace' "${CONFIG_FILE}")"
virtual_site_name="$(jq -r '.virtual_site.name' "${CONFIG_FILE}")"
virtual_site_namespace="$(jq -r '.virtual_site.namespace // .namespace' "${CONFIG_FILE}")"
virtual_site_tenant="$(jq -r '.virtual_site.tenant // .tenant_name' "${CONFIG_FILE}")"

[[ "${tenant_name}" != "null" && -n "${tenant_name}" ]] || die "Config must set .tenant_name"
[[ "${namespace}" != "null" && -n "${namespace}" ]] || die "Config must set .namespace"
[[ "${virtual_site_name}" != "null" && -n "${virtual_site_name}" ]] || die "Config must set .virtual_site.name"
[[ "${virtual_site_namespace}" != "null" && -n "${virtual_site_namespace}" ]] || die "Config must set .virtual_site.namespace or .namespace"
[[ "${virtual_site_tenant}" != "null" && -n "${virtual_site_tenant}" ]] || die "Config must set .virtual_site.tenant or .tenant_name"

app_keys="$(jq -r '.applications | keys[]' "${CONFIG_FILE}")"
[[ -n "${app_keys}" ]] || die "Config must define at least one application under .applications"

upsert_origin_pool() {
  local app_key="$1"
  local app_json="$2"
  local origin_pool_name="$3"

  local payload
  payload="$(
    jq -n \
      --arg namespace "${namespace}" \
      --arg name "${origin_pool_name}" \
      --arg origin_server_type "$(jq -r '.origin_server_type' <<<"${app_json}")" \
      --arg origin_server_value "$(jq -r '.origin_server_value' <<<"${app_json}")" \
      --arg tenant "${virtual_site_tenant}" \
      --arg virtual_site_name "${virtual_site_name}" \
      --arg virtual_site_namespace "${virtual_site_namespace}" \
      --arg endpoint_selection "$(jq -r '.endpoint_selection' <<<"${app_json}")" \
      --arg loadbalancer_algorithm "$(jq -r '.loadbalancer_algorithm' <<<"${app_json}")" \
      --argjson origin_port "$(jq -r '.origin_port' <<<"${app_json}")" \
      '
      {
        metadata: {
          name: $name,
          namespace: $namespace
        },
        spec: {
          origin_servers: [
            (
              if $origin_server_type == "private_ip" then
                {
                  private_ip: {
                    ip: $origin_server_value,
                    inside_network: true,
                    site_locator: {
                      virtual_site: {
                        tenant: $tenant,
                        namespace: $virtual_site_namespace,
                        name: $virtual_site_name,
                        kind: "virtual_site"
                      }
                    }
                  }
                }
              else
                {
                  private_name: {
                    dns_name: $origin_server_value,
                    inside_network: true,
                    refresh_interval: 60,
                    site_locator: {
                      virtual_site: {
                        tenant: $tenant,
                        namespace: $virtual_site_namespace,
                        name: $virtual_site_name,
                        kind: "virtual_site"
                      }
                    }
                  }
                }
              end
            )
          ],
          no_tls: {},
          port: $origin_port,
          endpoint_selection: $endpoint_selection,
          loadbalancer_algorithm: $loadbalancer_algorithm
        }
      }'
  )"

  xc_upsert_object "${namespace}" "origin_pools" "${origin_pool_name}" "${payload}"
  log "Upserted origin pool for ${app_key}: ${origin_pool_name}"
}

upsert_http_lb() {
  local app_key="$1"
  local app_json="$2"
  local origin_pool_name="$3"
  local http_lb_name="$4"

  local payload
  payload="$(
    jq -n \
      --arg namespace "${namespace}" \
      --arg name "${http_lb_name}" \
      --arg tenant "${virtual_site_tenant}" \
      --arg virtual_site_name "${virtual_site_name}" \
      --arg virtual_site_namespace "${virtual_site_namespace}" \
      --arg advertise_network "$(jq -r '.advertise_network' <<<"${app_json}")" \
      --argjson domains "$(jq -c '.domains' <<<"${app_json}")" \
      --argjson listener_port "$(jq -r '.listener_port' <<<"${app_json}")" \
      --arg origin_pool_name "${origin_pool_name}" \
      '
      {
        metadata: {
          name: $name,
          namespace: $namespace
        },
        spec: {
          domains: $domains,
          advertise_custom: {
            advertise_where: [
              {
                virtual_site: {
                  network: $advertise_network,
                  virtual_site: {
                    tenant: $tenant,
                    namespace: $virtual_site_namespace,
                    name: $virtual_site_name,
                    kind: "virtual_site"
                  }
                }
              }
            ]
          },
          default_route_pools: [
            {
              pool: {
                tenant: $tenant,
                namespace: $namespace,
                name: $origin_pool_name,
                kind: "origin_pool"
              },
              weight: 1
            }
          ],
          http: {
            dns_volterra_managed: false,
            port: $listener_port
          },
          disable_waf: {},
          no_challenge: {},
          user_id_client_ip: {},
          disable_rate_limit: {},
          disable_trust_client_ip_headers: {},
          multi_lb_app: {},
          disable_malicious_user_detection: {},
          disable_api_discovery: {},
          default_sensitive_data_policy: {},
          disable_api_testing: {},
          disable_api_definition: {},
          disable_threat_mesh: {},
          disable_malware_protection: {}
        }
      }'
  )"

  xc_upsert_object "${namespace}" "http_loadbalancers" "${http_lb_name}" "${payload}"
  log "Upserted HTTP load balancer for ${app_key}: ${http_lb_name}"
}

for app_key in ${app_keys}; do
  app_json="$(
    jq -c --arg key "${app_key}" '
      .applications[$key] as $app
      | .defaults as $defaults
      | {
          domains: $app.domains,
          listener_port: $app.listener_port,
          origin_server_type: ($app.origin_server_type // $defaults.origin_server_type // "private_ip"),
          origin_server_value: $app.origin_server_value,
          origin_port: ($app.origin_port // $defaults.origin_port // 80),
          advertise_network: $app.advertise_network,
          origin_pool_name: ($app.origin_pool_name // null),
          http_load_balancer_name: ($app.http_load_balancer_name // null),
          endpoint_selection: ($app.endpoint_selection // $defaults.endpoint_selection // "LOCALPREFERED"),
          loadbalancer_algorithm: ($app.loadbalancer_algorithm // $defaults.loadbalancer_algorithm // "LB_OVERRIDE")
        }' "${CONFIG_FILE}"
  )"

  domains_count="$(jq '(.domains // []) | length' <<<"${app_json}")"
  [[ "${domains_count}" -gt 0 ]] || die "Application ${app_key} must define a non-empty domains array"

  listener_port="$(jq -r '.listener_port' <<<"${app_json}")"
  origin_server_type="$(jq -r '.origin_server_type' <<<"${app_json}")"
  origin_server_value="$(jq -r '.origin_server_value' <<<"${app_json}")"
  origin_port="$(jq -r '.origin_port' <<<"${app_json}")"
  advertise_network="$(jq -r '.advertise_network' <<<"${app_json}")"

  [[ -n "${listener_port}" && "${listener_port}" != "null" ]] || die "Application ${app_key} must set listener_port"
  [[ "${origin_server_type}" == "private_ip" || "${origin_server_type}" == "private_name" ]] || die "Application ${app_key} origin_server_type must be private_ip or private_name"
  [[ -n "${origin_server_value}" && "${origin_server_value}" != "null" ]] || die "Application ${app_key} must set origin_server_value"
  [[ -n "${origin_port}" && "${origin_port}" != "null" ]] || die "Application ${app_key} must set origin_port"
  [[ "${advertise_network}" == "SITE_NETWORK_INSIDE" || "${advertise_network}" == "SITE_NETWORK_OUTSIDE" || "${advertise_network}" == "SITE_NETWORK_INSIDE_AND_OUTSIDE" ]] || die "Application ${app_key} advertise_network must be SITE_NETWORK_INSIDE, SITE_NETWORK_OUTSIDE, or SITE_NETWORK_INSIDE_AND_OUTSIDE"

  safe_key="$(slugify "${app_key}")"
  origin_pool_name="$(jq -r '.origin_pool_name // empty' <<<"${app_json}")"
  http_lb_name="$(jq -r '.http_load_balancer_name // empty' <<<"${app_json}")"
  [[ -n "${origin_pool_name}" ]] || origin_pool_name="$(slugify "${safe_key}-origin-pool")"
  [[ -n "${http_lb_name}" ]] || http_lb_name="$(slugify "${safe_key}-http-lb")"

  upsert_origin_pool "${app_key}" "${app_json}" "${origin_pool_name}"
  upsert_http_lb "${app_key}" "${app_json}" "${origin_pool_name}" "${http_lb_name}"
done

log "Completed XC API upsert for config: ${CONFIG_FILE}"
