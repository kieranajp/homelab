# resource "helm_release" "home_assistant" {
#   name             = "home-assistant"
#   repository       = "https://pajikos.github.io/home-assistant-helm-chart"
#   chart            = "home-assistant"
#   namespace        = "homelab"

#   values = [
#     file("${path.module}/values/home-assistant.yaml")
#   ]
# }
