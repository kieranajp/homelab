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
}
