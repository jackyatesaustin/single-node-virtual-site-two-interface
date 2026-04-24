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

variable "applications" {
  description = "Application-specific origin pools and HTTP load balancers keyed by application identifier."
  type = map(object({
    domains                = list(string)
    origin_pool_name       = string
    http_load_balancer_name = string
    listener_port          = number
    origin_server_type     = string
    origin_server_value    = string
    origin_port            = number
    advertise_network      = string
  }))

  validation {
    condition = alltrue([
      for app in values(var.applications) :
      length(app.domains) > 0 &&
      contains(["private_ip", "private_name"], app.origin_server_type) &&
      contains(
        ["SITE_NETWORK_INSIDE", "SITE_NETWORK_OUTSIDE", "SITE_NETWORK_INSIDE_AND_OUTSIDE"],
        app.advertise_network
      )
    ])
    error_message = "Each application must define at least one domain, use a supported origin_server_type, and use a supported advertise_network."
  }
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
