# KAT-648 T-005 — the log workspace.
mock_provider "azurerm" {}

variables {
  name                = "katachi-test-logs"
  resource_group_name = "katachi-test"
  location            = "centralus"
}

run "ingestion_is_capped_and_keys_are_off" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.daily_quota_gb == 1
    error_message = "A workspace with no daily cap is the bill nobody sees coming."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.local_authentication_enabled == false
    error_message = "Shared-key ingestion must be off: everything that writes here signs in with Entra ID."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30 && azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "Retention is 30 days on the pay-as-you-go tier."
  }
}

run "an_uncapped_workspace_is_refused" {
  command = plan

  variables {
    daily_quota_gb = -1
  }

  expect_failures = [var.daily_quota_gb]
}
