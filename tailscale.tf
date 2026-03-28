# Tailscale Operator
# Exposes the K8s and Talos APIs over the tailnet via a subnet router,
# enabling CI/CD pipelines (and remote access) without a VPN or port forwarding.

resource "helm_release" "tailscale_operator" {
  name       = "tailscale-operator"
  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = "1.82.0"
  namespace  = "tailscale"
  timeout    = 120
  atomic     = true

  create_namespace = true

  values = [
    templatefile("${path.module}/values/tailscale.yaml", {
      oauth_client_id     = var.tailscale_oauth_client_id
      oauth_client_secret = var.tailscale_oauth_client_secret
    })
  ]

  depends_on = [
    helm_release.cilium
  ]
}

# Subnet router: advertises the Talos node IP so both the K8s API (:6443)
# and Talos API (:50000) are reachable from the tailnet.
resource "kubernetes_manifest" "tailscale_connector" {
  manifest = {
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "Connector"
    metadata = {
      name      = "seldon-subnet-router"
      namespace = "tailscale"
    }
    spec = {
      hostname = "seldon-router"
      subnetRouter = {
        advertiseRoutes = [
          "${var.talos_controlplane_ip}/32"
        ]
      }
    }
  }

  depends_on = [
    helm_release.tailscale_operator
  ]
}
