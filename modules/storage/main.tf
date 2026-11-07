# KAT-648 T-005 — tenant files, in KAT-417's shape (ARD-039): one private container,
# every object under its tenant's prefix, nothing public, and the account answering
# only the cluster's subnet. storage-detection watches it.

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.replication_type
  access_tier              = "Hot"

  https_traffic_only_enabled = true
  # TLS1_2 is the only value Azure Storage accepts as a floor. The product's own
  # client refuses anything below TLS 1.3 (app/core/tls.py, ARD-043).
  min_tls_version = "TLS1_2"

  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true

  # The product reads a connection string from the vault until KAT-418 replaces it
  # with a workload identity (ARD-040; KAT-648 §2 and §8 Q8). Then this goes false.
  shared_access_key_enabled = true

  public_network_access = "Enabled"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["None"]
    ip_rules                   = var.operator_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.delete_retention_days
    }

    container_delete_retention_policy {
      days = var.delete_retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "attachments" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
