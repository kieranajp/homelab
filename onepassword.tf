resource "helm_release" "onepassword" {
  name       = "onepassword-connect"
  repository = "https://1password.github.io/connect-helm-charts"
  chart      = "connect"
  version    = "2.2.1"
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
