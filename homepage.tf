resource "helm_release" "homepage" {
  name  = "homepage"
  chart = local.cached_chart["homepage"]
  namespace        = "homelab"

  values = [
    file("${path.module}/values/homepage.yaml")
  ]
}
