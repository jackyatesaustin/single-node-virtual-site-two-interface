variable "name" {
  description = "Azure CE site name."
  type        = string
}

variable "namespace" {
  description = "Namespace used for the Azure CE site object."
  type        = string
}

variable "tenant_name" {
  description = "F5 XC tenant used in object references."
  type        = string
}

variable "azure_credential_name" {
  description = "Name of the pre-existing Azure credential object."
  type        = string
}

variable "azure_credential_namespace" {
  description = "Namespace of the Azure credential object."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for node access."
  type        = string
}

variable "azure_region" {
  description = "Azure region for the CE site."
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group created or used by the CE site."
  type        = string
}

variable "availability_zone" {
  description = "Azure availability zone for the single-node CE."
  type        = string
}

variable "machine_type" {
  description = "Azure VM size used by the CE node."
  type        = string
}

variable "azure_certified_hw" {
  description = "F5 XC Azure hardware profile."
  type        = string
}

variable "performance_mode" {
  description = "Performance mode for the CE data plane."
  type        = string

  validation {
    condition     = contains(["l3", "l7"], var.performance_mode)
    error_message = "performance_mode must be either \"l3\" or \"l7\"."
  }
}

variable "vnet_cidr" {
  description = "CIDR used when creating a new VNet."
  type        = string
}

variable "vnet_name" {
  description = "Optional explicit name for a new VNet."
  type        = string
  default     = null
}

variable "inside_subnet_cidr" {
  description = "SLI subnet CIDR."
  type        = string
}

variable "outside_subnet_cidr" {
  description = "SLO subnet CIDR."
  type        = string
}

variable "use_existing_vnet" {
  description = "Use an existing Azure VNet instead of creating a new one."
  type        = bool
  default     = false
}

variable "existing_vnet_name" {
  description = "Existing VNet name when use_existing_vnet is true."
  type        = string
  default     = null
}

variable "existing_vnet_rgname" {
  description = "Resource group that contains the existing VNet."
  type        = string
  default     = null
}

variable "routing_mode" {
  description = "Route management mode for existing VNets."
  type        = string
  default     = "f5_orchestrated"

  validation {
    condition     = contains(["f5_orchestrated", "manual"], var.routing_mode)
    error_message = "routing_mode must be either \"f5_orchestrated\" or \"manual\"."
  }
}
