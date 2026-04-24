variable "deployment_name" {
  description = "Root deployment name used to derive Azure resource names."
  type        = string
}

variable "site_key" {
  description = "Short identifier for the CE site."
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group that contains the CE resources and the new Azure load balancers."
  type        = string
}

variable "location" {
  description = "Azure region for the load balancer resources."
  type        = string
}

variable "vnet_name" {
  description = "Azure VNet that contains the CE interfaces."
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Azure resource group that contains the CE VNet."
  type        = string
}

variable "inside_subnet_cidr" {
  description = "CIDR used by the CE SLI subnet."
  type        = string
}

variable "outside_subnet_cidr" {
  description = "CIDR used by the CE SLO subnet."
  type        = string
}

variable "public_listener_ports" {
  description = "External application listener ports exposed through the public Azure load balancer."
  type        = list(number)
}

variable "internal_listener_ports" {
  description = "Internal application listener ports exposed through the internal Azure load balancer."
  type        = list(number)
}

variable "public_probe_port" {
  description = "TCP probe port used by the public Azure load balancer health checks."
  type        = number
}

variable "internal_probe_port" {
  description = "TCP probe port used by the internal Azure load balancer health checks."
  type        = number
}

variable "public_lb_enabled" {
  description = "Create a public Azure load balancer in front of the CE SLO interfaces."
  type        = bool
}

variable "internal_lb_enabled" {
  description = "Create an internal Azure load balancer in front of the CE SLI interfaces."
  type        = bool
}

variable "public_lb_name" {
  description = "Name of the public Azure load balancer."
  type        = string
}

variable "internal_lb_name" {
  description = "Name of the internal Azure load balancer."
  type        = string
}

variable "public_ip_name" {
  description = "Name of the Azure public IP attached to the public load balancer."
  type        = string
}

variable "public_frontend_name" {
  description = "Frontend IP configuration name for the public load balancer."
  type        = string
}

variable "internal_frontend_name" {
  description = "Frontend IP configuration name for the internal load balancer."
  type        = string
}

variable "internal_frontend_private_ip" {
  description = "Optional static private IP for the internal load balancer frontend."
  type        = string
  default     = null
}

variable "public_backend_ips" {
  description = "Optional explicit CE SLO backend IPs. Leave empty to auto-discover from the outside subnet."
  type        = list(string)
  default     = []
}

variable "internal_backend_ips" {
  description = "Optional explicit CE SLI backend IPs. Leave empty to auto-discover from the inside subnet."
  type        = list(string)
  default     = []
}
