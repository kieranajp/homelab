resource "helm_release" "plex" {
  name       = "plex"
  repository = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart      = "plex-media-server"
  namespace  = "homelab"
  timeout    = 120
  atomic     = true

  values = [
    file("${path.module}/values/plex.yaml"),
    yamlencode({
      extraEnv = {
        PLEX_UID   = var.nfs.puid
        PLEX_GID   = var.nfs.pgid
        PLEX_CLAIM = var.plex_claim_token
      }
      extraVolumes = [
        {
          name = "tv"
          nfs = {
            server = var.nfs.server
            path   = var.nfs.tv_path
          }
        },
        {
          name = "movies"
          nfs = {
            server = var.nfs.server
            path   = var.nfs.movies_path
          }
        }
      ]
      extraVolumeMounts = [
        {
          name      = "tv"
          mountPath = "/tv"
        },
        {
          name      = "movies"
          mountPath = "/movies"
        }
      ]
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
