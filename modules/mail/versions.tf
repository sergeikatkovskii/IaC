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
    # KAT-648 T-005: the SMTP application is an Entra one. 3.10.0 is the newest release
    # at least a week old on 2026-11-07.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10.0"
    }
  }
}
