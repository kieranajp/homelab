# Create Traefik resources in all namespaces
resource "helm_release" "traefik_middlewares" {
  for_each = toset(local.namespaces)

  name             = "traefik-middlewares-${each.key}"
  chart            = "./charts/traefik-resources"
  namespace        = each.key
  timeout          = 90
  atomic           = true

  values = [
    templatefile("${path.module}/values/traefik-middlewares.yaml", {
      google_client_id     = var.google_client_id
      google_client_secret = var.google_client_secret
      cookie_secret        = var.cookie_secret
      namespace            = each.key
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
