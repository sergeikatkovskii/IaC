# KAT-648 T-005 — the committed values are placeholders, and a placeholder must
# fail rather than plan clean (this repository's second rule). Reads the committed
# terraform.tfvars as it stands.
mock_provider "azurerm" {}

run "the_committed_values_cannot_be_applied" {
  command = plan

  # The addresses are answered (§8 Q2). What stays refused is what is never
  # committed: this repository is public.
  expect_failures = [
    var.subscription_id,
    var.operator_ip_ranges,
  ]
}
