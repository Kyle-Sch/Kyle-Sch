###############################################################################
# service.tf — Kubernetes ClusterIP Service
# APIM backend URL is set to http://worker-service.api.svc.cluster.local:8080
###############################################################################

resource "kubernetes_service" "fastapi" {
  metadata {
    name      = "worker-service"
    namespace = kubernetes_namespace.api.metadata[0].name

    labels = {
      "app"                          = "fastapi"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      app = "fastapi"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
