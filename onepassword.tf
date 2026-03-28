resource "helm_release" "onepassword" {
  name  = "onepassword-connect"
  chart = local.cached_chart["connect"]
  namespace  = "apps"
  timeout    = 120
  atomic     = true

  values = [
    file("${path.module}/values/onepassword.yaml"),
    yamlencode({
      connect = {
        credentials_base64 = base64encode(var.onepassword_credentials)
      }
      operator = {
        token = {
          value = var.onepassword_token
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
