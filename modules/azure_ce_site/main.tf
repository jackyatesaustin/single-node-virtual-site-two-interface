terraform {
  required_providers {
    volterra = {
      source = "volterraedge/volterra"
    }
  }
}

resource "volterra_azure_vnet_site" "this" {
  name      = var.name
  namespace = var.namespace

  default_blocked_services = true
  logs_streaming_disabled  = true
  machine_type             = var.machine_type
  azure_region             = var.azure_region
  resource_group           = var.resource_group_name
  ssh_key                  = var.ssh_public_key
  no_worker_nodes          = true

  azure_cred {
    name      = var.azure_credential_name
    namespace = var.azure_credential_namespace
    tenant    = var.tenant_name
  }

  ingress_egress_gw {
    accelerated_networking {
      disable = true
    }

    az_nodes {
      azure_az = var.availability_zone

      inside_subnet {
        subnet_param {
          ipv4 = var.inside_subnet_cidr
        }
      }

      outside_subnet {
        subnet_param {
          ipv4 = var.outside_subnet_cidr
        }
      }
    }

    azure_certified_hw       = var.azure_certified_hw
    no_dc_cluster_group      = true
    no_forward_proxy         = true
    no_global_network        = true
    not_hub                  = true
    no_inside_static_routes  = true
    no_network_policy        = true
    no_outside_static_routes = true

    performance_enhancement_mode {
      dynamic "perf_mode_l3_enhanced" {
        for_each = var.performance_mode == "l3" ? [1] : []

        content {
          no_jumbo = true
        }
      }

      dynamic "perf_mode_l7_enhanced" {
        for_each = var.performance_mode == "l7" ? [1] : []

        content {
          jumbo_disabled = true
        }
      }
    }

    sm_connection_public_ip = true
  }

  vnet {
    dynamic "existing_vnet" {
      for_each = var.use_existing_vnet ? [1] : []

      content {
        resource_group = var.existing_vnet_rgname
        vnet_name      = var.existing_vnet_name

        f5_orchestrated_routing = var.routing_mode == "f5_orchestrated" ? true : null
        manual_routing          = var.routing_mode == "manual" ? true : null
      }
    }

    dynamic "new_vnet" {
      for_each = var.use_existing_vnet ? [] : [1]

      content {
        autogenerate = var.vnet_name == null ? true : null
        name         = var.vnet_name
        primary_ipv4 = var.vnet_cidr
      }
    }
  }

  lifecycle {
    ignore_changes = [labels]
  }
}
