resource "helm_release" "tailscale" {
  name       = "tailscale"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.84.2"
  namespace  = "tailscale"
  create_namespace = true

  values = [
    templatefile("${path.module}/values/tailscale.yaml", {
      oauth_client_id     = var.tailscale_oauth_client_id
      oauth_client_secret = var.tailscale_oauth_client_secret
    })
  ]
}
