# Shared, environment-independent infrastructure: the Terraform state backend the
# other roots use. Nothing that belongs to a single environment goes here.

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                = var.state_account_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  # State is the most sensitive thing in this repo: it holds resource ids and can
  # hold secrets in plaintext. None of these three is optional.
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true # tighten to a private endpoint when a VNet exists
  min_tls_version                 = "TLS1_2"

  # Terraform's own locking protects against two concurrent applies; versioning is
  # what protects against a corrupted or truncated state being written over a good
  # one, which locking cannot help with.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
