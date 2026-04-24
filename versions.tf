terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.67.0"
    }
    volterra = {
      source  = "volterraedge/volterra"
      version = "~> 0.11.48"
    }
  }
}
