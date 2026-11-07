# KAT-648 T-005 — a vault.
mock_provider "azurerm" {}

variables {
  name                 = "kat-test-app-x1y2z"
  resource_group_name  = "katachi-test"
  location             = "centralus"
  tenant_id            = "00000000-0000-0000-0000-000000000001"
  allowed_subnet_ids   = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks"]
  operator_ip_ranges   = ["203.0.113.7"]
  reader_principal_ids = { backend = "11111111-1111-1111-1111-111111111111" }
  writer_principal_ids = { operator = "33333333-3333-3333-3333-333333333333" }
}

run "rights_are_role_assignments_and_a_purge_cannot_happen" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled == true
    error_message = "Rights to the vault are Azure role assignments, not access policies."
  }

  assert {
    condition     = azurerm_key_vault.this.purge_protection_enabled == true && azurerm_key_vault.this.soft_delete_retention_days == 90
    error_message = "A deleted vault must be recoverable for 90 days, and nobody may purge it early."
  }
}

run "the_network_is_default_deny" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.network_acls[0].default_action == "Deny" && azurerm_key_vault.this.network_acls[0].bypass == "None"
    error_message = "The vault answers only the cluster's subnet and the operator's addresses."
  }

  assert {
    condition     = contains(azurerm_key_vault.this.network_acls[0].ip_rules, "203.0.113.7")
    error_message = "The operator's address is admitted, so a person can write the values."
  }
}

run "readers_read_and_writers_write" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.reader["backend"].role_definition_name == "Key Vault Secrets User"
    error_message = "A unit reads secrets and does nothing else."
  }

  assert {
    condition     = azurerm_role_assignment.writer["operator"].role_definition_name == "Key Vault Secrets Officer"
    error_message = "The operator writes the values."
  }
}

run "a_placeholder_address_is_refused" {
  command = plan

  variables {
    operator_ip_ranges = ["REPLACE"]
  }

  expect_failures = [var.operator_ip_ranges]
}
