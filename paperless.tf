resource "helm_release" "paperless_ngx" {
  name      = "paperless-ngx"
  chart     = "./charts/paperless-ngx"
  namespace = "homelab"
  timeout   = 180
  atomic    = true

  values = [
    file("${path.module}/values/paperless-ngx.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      paperless = {
        secretKey = var.paperless_secret_key
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
