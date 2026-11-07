# KAT-648 T-005 — the registry.
mock_provider "azurerm" {}

variables {
  name                = "katachitestreg01"
  resource_group_name = "katachi-test"
  location            = "centralus"
  pull_principal_ids  = { kubelet = "11111111-1111-1111-1111-111111111111" }
  push_principal_ids  = { pipeline = "22222222-2222-2222-2222-222222222222" }
}

run "the_admin_user_and_anonymous_pull_are_off" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this.admin_enabled == false
    error_message = "The admin user is one shared password for the whole registry. It stays off."
  }

  assert {
    condition     = azurerm_container_registry.this.anonymous_pull_enabled == false
    error_message = "Nobody pulls an image without signing in."
  }
}

run "pull_and_push_go_only_where_named" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.pull) == 1 && azurerm_role_assignment.pull["kubelet"].role_definition_name == "AcrPull" && azurerm_role_assignment.pull["kubelet"].principal_id == "11111111-1111-1111-1111-111111111111"
    error_message = "Only the cluster's kubelet identity pulls."
  }

  assert {
    condition     = length(azurerm_role_assignment.push) == 1 && azurerm_role_assignment.push["pipeline"].role_definition_name == "AcrPush" && azurerm_role_assignment.push["pipeline"].principal_id == "22222222-2222-2222-2222-222222222222"
    error_message = "Only the pipeline pushes."
  }
}
