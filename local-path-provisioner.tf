resource "helm_release" "local_path_provisioner" {
  name      = "local-path-provisioner"
  chart     = "./charts/local-path-provisioner"
  namespace = "kube-system"
  timeout   = 60
  atomic    = true

  values = [
    yamlencode({
      storageClass = {
        defaultClass = true
      }
    })
  ]

  depends_on = [
    helm_release.cilium
  ]
}
