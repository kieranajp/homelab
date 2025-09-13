# loop over a list of namespaces to create them dynamically
locals {
  namespaces = ["homelab", "monitoring", "apps"]
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(local.namespaces)

  metadata {
    name = each.key
  }
}

resource "kubernetes_secret" "ghcr_secret" {
  for_each = toset(local.namespaces)

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
