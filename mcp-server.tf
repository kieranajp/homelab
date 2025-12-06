resource "helm_release" "mcp_server" {
  name             = "mcp-server"
  chart            = "./charts/mcp-server"
  namespace        = "homelab"

  values = [
    file("${path.module}/values/mcp-server.yaml")
  ]

  depends_on = [helm_release.homepage, kubernetes_secret.ghcr_secret]
}
