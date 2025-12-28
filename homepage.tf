resource "helm_release" "homepage" {
  name             = "homepage"
  repository       = "oci://oci.trueforge.org/truecharts"
  chart            = "homepage"
  version          = "10.3.0"
  namespace        = "homelab"

  values = [
    file("${path.module}/values/homepage.yaml")
  ]
}
