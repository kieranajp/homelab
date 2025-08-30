resource "kubernetes_secret" "ghcr_secret" {
  for_each = toset(["homelab", "apps"])

  metadata {
    name      = "ghcr-secret"
    namespace = each.key
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = "kieranajp"
          password = var.github_token
          auth     = base64encode("kieranajp:${var.github_token}")
        }
      }
    })
  }
}
