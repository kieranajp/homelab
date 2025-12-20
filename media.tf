resource "helm_release" "prowlarr" {
  name      = "prowlarr"
  chart     = "./charts/prowlarr"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/prowlarr.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}

resource "helm_release" "sonarr" {
  name      = "sonarr"
  chart     = "./charts/sonarr"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/sonarr.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      nfs = {
        server        = var.nfs.server
        tvPath        = var.nfs.tv_path
        downloadsPath = var.nfs.downloads_path
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
