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
  description = "Legacy single-application domain exposed by the XC HTTP load balancer."
  type        = string
  default     = null
}

variable "listener_port" {
  description = "Legacy default listener port exposed by the HTTP load balancer."
  type        = number
  default     = 80

  validation {
    condition     = var.listener_port >= 1 && var.listener_port <= 65535
    error_message = "listener_port must be between 1 and 65535."
  }
}

variable "origin_server_type" {
  description = "Legacy default origin addressing model. Use private_ip for a site-local RFC1918 IP or private_name for a site-local DNS name."
  type        = string
  default     = "private_ip"

  validation {
    condition     = contains(["private_ip", "private_name"], var.origin_server_type)
    error_message = "origin_server_type must be either \"private_ip\" or \"private_name\"."
  }
}

variable "origin_server_value" {
  description = "Legacy default origin IP or DNS name that is reachable via the Virtual Site inside network."
  type        = string
  default     = null
}

variable "origin_port" {
  description = "Legacy default origin port exposed by the application behind each CE site."
  type        = number
  default     = 80

  validation {
    condition     = var.origin_port >= 1 && var.origin_port <= 65535
    error_message = "origin_port must be between 1 and 65535."
  }
}

variable "advertise_network" {
  description = "Legacy default advertisement network for single-app mode."
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

variable "applications" {
  description = "Application-specific XC HTTP load balancers and origin pools. Each app can advertise on inside, outside, or both networks."
  type = map(object({
    domains             = list(string)
    listener_port       = optional(number)
    origin_server_type  = optional(string)
    origin_server_value = string
    origin_port         = optional(number)
    advertise_network   = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for app in values(var.applications) : contains(
        ["private_ip", "private_name"],
        coalesce(app.origin_server_type, var.origin_server_type)
      )
    ])
    error_message = "Each application origin_server_type must be private_ip or private_name."
  }

  validation {
    condition = alltrue([
      for app in values(var.applications) : contains(
        [
          "SITE_NETWORK_INSIDE",
          "SITE_NETWORK_OUTSIDE",
          "SITE_NETWORK_INSIDE_AND_OUTSIDE",
        ],
        coalesce(app.advertise_network, var.advertise_network)
      )
    ])
    error_message = "Each application advertise_network must be SITE_NETWORK_INSIDE, SITE_NETWORK_OUTSIDE, or SITE_NETWORK_INSIDE_AND_OUTSIDE."
  }

  validation {
    condition = alltrue([
      for app in values(var.applications) :
      length(app.domains) > 0 &&
      alltrue([for domain in app.domains : length(trimspace(domain)) > 0]) &&
      coalesce(app.listener_port, var.listener_port) >= 1 && coalesce(app.listener_port, var.listener_port) <= 65535
    ])
    error_message = "Each application must define at least one non-empty domain and listener_port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for app in values(var.applications) :
      coalesce(app.origin_port, var.origin_port) >= 1 && coalesce(app.origin_port, var.origin_port) <= 65535
    ])
    error_message = "Each application origin_port must be between 1 and 65535."
  }
}

variable "default_create_public_load_balancer" {
  description = "Create a public Azure load balancer per CE site by default."
  type        = bool
  default     = false
}

variable "default_create_internal_load_balancer" {
  description = "Create an internal Azure load balancer per CE site by default."
  type        = bool
  default     = false
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
    create_public_load_balancer  = optional(bool)
    create_internal_load_balancer = optional(bool)
    internal_frontend_private_ip = optional(string)
    azure_lb_public_listener_ports = optional(list(number))
    azure_lb_internal_listener_ports = optional(list(number))
    azure_lb_public_probe_port   = optional(number)
    azure_lb_internal_probe_port = optional(number)
    azure_lb_inside_backend_ips  = optional(list(string))
    azure_lb_outside_backend_ips = optional(list(string))
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

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      !(
        coalesce(site.create_public_load_balancer, var.default_create_public_load_balancer) ||
        coalesce(site.create_internal_load_balancer, var.default_create_internal_load_balancer)
      ) || coalesce(site.use_existing_vnet, false) || site.vnet_name != null
    ])
    error_message = "Each CE site that enables Azure load balancers must set vnet_name or use_existing_vnet with existing_vnet_name."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      alltrue([
        for port in coalesce(site.azure_lb_public_listener_ports, []) :
        port >= 1 && port <= 65535
      ])
    ])
    error_message = "Each azure_lb_public_listener_ports entry must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      alltrue([
        for port in coalesce(site.azure_lb_internal_listener_ports, []) :
        port >= 1 && port <= 65535
      ])
    ])
    error_message = "Each azure_lb_internal_listener_ports entry must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      coalesce(site.azure_lb_public_probe_port, var.listener_port) >= 1 &&
      coalesce(site.azure_lb_public_probe_port, var.listener_port) <= 65535
    ])
    error_message = "Each azure_lb_public_probe_port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for site in values(var.ce_sites) :
      coalesce(site.azure_lb_internal_probe_port, var.listener_port) >= 1 &&
      coalesce(site.azure_lb_internal_probe_port, var.listener_port) <= 65535
    ])
    error_message = "Each azure_lb_internal_probe_port must be between 1 and 65535."
  }
}
