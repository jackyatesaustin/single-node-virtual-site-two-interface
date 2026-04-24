terraform {
  required_providers {
    volterra = {
      source = "volterraedge/volterra"
    }
  }
}

locals {
  site_selector_expression = "${var.label_key} in (${var.label_value})"
}

resource "volterra_known_label_key" "membership" {
  key         = var.label_key
  namespace   = var.label_namespace
  description = "Selector key for ${var.virtual_site_name} membership."
}

resource "volterra_known_label" "membership" {
  key         = volterra_known_label_key.membership.key
  namespace   = var.label_namespace
  value       = var.label_value
  description = "Selector value for ${var.virtual_site_name} membership."
}

resource "volterra_cloud_site_labels" "membership" {
  for_each = var.site_names

  name      = each.value
  site_type = "azure_vnet_site"
  labels = {
    (var.label_key) = var.label_value
  }
  ignore_on_delete = true

  depends_on = [volterra_known_label.membership]
}

resource "volterra_virtual_site" "this" {
  name      = var.virtual_site_name
  namespace = var.namespace
  site_type = "CE"

  site_selector {
    expressions = [local.site_selector_expression]
  }

  depends_on = [volterra_cloud_site_labels.membership]
}

resource "volterra_origin_pool" "this" {
  for_each = var.applications

  name                   = each.value.origin_pool_name
  namespace              = var.namespace
  endpoint_selection     = each.value.origin_endpoint_selection
  loadbalancer_algorithm = each.value.origin_loadbalancer_algorithm
  no_tls                 = true
  port                   = tostring(each.value.origin_port)

  origin_servers {
    dynamic "private_ip" {
      for_each = each.value.origin_server_type == "private_ip" ? [each.value.origin_server_value] : []

      content {
        ip             = private_ip.value
        inside_network = true

        site_locator {
          virtual_site {
            name      = volterra_virtual_site.this.name
            namespace = var.namespace
            tenant    = var.tenant_name
          }
        }
      }
    }

    dynamic "private_name" {
      for_each = each.value.origin_server_type == "private_name" ? [each.value.origin_server_value] : []

      content {
        dns_name         = private_name.value
        inside_network   = true
        refresh_interval = 60

        site_locator {
          virtual_site {
            name      = volterra_virtual_site.this.name
            namespace = var.namespace
            tenant    = var.tenant_name
          }
        }
      }
    }
  }
}

resource "volterra_http_loadbalancer" "this" {
  for_each = var.applications

  depends_on = [volterra_origin_pool.this]

  name      = each.value.http_load_balancer_name
  namespace = var.namespace

  advertise_custom {
    advertise_where {
      virtual_site {
        network = each.value.advertise_network

        virtual_site {
          name      = volterra_virtual_site.this.name
          namespace = var.namespace
          tenant    = var.tenant_name
        }
      }
    }
  }

  disable_api_definition = true
  disable_api_discovery  = true
  disable_api_testing    = true
  no_challenge           = true
  domains                = each.value.domains
  source_ip_stickiness   = true

  http {
    dns_volterra_managed = false
    port                 = tostring(each.value.listener_port)
  }

  disable_malicious_user_detection = true
  disable_malware_protection       = true
  disable_rate_limit               = true
  default_sensitive_data_policy    = true
  no_service_policies              = true
  disable_threat_mesh              = true
  disable_trust_client_ip_headers  = true
  user_id_client_ip                = true
  disable_waf                      = true

  default_route_pools {
    pool {
      name      = volterra_origin_pool.this[each.key].name
      namespace = var.namespace
      tenant    = var.tenant_name
    }

    weight = 1
  }
}
