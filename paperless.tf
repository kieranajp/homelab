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
      nfs = {
        server   = var.nfs.server
        docsPath = var.nfs.docs_path
      }
      paperless = {
        secretKey = var.paperless_secret_key
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
