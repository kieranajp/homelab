# Cloudflare DNS Records
# CNAME records pointing to the Cloudflare Tunnel

locals {
  tunnel_cname = "${var.cloudflare_tunnel_id}.cfargotunnel.com"

  # Subdomains to route through the tunnel
  tunnel_subdomains = [
    "home",
    "homeassistant",
    "kratos",
    "hydra",
    "hydra-admin",
  ]
}

resource "cloudflare_record" "tunnel_subdomains" {
  for_each = toset(local.tunnel_subdomains)

  zone_id = var.cloudflare_zone_id
  name    = each.value
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
  ttl     = 1  # Auto TTL when proxied

  comment = "Managed by Terraform - Routes to homelab tunnel"
}
