output "ip_name" {
  value = azurerm_public_ip.gateway.name
}

output "ip_resource_group" {
  value = azurerm_public_ip.gateway.resource_group_name
}

output "ip_address" {
  value = azurerm_public_ip.gateway.ip_address
}

output "name_servers" {
  description = "Give these to the registrar when the zone is served here. Empty when it is not."
  value       = var.dns_zone_name == "" ? [] : tolist(azurerm_dns_zone.this[0].name_servers)
}

output "zone_name" {
  description = "The zone served here, or empty when DNS lives elsewhere: what records outside this module are written into (KAT-648 T-005: mail's)."
  value       = var.dns_zone_name == "" ? "" : azurerm_dns_zone.this[0].name
}
