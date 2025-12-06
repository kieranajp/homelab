# Cilium CNI
# Must be installed before any workloads that need networking

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.4"
  namespace  = "kube-system"
  timeout    = 600
  atomic     = true

  values = [
    yamlencode({
      # Cilium replaces kube-proxy (which we disabled in Talos config)
      kubeProxyReplacement = true

      # Bootstrap: connect directly to API server via node IP, not service IP
      k8sServiceHost = var.talos_controlplane_ip
      k8sServicePort = 6443

      # Talos-specific: needs privileged mode for init containers
      securityContext = {
        privileged = true
      }

      # Optimized for single-node homelab
      operator = {
        replicas = 1
      }

      # Enable Hubble for observability
      hubble = {
        enabled = true
        relay = {
          enabled = true
        }
        ui = {
          enabled = true
        }
      }
    })
  ]

  # Must wait for Talos cluster to be bootstrapped
  depends_on = [
    talos_machine_bootstrap.this
  ]
}
