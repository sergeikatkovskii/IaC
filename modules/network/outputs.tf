output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "postgres_subnet_id" {
  value = azurerm_subnet.postgres.id
}

# Depends on the link, because a Flexible Server created before its zone is linked
# to the network cannot resolve its own name.
output "postgres_private_dns_zone_id" {
  value      = azurerm_private_dns_zone.postgres.id
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}
