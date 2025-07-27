resource "helm_release" "traefik_resources" {
  name             = "traefik-resources"
  chart            = "./charts/traefik-resources"
  namespace        = "homelab"

  values = [
    templatefile("${path.module}/values/traefik-resources.yaml", {
      google_client_id     = var.google_client_id
      google_client_secret = var.google_client_secret
      cookie_secret        = var.cookie_secret
    })
  ]

  depends_on = [helm_release.homepage]
}
