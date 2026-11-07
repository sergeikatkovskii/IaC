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
}

provider "azuread" {}
