resource "helm_release" "homepage" {
  name             = "homepage"
  repository       = "oci://tccr.io/truecharts"
  chart            = "homepage"
  version          = "10.3.0"
  namespace        = "homelab"

  values = [
    file("${path.module}/values/homepage.yaml")
  ]
}
