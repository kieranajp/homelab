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

resource "helm_release" "lazylibrarian" {
  name      = "lazylibrarian"
  chart     = "./charts/lazylibrarian"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/lazylibrarian.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      nfs = {
        server        = var.nfs.server
        booksPath     = var.nfs.books_path
        downloadsPath = var.nfs.downloads_path
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}

resource "helm_release" "calibre_web_automated" {
  name      = "calibre-web-automated"
  chart     = "./charts/calibre-web-automated"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/calibre-web-automated.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      nfs = {
        server    = var.nfs.server
        booksPath = var.nfs.books_path
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
