resource "helm_release" "bentopdf" {
  name      = "bentopdf"
  chart     = "./charts/bentopdf"
  namespace = "homelab"
  timeout   = 90
  atomic    = true

  values = [
    file("${path.module}/values/bentopdf.yaml")
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
