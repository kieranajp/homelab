# Temporarily disabled - backup at openclaw-config-backup.tar.gz
# resource "helm_release" "openclaw" {
#   name      = "openclaw"
#   chart     = "./charts/openclaw"
#   namespace = "agents"
#   timeout   = 300
#   atomic    = true
#
#   values = [
#     file("${path.module}/values/openclaw.yaml"),
#     yamlencode({
#       agent = {
#         model = var.openclaw_model
#       }
#       secrets = {
#         OPENCLAW_GATEWAY_TOKEN = var.openclaw_gateway_token
#         ANTHROPIC_API_KEY      = var.anthropic_api_key
#         GEMINI_API_KEY         = var.gemini_api_key
#         TELEGRAM_BOT_TOKEN     = var.telegram_bot_token
#         GITHUB_TOKEN           = var.openclaw_github_token
#         ONEPASSWORD_TOKEN      = var.onepassword_token
#
#         GOOGLE_CLIVE_CLIENT_ID     = var.google_clive_client_id
#         GOOGLE_CLIVE_CLIENT_SECRET = var.google_clive_client_secret
#         GOOGLE_CLIVE_REFRESH_TOKEN = var.google_clive_refresh_token
#       }
#     })
#   ]
#
#   depends_on = [kubernetes_namespace.namespaces]
# }
