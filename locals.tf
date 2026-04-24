locals {
  site_label_value = lower(var.deployment_name)

  ce_site_names = {
    for key, site in var.ce_sites :
    key => lower("${var.deployment_name}-${key}-ce")
  }

  azure_lb_site_configs = {
    for key, site in var.ce_sites :
    key => {
      resource_group_name          = site.resource_group
      location                     = site.azure_region
      vnet_name                    = coalesce(site.use_existing_vnet, false) ? site.existing_vnet_name : site.vnet_name
      vnet_resource_group_name     = coalesce(site.use_existing_vnet, false) ? coalesce(site.existing_vnet_resource_group, site.resource_group) : site.resource_group
      inside_subnet_cidr           = site.inside_subnet_cidr
      outside_subnet_cidr          = site.outside_subnet_cidr
      listener_port                = coalesce(site.azure_lb_listener_port, var.listener_port)
      probe_port                   = coalesce(site.azure_lb_health_probe_port, coalesce(site.azure_lb_listener_port, var.listener_port))
      public_lb_enabled            = coalesce(site.create_public_load_balancer, var.default_create_public_load_balancer)
      internal_lb_enabled          = coalesce(site.create_internal_load_balancer, var.default_create_internal_load_balancer)
      public_lb_name               = lower("${var.deployment_name}-${key}-public-lb")
      internal_lb_name             = lower("${var.deployment_name}-${key}-internal-lb")
      public_ip_name               = lower("${var.deployment_name}-${key}-public-pip")
      public_frontend_name         = "public-frontend"
      internal_frontend_name       = "internal-frontend"
      internal_frontend_private_ip = site.internal_frontend_private_ip
      public_frontend_domain_name  = null
      outside_backend_addresses    = coalesce(site.azure_lb_outside_backend_ips, [])
      inside_backend_addresses     = coalesce(site.azure_lb_inside_backend_ips, [])
    }
    if coalesce(site.create_public_load_balancer, var.default_create_public_load_balancer) || coalesce(site.create_internal_load_balancer, var.default_create_internal_load_balancer)
  }

  virtual_site_name       = lower("${var.deployment_name}-vsite")
  origin_pool_name        = lower("${var.deployment_name}-origin-pool")
  http_load_balancer_name = lower("${var.deployment_name}-http-lb")
}
