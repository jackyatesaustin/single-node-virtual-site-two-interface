# F5 XC Azure CE Repo

This Terraform repo creates a two-site F5 XC Azure Customer Edge deployment for a Virtual Site pattern:

- two single-node Azure CE sites
- `SLI` and `SLO` on each site via `ingress_egress_gw`
- one XC `Virtual Site` that groups both CE sites
- one XC `Virtual Site` shared by all applications in the deployment
- one XC `Origin Pool` per application that targets the Virtual Site over the inside network
- one XC `HTTP Load Balancer` per application, with each app advertised on inside, outside, or both networks
- optional Azure public and internal load balancers per site that front the CE `SLO` and `SLI` interfaces

## Scope

This repo uses the `volterraedge/volterra` provider for F5 XC objects and the `hashicorp/azurerm` provider for optional Azure-native load balancers in front of the CE interfaces.

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
    ├── f5_http_lb
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── azure_site_load_balancer
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
- `applications`
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
- `applications`
  - map of application definitions keyed by a short app identifier such as `external`, `internal`, or `api`
  - each application creates:
    - one XC `Origin Pool`
    - one XC `HTTP Load Balancer`
  - each application sets:
    - `domain`
    - `listener_port`
    - `origin_server_type`
    - `origin_server_value`
    - `origin_port`
    - `advertise_network`
- `advertise_network`
  - per-application value that decides which CE interface the app listens on
  - `SITE_NETWORK_OUTSIDE` -> external app on `SLO`
  - `SITE_NETWORK_INSIDE` -> internal app on `SLI`
  - `SITE_NETWORK_INSIDE_AND_OUTSIDE` -> app exposed on both interfaces
- `default_create_public_load_balancer` / `default_create_internal_load_balancer`
  - optional defaults that create Azure load balancers per CE site
  - public LBs front CE `SLO` IPs and create rules for externally advertised application ports
  - internal LBs front CE `SLI` IPs and create rules for internally advertised application ports
- `ce_sites[*].azure_lb_outside_backend_ips` / `ce_sites[*].azure_lb_inside_backend_ips`
  - optional backend IP overrides for Azure load balancers
  - leave unset to auto-discover CE NIC IPs by matching NIC subnet attachments to the configured `outside_subnet_cidr` and `inside_subnet_cidr`
- `ce_sites[*].azure_lb_public_listener_ports` / `ce_sites[*].azure_lb_internal_listener_ports`
  - optional per-site overrides for which listener ports the Azure public/internal load balancers expose
  - leave unset to derive them automatically from the `applications` map

## Deployment Flow

1. Create two Azure CE sites, each with:
   - one `SLO` outside interface for client-facing advertisement
   - one `SLI` inside interface for private origin access
2. Attach a known XC label and site labels to both CE sites.
3. Build one XC `Virtual Site` that selects the labeled CE sites.
4. Create one XC `Origin Pool` per application that reaches that app's backend over the inside network through the Virtual Site.
5. Create one XC `HTTP Load Balancer` per application:
   - external apps advertise on `SITE_NETWORK_OUTSIDE`
   - internal apps advertise on `SITE_NETWORK_INSIDE`
   - shared apps advertise on `SITE_NETWORK_INSIDE_AND_OUTSIDE`
6. Optionally create Azure public and internal load balancers in each site resource group:
   - the public LB fronts CE `SLO` backend IPs and exposes the union of external app ports
   - the internal LB fronts CE `SLI` backend IPs and exposes the union of internal app ports

## Diagrams

See [`docs/deployment-diagram.md`](docs/deployment-diagram.md) for the deployment/object diagram, including:

- the F5 XC objects created by this stack
- the CE `SLO` outside interface used for load-balancer advertisement
- the CE `SLI` inside interface used to reach the private origin
- the Secure Mesh public IP used for control-plane connectivity

See [`docs/traffic-flow.md`](docs/traffic-flow.md) for the end-to-end request traffic flow:

- external client to public DNS and the CE `SLO` path
- internal client to internal DNS and the CE `SLI` path
- application-specific load balancers and origin pools over the shared Virtual Site
- the Virtual Site shown as a logical grouping of CE sites rather than a traffic-processing hop

## Azure Load Balancer Behavior

When enabled, the repo creates Azure-native frontends per CE site:

- **public Azure load balancer**
  - frontend: Standard public IP
  - backend pool: CE `SLO` interface IPs
  - rules: one TCP rule per application that advertises on `SITE_NETWORK_OUTSIDE` or `SITE_NETWORK_INSIDE_AND_OUTSIDE`
- **internal Azure load balancer**
  - frontend: private IP on the `SLI` subnet
  - backend pool: CE `SLI` interface IPs
  - rules: one TCP rule per application that advertises on `SITE_NETWORK_INSIDE` or `SITE_NETWORK_INSIDE_AND_OUTSIDE`

Backend discovery works like this:

1. Read the CE VNet and all subnets in that VNet.
2. Match the configured `inside_subnet_cidr` and `outside_subnet_cidr` to subnet IDs.
3. Read NICs from the CE resource group.
4. Collect NIC IP configurations attached to the matching inside/outside subnets.

If your CE deployment uses a topology that makes this discovery ambiguous, set:

- `ce_sites[*].azure_lb_inside_backend_ips`
- `ce_sites[*].azure_lb_outside_backend_ips`

to pin the exact backend IPs for the internal and public Azure load balancers.

## Notes

- The repo uses `volterra_cloud_site_labels` to attach a known label to each Azure VNet Site, then a `volterra_virtual_site` selector groups those sites.
- Each application origin pool assumes the same application IP or DNS name exists behind each CE site and is reachable via `SLI`.
- HTTP load balancers are configured as HTTP listeners. If you want HTTPS or certificate automation, extend `modules/f5_http_lb/main.tf`.
- Azure DNS records are still not created by this repo. Public and internal DNS remain external to this Terraform.
