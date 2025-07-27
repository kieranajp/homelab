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
