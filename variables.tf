variable "deployment_name" {
  description = "Prefix used for the CE sites and XC application objects."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", lower(var.deployment_name)))
    error_message = "deployment_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "tenant_name" {
  description = "F5 XC tenant name used in cross-object references."
  type        = string
}

variable "xc_namespace" {
  description = "Namespace for the CE sites, virtual site, origin pool, and HTTP load balancer."
  type        = string
  default     = "system"
}

variable "azure_credential_name" {
  description = "Name of the pre-existing F5 XC Azure credential object."
  type        = string
}

variable "azure_credential_namespace" {
  description = "Namespace that contains the Azure credential object."
  type        = string
  default     = "system"
}

variable "ssh_public_key" {
  description = "SSH public key injected into each Azure CE node."
  type        = string
}

variable "default_machine_type" {
  description = "Default Azure VM size for the CE nodes."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "default_azure_certified_hw" {
  description = "Default F5 XC certified hardware profile for Azure CE."
  type        = string
  default     = "azure-byol-voltmesh"
}

variable "default_performance_mode" {
  description = "Default CE performance mode."
  type        = string
  default     = "l7"

  validation {
    condition     = contains(["l3", "l7"], var.default_performance_mode)
    error_message = "default_performance_mode must be either \"l3\" or \"l7\"."
  }
}

variable "site_label_namespace" {
  description = "Namespace used for the XC known label key and value."
  type        = string
  default     = "shared"
}

variable "site_label_key" {
  description = "Known label key used to group the CE sites into the Virtual Site."
  type        = string
  default     = "vsite-group"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", lower(var.site_label_key)))
    error_message = "site_label_key must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "app_domain" {
  description = "Domain exposed by the XC HTTP load balancer."
  type        = string
}

variable "listener_port" {
  description = "Listener port exposed by the HTTP load balancer."
  type        = number
  default     = 80

  validation {
    condition     = var.listener_port >= 1 && var.listener_port <= 65535
    error_message = "listener_port must be between 1 and 65535."
  }
}

variable "origin_server_type" {
  description = "Origin addressing model. Use private_ip for a site-local RFC1918 IP or private_name for a site-local DNS name."
  type        = string
  default     = "private_ip"

  validation {
    condition     = contains(["private_ip", "private_name"], var.origin_server_type)
    error_message = "origin_server_type must be either \"private_ip\" or \"private_name\"."
  }
}

variable "origin_server_value" {
  description = "Origin IP or DNS name that is reachable via the Virtual Site inside network."
  type        = string
}

variable "origin_port" {
  description = "Port exposed by the origin application behind each CE site."
  type        = number
  default     = 80

  validation {
    condition     = var.origin_port >= 1 && var.origin_port <= 65535
    error_message = "origin_port must be between 1 and 65535."
  }
}

variable "advertise_network" {
  description = "Where the HTTP load balancer VIP is advertised on the Virtual Site. Defaults to both inside and outside networks so the CE can proxy internal and external client traffic."
  type        = string
  default     = "SITE_NETWORK_INSIDE_AND_OUTSIDE"

  validation {
    condition = contains(
      [
        "SITE_NETWORK_INSIDE",
        "SITE_NETWORK_OUTSIDE",
        "SITE_NETWORK_INSIDE_AND_OUTSIDE",
      ],
      var.advertise_network
    )
    error_message = "advertise_network must be SITE_NETWORK_INSIDE, SITE_NETWORK_OUTSIDE, or SITE_NETWORK_INSIDE_AND_OUTSIDE."
  }
}

variable "ce_sites" {
  description = "Azure CE site definitions keyed by a short site identifier such as ce1 or ce2."
  type = map(object({
    azure_region                 = string
    resource_group               = string
    availability_zone            = string
    vnet_cidr                    = string
    inside_subnet_cidr           = string
    outside_subnet_cidr          = string
    machine_type                 = optional(string)
    azure_certified_hw           = optional(string)
    performance_mode             = optional(string)
    use_existing_vnet            = optional(bool)
    existing_vnet_name           = optional(string)
    existing_vnet_resource_group = optional(string)
    vnet_name                    = optional(string)
    routing_mode                 = optional(string)
  }))

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) : contains(
        ["f5_orchestrated", "manual"],
        coalesce(site.routing_mode, "f5_orchestrated")
      )
    ])
    error_message = "Each CE site routing_mode must be either \"f5_orchestrated\" or \"manual\"."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) : contains(
        ["l3", "l7"],
        coalesce(site.performance_mode, var.default_performance_mode)
      )
    ])
    error_message = "Each CE site performance_mode must be either \"l3\" or \"l7\"."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      !coalesce(site.use_existing_vnet, false) || site.existing_vnet_name != null
    ])
    error_message = "Each CE site using an existing VNet must set existing_vnet_name."
  }
}
