resource "helm_release" "traefik_ingress" {
  name             = "traefik-ingress"
  chart            = "./charts/ingressroutes"
  namespace        = "homelab"

  values = [
    templatefile("${path.module}/values/traefik-ingress.yaml", {
      google_client_id     = var.google_client_id
      google_client_secret = var.google_client_secret
      cookie_secret        = var.cookie_secret
    })
  ]

  depends_on = [helm_release.homepage]
}
