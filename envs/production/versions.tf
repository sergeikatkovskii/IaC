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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.2"
    }
    # KAT-648 T-005: modules/mail's SMTP application, made in the tenant az is signed in to.
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # KAT-418 T-003: where the provider reaches a storage account's data plane, it signs
  # in with Entra and never fetches the account's key. The tenant files account stops
  # taking a key at T-005; this is set while it still does, so that a plan shows any
  # such read before then rather than after. envs/global does the same for state.
  storage_use_azuread = true
}

provider "azuread" {}
