# Talos Kubernetes Cluster Configuration
# This replaces the K3s installation from Ansible

provider "talos" {}

# Generate machine secrets (certificates, tokens, etc.)
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Generate controlplane configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.talos_controlplane_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  docs     = false
  examples = false

  config_patches = [
    yamlencode({
      cluster = {
        # Single-node cluster: allow workloads on control plane
        allowSchedulingOnControlPlanes = true

        network = {
          cni = {
            name = "none" # We'll install Cilium via Helm
          }
        }
        proxy = {
          disabled = true # Disable kube-proxy (Cilium handles this)
        }
      }
      machine = {
        network = {
          hostname = var.talos_hostname
        }
        install = {
          disk            = "/dev/sda" # Proxmox VirtIO disk
          image           = "ghcr.io/siderolabs/installer:${var.talos_version}"
          bootloader      = true
          wipe            = false
        }
        kubelet = {
          # Extra args for kubelet if needed
          extraArgs = {}
        }
      }
    })
  ]
}

# Apply configuration to the Talos node
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.talos_controlplane_ip

  config_patches = []
}

# Bootstrap the Kubernetes cluster (one-time operation)
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos_controlplane_ip

  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

# Extract kubeconfig for use by Helm/Kubernetes providers
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos_controlplane_ip

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

# Write kubeconfig to local file (optional - for manual kubectl access)
resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.root}/talos-kubeconfig"
  file_permission = "0600"

  depends_on = [
    talos_cluster_kubeconfig.this
  ]
}

# Generate talosconfig for talosctl CLI access
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.talos_controlplane_ip]
}

# Write talosconfig to local file (for talosctl access)
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.root}/talosconfig"
  file_permission = "0600"
}

# Output useful information
output "talos_controlplane_ip" {
  description = "IP address of Talos controlplane node"
  value       = var.talos_controlplane_ip
}

output "kubeconfig_path" {
  description = "Path to generated kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "talosconfig_path" {
  description = "Path to generated talosconfig file"
  value       = local_file.talosconfig.filename
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://${var.talos_controlplane_ip}:6443"
}
