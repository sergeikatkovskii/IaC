# KAT-648 T-005 — the committed values are placeholders, and a placeholder must
# fail rather than plan clean (this repository's second rule). Reads the committed
# terraform.tfvars as it stands.
mock_provider "azurerm" {
  # The provider still validates what a mock answers, so ids are shaped as Azure's.
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      object_id       = "33333333-3333-3333-3333-333333333333"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      client_id       = "55555555-5555-5555-5555-555555555555"
    }
  }

  mock_data "azurerm_subscription" {
    defaults = {
      display_name = "AZ2-NonProd"
    }
  }
}
mock_provider "azuread" {}

run "the_committed_values_cannot_be_applied" {
  command = plan

  # The addresses are answered (§8 Q2). What stays refused is what is never
  # committed: this repository is public.
  expect_failures = [
    var.subscription_id,
    var.operator_ip_ranges,
  ]
}

# KAT-648 T-005: the early shape the founder approved (2026-11-07), read from the
# committed values with the two that are never committed given here. B1ms's 35 user
# connections reach tcm's environment.env as DB_MAX_USER_CONNECTIONS, which its pool
# guard holds every pool to (tests/test_k8s_manifests.py).
run "the_committed_shape_is_one_node_and_the_smallest_database" {
  command = plan

  variables {
    subscription_id    = "00000000-0000-0000-0000-000000000000"
    operator_ip_ranges = ["203.0.113.7"]
  }

  assert {
    condition     = output.postgres_max_user_connections == 35
    error_message = "staging's database is B1ms, whose 35 connections the pools are sized for."
  }
}
