# Traefik Ingress Controller

resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "kube-system"
  }

  data = {
    api-token = var.cloudflare_api_token
  }
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "37.4.0"
  namespace  = "kube-system"
  timeout    = 90
  atomic     = true

  # Traefik configuration migrated from roles/internal/k3s/templates/traefik-config.yaml.j2
  values = [
    yamlencode({
      # Experimental features for plugin support
      experimental = {
        plugins = {
          google-oidc-auth-middleware = {
            moduleName = "github.com/andrewkroh/google-oidc-auth-middleware"
            version    = "v0.2.0"
          }
        }
      }

      # Additional arguments for Traefik
      additionalArguments = [
        "--api",
        "--api.dashboard=true",
        "--api.insecure=true"
      ]

      # Port configuration - use hostPort for direct :80/:443 access
      ports = {
        web = {
          port        = 8000
          exposedPort = 80
          hostPort    = 80
          redirections = {
            entryPoint = {
              to        = "websecure"
              scheme    = "https"
              permanent = true
            }
          }
        }
        websecure = {
          port        = 8443
          exposedPort = 443
          hostPort    = 443
        }
      }

      # Provider configuration
      providers = {
        kubernetesCRD = {
          enabled           = true
          allowCrossNamespace = true
        }
        kubernetesIngress = {
          enabled = true
        }
      }

      # Service configuration - ClusterIP since we're using hostPort
      service = {
        type = "ClusterIP"
      }

      # Persistence for ACME certificates
      persistence = {
        enabled = true
        size    = "128Mi"
      }

      # Cloudflare API token for DNS-01 challenge
      env = [{
        name = "CF_DNS_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = "cloudflare-api-token"
            key  = "api-token"
          }
        }
      }]

      # Let's Encrypt certificate resolver
      certificatesResolvers = {
        letsencrypt = {
          acme = {
            email   = var.letsencrypt_email
            storage = "/data/acme.json"
            dnsChallenge = {
              provider = "cloudflare"
            }
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.namespaces,
    kubernetes_secret.cloudflare_api_token
  ]
}
