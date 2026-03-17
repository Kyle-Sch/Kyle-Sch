###############################################################################
# service_account.tf — Kubernetes ServiceAccount with Workload Identity
###############################################################################

resource "kubernetes_service_account" "fastapi" {
  metadata {
    name      = var.fastapi_service_account_name
    namespace = kubernetes_namespace.api.metadata[0].name

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.fastapi.client_id
    }

    labels = {
      "azure.workload.identity/use"  = "true"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
