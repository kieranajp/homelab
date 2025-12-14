# Cloudflare DNS Records

resource "cloudflare_record" "tunnel_subdomains" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = var.cluster_public_ip
  type    = "A"
  proxied = false
  ttl     = 300  # Auto TTL when proxied

  comment = "Managed by Terraform - Routes to homelab"
}
