# Traefik Ingress Controller
# This replaces the K3s bundled Traefik and the HelmChartConfig from Ansible

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "~> 32.0" # Uses Traefik v3
  namespace  = "kube-system"
  timeout    = 300
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

      # Port configuration
      ports = {
        web = {
          port     = 80
          expose   = true
          exposedPort = 80
        }
        websecure = {
          port     = 443
          expose   = true
          exposedPort = 443
        }
        traefik = {
          expose = true
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

      # Service configuration
      service = {
        type = "LoadBalancer"
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
