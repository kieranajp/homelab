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

resource "helm_release" "transmission" {
  name      = "transmission"
  chart     = "./charts/transmission"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/transmission.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      vpn = {
        enabled             = true
        provider            = "mullvad"
        wireguardPrivateKey = var.mullvad.wireguard_private_key
        wireguardAddresses  = var.mullvad.wireguard_addresses
        serverCountries     = var.mullvad.server_countries
        inputPorts          = "51413"
        firewallInputPorts  = "9091"
        ports = [
          { name = "web", port = 9091 },
          { name = "peer-tcp", port = 51413, protocol = "TCP" },
          { name = "peer-udp", port = 51413, protocol = "UDP" }
        ]
      }
      auth = {
        username = var.transmission.username
        password = var.transmission.password
      }
      nfs = {
        server        = var.nfs.server
        downloadsPath = var.nfs.downloads_path
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
