# XC API automation

This folder contains a Bash-based workflow for configuring F5 Distributed Cloud (XC) application objects directly through the XC config APIs instead of Terraform.

The automation mirrors the repository's multi-application model:

- one shared **Virtual Site**
- one **Origin Pool** per application
- one **HTTP Load Balancer** per application
- per-application **Virtual Site interface configuration**
  - `SITE_NETWORK_OUTSIDE` for external apps
  - `SITE_NETWORK_INSIDE` for internal apps
  - `SITE_NETWORK_INSIDE_AND_OUTSIDE` for shared apps

## Requirements

- `bash`
- `curl`
- `jq`
- F5 XC API credentials exposed as environment variables:

```bash
export VOLT_API_URL="https://<tenant>.console.ves.volterra.io/api"
export VOLT_API_TOKEN="<api-token>"
```

Or use the same P12-based auth pattern as the Terraform provider:

```bash
export VOLT_API_URL="https://<tenant>.console.ves.volterra.io/api"
export VOLT_API_P12_FILE="/absolute/path/to/api-creds.p12"
export VES_P12_PASSWORD="<p12-password>"
```

The helper library supports either bearer-token auth or P12 client-certificate auth.

## Files

- `bin/lib.sh`
  - shared helper functions for auth, API requests, and JSON generation
- `bin/upsert-http-lbs.sh`
  - reads a JSON config file and creates or replaces:
    - XC Origin Pools
    - XC HTTP Load Balancers
- `examples/applications.json`
  - sample input configuration

## Configuration file

The config file is JSON with the following top-level fields:

```json
{
  "tenant_name": "my-tenant",
  "namespace": "system",
  "virtual_site": {
    "name": "vsite-single-node-vsite",
    "namespace": "system",
    "tenant": "my-tenant"
  },
  "defaults": {
    "origin_server_type": "private_ip",
    "origin_port": 80,
    "endpoint_selection": "LOCALPREFERED",
    "loadbalancer_algorithm": "LB_OVERRIDE"
  },
  "applications": {
    "ext-web": {
      "domains": ["app.example.com"],
      "listener_port": 80,
      "origin_server_type": "private_ip",
      "origin_server_value": "10.10.1.10",
      "origin_port": 80,
      "advertise_network": "SITE_NETWORK_OUTSIDE"
    }
  }
}
```

### Application fields

Each application must define:

- `domains`
  - array of domain names for the HTTP load balancer
- `listener_port`
  - load balancer listener port
- `origin_server_type`
  - `private_ip` or `private_name`
- `origin_server_value`
  - backend IP or DNS name
- `origin_port`
  - backend port
- `advertise_network`
  - Virtual Site interface configuration for that app:
    - `SITE_NETWORK_OUTSIDE`
    - `SITE_NETWORK_INSIDE`
    - `SITE_NETWORK_INSIDE_AND_OUTSIDE`

Optional top-level defaults:

- `defaults.origin_server_type`
- `defaults.origin_port`
- `defaults.endpoint_selection`
- `defaults.loadbalancer_algorithm`

Per-application optional overrides:

- `origin_pool_name`
- `http_load_balancer_name`
- `endpoint_selection`
- `loadbalancer_algorithm`

## Usage

Run the script with a config file:

```bash
bash xc-api/bin/upsert-http-lbs.sh -f xc-api/examples/applications.json
```

By default, names are derived from the application key:

- origin pool: `<app-key>-origin-pool`
- HTTP load balancer: `<app-key>-http-lb`

You can override them per application:

```json
{
  "applications": {
    "ext-web": {
      "origin_pool_name": "custom-origin-pool",
      "http_load_balancer_name": "custom-http-lb"
    }
  }
}
```

## Idempotent behavior

For each application:

1. the script checks whether the Origin Pool exists
2. it `POST`s create if missing, otherwise `PUT`s replace
3. it checks whether the HTTP Load Balancer exists
4. it `POST`s create if missing, otherwise `PUT`s replace

This keeps the workflow easy to rerun after edits.

## Notes

- The script expects the **Virtual Site already to exist**.
- This automation does **not** create:
  - CE sites
  - Virtual Sites
  - Azure load balancers
  - DNS records
- Origins are modeled as **private backends reached over the inside network**, even for externally exposed applications.
- The `SITE_NETWORK_*` value is the **Virtual Site interface configuration** used by the HTTP load balancer advertisement.
- The script sends XC config objects using the documented `metadata` + `spec` request shape for:
  - `/api/config/namespaces/{namespace}/origin_pools`
  - `/api/config/namespaces/{namespace}/http_loadbalancers`
