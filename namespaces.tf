# loop over a list of namespaces to create them dynamically
locals {
  namespaces = ["homelab", "monitoring", "apps", "auth", "agents"]
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(local.namespaces)

  metadata {
    name = each.key

    # Monitoring/homelab namespaces need privileged pod security for host access
    labels = contains(["monitoring", "homelab"], each.key) ? {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    } : {}
  }

  # Wait for CNI to be ready before creating namespaces
  depends_on = [
    helm_release.cilium
  ]
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

  depends_on = [
    kubernetes_namespace.namespaces
  ]
}
