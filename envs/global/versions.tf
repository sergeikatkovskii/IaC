terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12.0"
    }
  }

  # Deliberately NO backend block. This root is the chicken-and-egg one: it
  # CREATES the storage account the other roots keep their state in, so it cannot
  # keep its own state there before it exists. It runs on local state, and
  # terraform.tfstate in this directory is therefore a real artefact — see README.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
