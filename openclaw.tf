resource "helm_release" "openclaw" {
  name      = "openclaw"
  chart     = "./charts/openclaw"
  namespace = "homelab"
  timeout   = 300
  atomic    = true

  values = [
    file("${path.module}/values/openclaw.yaml"),
    yamlencode({
      agent = {
        model = var.openclaw_model
      }
      secrets = {
        gatewayToken     = var.openclaw_gateway_token
        anthropicApiKey  = var.anthropic_api_key
        geminiApiKey     = var.gemini_api_key
        telegramBotToken = var.telegram_bot_token
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
