resource "helm_release" "syncthing" {
  name      = "syncthing"
  chart     = "./charts/syncthing"
  namespace = "homelab"
  timeout   = 90
  atomic    = true

  values = [
    file("${path.module}/values/syncthing.yaml")
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
