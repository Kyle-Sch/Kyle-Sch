###############################################################################
# roles.tf — AKS Workload Identity
###############################################################################

resource "azurerm_user_assigned_identity" "fastapi" {
  name                = "id-fastapi-${var.cluster_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "fastapi" {
  name                = "fic-fastapi-${var.cluster_name}"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.fastapi.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${var.fastapi_namespace}:${var.fastapi_service_account_name}"
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count                = var.acr_id != "" ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
