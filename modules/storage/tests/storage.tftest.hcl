# KAT-648 T-005 — tenant files, in KAT-417's shape (ARD-039).
mock_provider "azurerm" {}

variables {
  name                = "katachitestdata01"
  resource_group_name = "katachi-test"
  location            = "centralus"
  allowed_subnet_ids  = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks"]
  operator_ip_ranges  = ["203.0.113.7"]
}

run "nothing_is_public" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false && azurerm_storage_container.attachments.container_access_type == "private"
    error_message = "No container and no blob can be made public (ARD-039 §4)."
  }

  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    error_message = "The account answers only the cluster's subnet and the operator's addresses."
  }
}

run "https_only_and_encrypted_twice" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled && azurerm_storage_account.this.infrastructure_encryption_enabled
    error_message = "HTTPS only, and a second layer of encryption at rest."
  }

  assert {
    condition     = azurerm_storage_account.this.cross_tenant_replication_enabled == false
    error_message = "Nothing copies these objects to another tenant."
  }
}

run "a_delete_can_be_undone_for_a_week" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].versioning_enabled && azurerm_storage_account.this.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "Versioning, and a week to undo a delete."
  }
}

run "the_container_is_the_products" {
  command = plan

  assert {
    condition     = azurerm_storage_container.attachments.name == "tcm-attachments"
    error_message = "AZURE_STORAGE_CONTAINER_NAME defaults to tcm-attachments in backend/app/core/config.py."
  }
}

run "a_placeholder_address_is_refused" {
  command = plan

  variables {
    operator_ip_ranges = ["REPLACE"]
  }

  expect_failures = [var.operator_ip_ranges]
}
