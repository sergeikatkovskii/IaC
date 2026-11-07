output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_object_id" {
  description = "The identity the nodes pull images as."
  value       = azurerm_user_assigned_identity.kubelet.principal_id
}

output "principal_id" {
  description = "The cluster's own identity, which attaches the load balancer to the gateway's address."
  value       = azurerm_user_assigned_identity.control_plane.principal_id
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "pod_cidr" {
  value = var.pod_cidr
}

output "kubernetes_version" {
  description = "The minor the cluster runs (null: AKS's default)."
  value       = azurerm_kubernetes_cluster.this.kubernetes_version
}
