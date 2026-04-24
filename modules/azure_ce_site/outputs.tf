output "id" {
  description = "ID of the Azure CE site object."
  value       = volterra_azure_vnet_site.this.id
}

output "site_name" {
  description = "Name of the Azure CE site."
  value       = volterra_azure_vnet_site.this.name
}

output "namespace" {
  description = "Namespace of the Azure CE site."
  value       = volterra_azure_vnet_site.this.namespace
}
