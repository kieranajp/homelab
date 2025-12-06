# Traefik Ingress Controller

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
          port = 8000
          exposedPort = 80
          hostPort = 80  # Bind directly to host's port 80
        }
        websecure = {
          port = 8443
          exposedPort = 443
          hostPort = 443  # Bind directly to host's port 443
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
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
