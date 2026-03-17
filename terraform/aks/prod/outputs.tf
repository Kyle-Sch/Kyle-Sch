###############################################################################
# AKS Cluster — outputs.tf
###############################################################################

output "cluster_name" {
  description = "Name of the provisioned AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "resource_group_name" {
  description = "Resource group that contains the cluster."
  value       = azurerm_resource_group.aks.name
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster. Store securely — do not log."
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_fqdn" {
  description = "FQDN of the AKS API server."
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "node_resource_group" {
  description = "Auto-generated resource group that holds AKS node pool VMs."
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity (used to grant ACR pull rights)."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "oms_agent_identity_object_id" {
  description = "Object ID of the OMS agent managed identity."
  value       = azurerm_kubernetes_cluster.aks.oms_agent[0].oms_agent_identity[0].object_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster (needed for federated identity setup)."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace (used by APIM App Insights)."
  value       = azurerm_log_analytics_workspace.aks.id
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS node subnet."
  value       = azurerm_subnet.aks_nodes.id
}

output "vnet_id" {
  description = "Resource ID of the AKS virtual network."
  value       = azurerm_virtual_network.aks.id
}

# ---------------------------------------------------------------------------
# Workload Identity
# ---------------------------------------------------------------------------
output "fastapi_workload_identity_client_id" {
  description = "Client ID of the FastAPI user-assigned managed identity."
  value       = azurerm_user_assigned_identity.fastapi.client_id
}

output "fastapi_workload_identity_principal_id" {
  description = "Principal ID of the FastAPI managed identity."
  value       = azurerm_user_assigned_identity.fastapi.principal_id
}

# ---------------------------------------------------------------------------
# App Deployment
# ---------------------------------------------------------------------------
output "app_namespace" {
  description = "Kubernetes namespace the FastAPI app is deployed into."
  value       = kubernetes_namespace.api.metadata[0].name
}

output "app_service_name" {
  description = "Kubernetes service name for the FastAPI backend."
  value       = kubernetes_service.fastapi.metadata[0].name
}

output "app_deployment_name" {
  description = "Kubernetes deployment name for the FastAPI app."
  value       = kubernetes_deployment.fastapi.metadata[0].name
}
