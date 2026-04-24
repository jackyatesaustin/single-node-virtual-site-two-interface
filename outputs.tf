output "ce_site_names" {
  description = "Created Azure CE site names keyed by site identifier."
  value       = { for key, site in module.azure_ce_site : key => site.site_name }
}

output "virtual_site_name" {
  description = "Virtual Site that groups the CE sites."
  value       = module.f5_http_lb.virtual_site_name
}

output "origin_pool_name" {
  description = "Origin Pool attached to the Virtual Site."
  value       = module.f5_http_lb.origin_pool_name
}

output "http_load_balancer_name" {
  description = "HTTP load balancer advertised on the Virtual Site."
  value       = module.f5_http_lb.http_load_balancer_name
}

output "site_selector_label" {
  description = "Known label used to join CE sites to the Virtual Site."
  value = {
    key   = var.site_label_key
    value = local.site_label_value
  }
}

output "azure_site_load_balancers" {
  description = "Optional Azure load balancer frontends created per CE site."
  value = {
    for key, site in module.azure_site_load_balancer : key => {
      public_load_balancer_id          = site.public_load_balancer_id
      public_frontend_ip_address       = site.public_frontend_ip_address
      internal_load_balancer_id        = site.internal_load_balancer_id
      internal_frontend_private_ip     = site.internal_frontend_private_ip
      inside_backend_addresses         = site.inside_backend_addresses
      outside_backend_addresses        = site.outside_backend_addresses
    }
  }
}
