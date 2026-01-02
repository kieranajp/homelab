# Cloudflare DNS Records

resource "cloudflare_record" "wildcard_subdomain" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = var.cluster_public_ip
  type    = "A"
  proxied = false
  ttl     = 300

  comment = "Managed by Terraform - Routes to homelab"

  lifecycle {
    ignore_changes = [content]
  }
}

# Dynamic DNS updater to keep the wildcard record in sync with public IP
resource "kubernetes_deployment" "cloudflare_ddns" {
  metadata {
    name      = "cloudflare-ddns"
    namespace = "kube-system"
    labels = {
      app = "cloudflare-ddns"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflare-ddns"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflare-ddns"
        }
      }

      spec {
        container {
          name  = "cloudflare-ddns"
          image = "favonia/cloudflare-ddns:1.15.0"

          env {
            name = "CLOUDFLARE_API_TOKEN"
            value_from {
              secret_key_ref {
                name = "cloudflare-api-token"
                key  = "api-token"
              }
            }
          }

          env {
            name  = "DOMAINS"
            value = "*.kieranajp.uk"
          }

          env {
            name  = "PROXIED"
            value = "false"
          }

          env {
            name  = "IP6_PROVIDER"
            value = "none"
          }

          security_context {
            read_only_root_filesystem = true
            run_as_non_root           = true
            run_as_user               = 1000
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.traefik
  ]
}
