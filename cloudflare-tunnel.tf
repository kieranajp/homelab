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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.cloudflare_tunnel_id

  config {
    # Wildcard route for all *.kieranajp.uk to Traefik
    ingress_rule {
      hostname = "*.kieranajp.uk"
      service  = "http://traefik.kube-system.svc.cluster.local:80"
    }

    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}
