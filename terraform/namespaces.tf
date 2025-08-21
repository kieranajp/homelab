resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}
