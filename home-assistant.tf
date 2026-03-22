resource "kubernetes_secret" "google_service_account" {
  metadata {
    name      = "ha-google-assistant-sa"
    namespace = "homelab"
  }

  data = {
    "SERVICE_ACCOUNT.json" = var.ha_google_assistant_sa
  }
}

resource "helm_release" "home_assistant" {
  name             = "home-assistant"
  repository       = "https://pajikos.github.io/home-assistant-helm-chart"
  chart            = "home-assistant"
  namespace        = "homelab"
  timeout          = 180
  atomic           = true

  values = [
    file("${path.module}/values/home-assistant.yaml")
  ]

  depends_on = [kubernetes_secret.google_service_account]
}
