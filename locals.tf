locals {
  site_label_value = lower(var.deployment_name)

  ce_site_names = {
    for key, site in var.ce_sites :
    key => lower("${var.deployment_name}-${key}-ce")
  }

  virtual_site_name       = lower("${var.deployment_name}-vsite")
  origin_pool_name        = lower("${var.deployment_name}-origin-pool")
  http_load_balancer_name = lower("${var.deployment_name}-http-lb")
}
