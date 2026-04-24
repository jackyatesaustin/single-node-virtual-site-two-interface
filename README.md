# F5 XC Azure CE Repo

This Terraform repo creates a two-site F5 XC Azure Customer Edge deployment for a Virtual Site pattern:

- two single-node Azure CE sites
- `SLI` and `SLO` on each site via `ingress_egress_gw`
- one XC `Virtual Site` that groups both CE sites
- one XC `Origin Pool` that targets the Virtual Site over the inside network
- one XC `HTTP Load Balancer` advertised on the Virtual Site

## Scope

This repo uses only the `volterraedge/volterra` provider.

It does create Azure VNet Site objects in F5 XC, but it does not provision standalone Azure ingress resources such as a public Azure Load Balancer or Azure DNS records. If you want internet-facing ingress through an Azure NLB in front of the CE `SLO` IPs, add that on the Azure side outside this repo.

## Prerequisites

- Terraform `>= 1.7.0`
- access to an F5 XC tenant
- a pre-existing F5 XC Azure credential object
- an SSH public key for the CE nodes
- Azure permissions behind that XC credential sufficient to deploy the site objects

Set provider authentication with environment variables instead of hard-coding secrets:

```bash
export VOLT_API_URL="https://<tenant>.console.ves.volterra.io/api"
export VOLT_API_P12_FILE="/absolute/path/to/api-creds.p12"
export VES_P12_PASSWORD="<p12-password>"
```

## Repo Layout

```text
.
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── versions.tf
├── providers.tf
├── terraform.tfvars.example
└── modules
    ├── azure_ce_site
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── f5_http_lb
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Usage

1. Copy the example input file and update the values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Review these fields carefully:

- `tenant_name`
- `azure_credential_name`
- `ssh_public_key`
- `app_domain`
- `origin_server_type`
- `origin_server_value`
- each entry in `ce_sites`

3. Initialize and validate:

```bash
terraform init
terraform validate
```

4. Apply:

```bash
terraform apply
```

## Important Inputs

- `ce_sites`
  - map of CE site definitions keyed by a short identifier such as `ce1` and `ce2`
  - each site creates a single-node Azure CE in two-interface mode
- `origin_server_type`
  - `private_ip` if the backend is reachable via the same RFC1918 IP at each member site
  - `private_name` if the backend is reachable via a site-local DNS name at each member site
- `advertise_network`
  - where the HTTP LB VIP is advertised on the Virtual Site
  - defaults to `SITE_NETWORK_OUTSIDE`

## Deployment Flow

```text
Azure CE Site 1 (SLI + SLO)
Azure CE Site 2 (SLI + SLO)
        |
        v
Known label + site labels
        |
        v
XC Virtual Site
        |
        v
XC Origin Pool (inside network)
        |
        v
XC HTTP Load Balancer
```

## Notes

- The repo uses `volterra_cloud_site_labels` to attach a known label to each Azure VNet Site, then a `volterra_virtual_site` selector groups those sites.
- The default origin-pool model assumes the same application IP or DNS name exists behind each CE site and is reachable via `SLI`.
- The HTTP LB is configured as an HTTP listener. If you want HTTPS or certificate automation, extend `modules/f5_http_lb/main.tf`.
