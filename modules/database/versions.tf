# A module declares the providers it needs and never configures one (see
# modules/storage-detection/versions.tf). Each constraint admits patches only, so
# a new minor arrives as a reviewed edit, never on its own (ARD-059 §2).
terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }
  }
}
