resource "helm_release" "cloudflare-tunnel" {
  name             = "cloudflare-tunnel"
  repository       = "https://cloudflare.github.io/helm-charts"
  chart            = "cloudflare-tunnel"
  namespace        = "homelab"

  values = [
    templatefile("${path.module}/values/cloudflare-tunnel.yaml", {
      cloudflare_account_id    = var.cloudflare_account_id
      cloudflare_tunnel_id     = var.cloudflare_tunnel_id
      cloudflare_tunnel_name   = var.cloudflare_tunnel_name
      cloudflare_tunnel_secret = var.cloudflare_tunnel_secret
    })
  ]
}
