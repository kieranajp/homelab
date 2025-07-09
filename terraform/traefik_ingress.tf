resource "helm_release" "traefik_ingress" {
  name       = "traefik-ingress"
  chart      = "./charts/ingressroutes"
  namespace  = "homelab"
  create_namespace = false  # Already created by homepage

  values = [
    file("${path.module}/values/traefik-ingress.yaml")
  ]

  depends_on = [helm_release.homepage]
}
