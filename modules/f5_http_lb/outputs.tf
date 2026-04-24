output "virtual_site_name" {
  description = "Name of the Virtual Site."
  value       = volterra_virtual_site.this.name
}

output "origin_pool_name" {
  description = "Name of the Origin Pool."
  value       = volterra_origin_pool.this.name
}

output "http_load_balancer_name" {
  description = "Name of the HTTP load balancer."
  value       = volterra_http_loadbalancer.this.name
}
