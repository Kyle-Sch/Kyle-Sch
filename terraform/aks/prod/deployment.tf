###############################################################################
# deployment.tf — FastAPI Kubernetes Deployment
###############################################################################

resource "kubernetes_deployment" "fastapi" {
  metadata {
    name      = "fastapi"
    namespace = kubernetes_namespace.api.metadata[0].name

    labels = {
      "app"                          = "fastapi"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "fastapi"
      }
    }

    template {
      metadata {
        labels = {
          "app"                         = "fastapi"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fastapi.metadata[0].name

        # Schedule exclusively on the user node pool, away from system workloads
        node_selector = {
          "nodepool-type" = "user"
        }

        container {
          name  = "fastapi"
          image = "${var.image_repository}:${var.image_tag}"

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          # Key Vault URIs — supplied as variables from the platform (prod/) apply
          env {
            name  = "AZURE_KEYVAULT_INTERNAL_URI"
            value = var.keyvault_internal_uri
          }

          env {
            name  = "AZURE_KEYVAULT_EXTERNAL_URI"
            value = var.keyvault_external_uri
          }

          # Injected by the workload identity webhook; included here for explicitness
          env {
            name  = "AZURE_CLIENT_ID"
            value = azurerm_user_assigned_identity.fastapi.client_id
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  lifecycle {
    # Allow external CI/CD pipelines to update the image tag without Terraform drift
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].image,
    ]
  }
}
