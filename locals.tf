locals {
  site_label_value = lower(var.deployment_name)

  ce_site_names = {
    for key, site in var.ce_sites :
    key => lower("${var.deployment_name}-${key}-ce")
  }

  application_defaults = (
    var.app_domain != null && var.origin_server_value != null
  ) ? {
    default = {
      domains             = [var.app_domain]
      listener_port       = var.listener_port
      origin_server_type  = var.origin_server_type
      origin_server_value = var.origin_server_value
      origin_port         = var.origin_port
      advertise_network   = var.advertise_network
    }
  } : {}

  applications = length(var.applications) > 0 ? var.applications : local.application_defaults

  public_application_ports = sort(distinct([
    for app in values(local.applications) : app.listener_port
    if app.advertise_network == "SITE_NETWORK_OUTSIDE" || app.advertise_network == "SITE_NETWORK_INSIDE_AND_OUTSIDE"
  ]))

  internal_application_ports = sort(distinct([
    for app in values(local.applications) : app.listener_port
    if app.advertise_network == "SITE_NETWORK_INSIDE" || app.advertise_network == "SITE_NETWORK_INSIDE_AND_OUTSIDE"
  ]))

  azure_lb_site_configs = {
    for key, site in var.ce_sites :
    key => {
      resource_group_name          = site.resource_group
      location                     = site.azure_region
      vnet_name                    = coalesce(site.use_existing_vnet, false) ? site.existing_vnet_name : site.vnet_name
      vnet_resource_group_name     = coalesce(site.use_existing_vnet, false) ? coalesce(site.existing_vnet_resource_group, site.resource_group) : site.resource_group
      inside_subnet_cidr           = site.inside_subnet_cidr
      outside_subnet_cidr          = site.outside_subnet_cidr
      public_listener_ports        = length(coalesce(site.azure_lb_public_listener_ports, [])) > 0 ? sort(distinct(site.azure_lb_public_listener_ports)) : local.public_application_ports
      internal_listener_ports      = length(coalesce(site.azure_lb_internal_listener_ports, [])) > 0 ? sort(distinct(site.azure_lb_internal_listener_ports)) : local.internal_application_ports
      public_probe_port            = coalesce(site.azure_lb_public_probe_port, coalesce(site.azure_lb_health_probe_port, length(local.public_application_ports) > 0 ? local.public_application_ports[0] : var.listener_port))
      internal_probe_port          = coalesce(site.azure_lb_internal_probe_port, coalesce(site.azure_lb_health_probe_port, length(local.internal_application_ports) > 0 ? local.internal_application_ports[0] : var.listener_port))
      public_lb_enabled            = coalesce(site.create_public_load_balancer, var.default_create_public_load_balancer)
      internal_lb_enabled          = coalesce(site.create_internal_load_balancer, var.default_create_internal_load_balancer)
      public_lb_name               = lower("${var.deployment_name}-${key}-public-lb")
      internal_lb_name             = lower("${var.deployment_name}-${key}-internal-lb")
      public_ip_name               = lower("${var.deployment_name}-${key}-public-pip")
      public_frontend_name         = "public-frontend"
      internal_frontend_name       = "internal-frontend"
      internal_frontend_private_ip = site.internal_frontend_private_ip
      public_frontend_domain_name  = null
      public_backend_ips           = coalesce(site.azure_lb_outside_backend_ips, [])
      internal_backend_ips         = coalesce(site.azure_lb_inside_backend_ips, [])
    }
    if coalesce(site.create_public_load_balancer, var.default_create_public_load_balancer) || coalesce(site.create_internal_load_balancer, var.default_create_internal_load_balancer)
  }

  virtual_site_name       = lower("${var.deployment_name}-vsite")
  origin_pool_name        = lower("${var.deployment_name}-origin-pool")
  http_load_balancer_name = lower("${var.deployment_name}-http-lb")
}
