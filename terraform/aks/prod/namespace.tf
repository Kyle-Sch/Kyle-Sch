###############################################################################
# namespace.tf — Kubernetes Namespace
###############################################################################

resource "kubernetes_namespace" "api" {
  metadata {
    name = var.fastapi_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}
