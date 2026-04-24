module "azure_ce_site" {
  source   = "./modules/azure_ce_site"
  for_each = var.ce_sites

  tenant_name                = var.tenant_name
  namespace                  = var.xc_namespace
  name                       = local.ce_site_names[each.key]
  azure_credential_name      = var.azure_credential_name
  azure_credential_namespace = var.azure_credential_namespace
  ssh_public_key             = var.ssh_public_key

  azure_region         = each.value.azure_region
  resource_group_name  = each.value.resource_group
  availability_zone    = each.value.availability_zone
  machine_type         = coalesce(each.value.machine_type, var.default_machine_type)
  azure_certified_hw   = coalesce(each.value.azure_certified_hw, var.default_azure_certified_hw)
  performance_mode     = coalesce(each.value.performance_mode, var.default_performance_mode)
  vnet_cidr            = each.value.vnet_cidr
  vnet_name            = each.value.vnet_name
  inside_subnet_cidr   = each.value.inside_subnet_cidr
  outside_subnet_cidr  = each.value.outside_subnet_cidr
  use_existing_vnet    = coalesce(each.value.use_existing_vnet, false)
  existing_vnet_name   = each.value.existing_vnet_name
  routing_mode         = coalesce(each.value.routing_mode, "f5_orchestrated")
  existing_vnet_rgname = coalesce(each.value.existing_vnet_resource_group, each.value.resource_group)
}

module "f5_http_lb" {
  source = "./modules/f5_http_lb"

  tenant_name             = var.tenant_name
  namespace               = var.xc_namespace
  label_namespace         = var.site_label_namespace
  label_key               = var.site_label_key
  label_value             = local.site_label_value
  site_names              = { for key, site in module.azure_ce_site : key => site.site_name }
  virtual_site_name       = local.virtual_site_name
  origin_pool_name        = local.origin_pool_name
  http_load_balancer_name = local.http_load_balancer_name
  app_domain              = var.app_domain
  listener_port           = var.listener_port
  origin_server_type      = var.origin_server_type
  origin_server_value     = var.origin_server_value
  origin_port             = var.origin_port
  advertise_network       = var.advertise_network
}
