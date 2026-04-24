output "virtual_site_name" {
  description = "Name of the Virtual Site."
  value       = volterra_virtual_site.this.name
}

output "origin_pool_names" {
  description = "Origin pool names keyed by application identifier."
  value       = { for key, pool in volterra_origin_pool.this : key => pool.name }
}

output "http_load_balancer_names" {
  description = "HTTP load balancer names keyed by application identifier."
  value       = { for key, lb in volterra_http_loadbalancer.this : key => lb.name }
}
