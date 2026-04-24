variable "tenant_name" {
  description = "F5 XC tenant used in object references."
  type        = string
}

variable "namespace" {
  description = "Namespace for the Virtual Site, Origin Pool, and HTTP load balancer."
  type        = string
}

variable "label_namespace" {
  description = "Namespace that stores the known label key and value."
  type        = string
}

variable "label_key" {
  description = "Known label key used by the Virtual Site selector."
  type        = string
}

variable "label_value" {
  description = "Known label value applied to each CE site."
  type        = string
}

variable "site_names" {
  description = "Azure CE site names keyed by a short site identifier."
  type        = map(string)
}

variable "virtual_site_name" {
  description = "Name of the Virtual Site."
  type        = string
}

variable "origin_pool_name" {
  description = "Name of the Origin Pool."
  type        = string
}

variable "http_load_balancer_name" {
  description = "Name of the HTTP load balancer."
  type        = string
}

variable "app_domain" {
  description = "Domain exposed by the HTTP load balancer."
  type        = string
}

variable "listener_port" {
  description = "Listener port for the HTTP load balancer."
  type        = number
}

variable "origin_server_type" {
  description = "Origin addressing model."
  type        = string

  validation {
    condition     = contains(["private_ip", "private_name"], var.origin_server_type)
    error_message = "origin_server_type must be either \"private_ip\" or \"private_name\"."
  }
}

variable "origin_server_value" {
  description = "Origin IP or DNS name that each CE site can resolve on its inside network."
  type        = string
}

variable "origin_port" {
  description = "Origin port for the backend application."
  type        = number
}

variable "advertise_network" {
  description = "Virtual Site network where the load balancer VIP should be advertised."
  type        = string
}

variable "origin_endpoint_selection" {
  description = "Endpoint selection policy for the origin pool."
  type        = string
  default     = "LOCALPREFERED"
}

variable "origin_loadbalancer_algorithm" {
  description = "Load balancing algorithm used by the origin pool."
  type        = string
  default     = "LB_OVERRIDE"
}
