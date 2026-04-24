output "public_load_balancer_id" {
  description = "ID of the public Azure load balancer, if created."
  value       = try(azurerm_lb.public[0].id, null)
}

output "public_frontend_ip_address" {
  description = "Public frontend IP address for the Azure load balancer, if created."
  value       = try(azurerm_public_ip.public[0].ip_address, null)
}

output "internal_load_balancer_id" {
  description = "ID of the internal Azure load balancer, if created."
  value       = try(azurerm_lb.internal[0].id, null)
}

output "internal_frontend_private_ip" {
  description = "Private frontend IP address for the internal Azure load balancer, if created."
  value       = try(azurerm_lb.internal[0].frontend_ip_configuration[0].private_ip_address, null)
}

output "inside_backend_addresses" {
  description = "Discovered CE inside-network IPs added to the internal backend pool."
  value       = local.inside_backend_addresses
}

output "outside_backend_addresses" {
  description = "Discovered CE outside-network IPs added to the public backend pool."
  value       = local.outside_backend_addresses
}
