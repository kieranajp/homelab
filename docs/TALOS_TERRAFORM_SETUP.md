# Talos Terraform Setup Guide

This guide covers bootstrapping a Talos Kubernetes cluster using Terraform.

## Prerequisites

- Talos VM created and running on Proxmox (see [PROXMOX_TALOS_VM.md](PROXMOX_TALOS_VM.md))
- Talos VM IP address noted (check Proxmox console or DHCP leases)
- Terraform/OpenTofu installed locally
- Access to Proxmox network from your workstation

## Overview

The Terraform configuration in this repository will:

1. Generate Talos machine secrets (PKI, tokens)
2. Create machine configuration for the controlplane node
3. Apply configuration to the Talos VM
4. Bootstrap the Kubernetes cluster
5. Extract kubeconfig for application deployment
6. Deploy Traefik and all your applications

## Initial Setup

### 1. Update Configuration

Edit `terraform/terraform.tfvars` (create from example if needed):

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Update the Talos-specific variables:

```hcl
# Talos Linux configuration
talos_version          = "v1.9.0"
cluster_name           = "seldon"
talos_controlplane_ip  = "192.168.1.57"  # YOUR TALOS VM IP
talos_hostname         = "talos-cp1"
```

### 2. Initialize Terraform

```bash
cd terraform
tofu init
```

This will download:
- Talos provider
- Helm provider
- Kubernetes provider
- Local provider

### 3. Review the Plan

```bash
tofu plan
```

You should see resources being created:
- `talos_machine_secrets.this`
- `talos_machine_configuration_apply.controlplane`
- `talos_machine_bootstrap.this`
- All your existing Helm releases (Traefik, Victoria Metrics, etc.)

### 4. Apply Configuration

```bash
tofu apply
```

**What happens:**
1. Generates machine secrets (~5 seconds)
2. Applies configuration to Talos VM (~30 seconds)
3. Installs Talos to disk (~60 seconds)
4. Reboots Talos VM (~30 seconds)
5. Bootstraps Kubernetes (~90 seconds)
6. Deploys Traefik (~30 seconds)
7. Deploys all applications (~2-5 minutes)

**Total time:** ~5-8 minutes for full cluster + apps

## Post-Bootstrap

### Generated Files

Terraform will create:

- `terraform/talos-kubeconfig` - Kubernetes access (chmod 600)
- `terraform/talosconfig` - Talos API access (chmod 600)

### Access Kubernetes

```bash
# Using generated kubeconfig
export KUBECONFIG=./talos-kubeconfig
kubectl get nodes

# Or copy to default location
cp talos-kubeconfig ~/.kube/config
kubectl get nodes
```

### Access Talos API

```bash
# Export talosconfig
export TALOSCONFIG=./talosconfig

# Check Talos health
talosctl health --nodes 192.168.1.57

# View logs
talosctl logs --nodes 192.168.1.57

# Interactive dashboard
talosctl dashboard --nodes 192.168.1.57
```

### Verify Cluster

```bash
# Check nodes
kubectl get nodes
# Should show: talos-cp1   Ready   control-plane   <age>

# Check system pods
kubectl get pods -A
# Should show: kube-system pods running

# Check your apps
kubectl get pods -n apps
kubectl get pods -n monitoring
kubectl get pods -n auth
```

## Cluster Configuration

### CNI (Container Network Interface)

The configuration includes `cni.name = "none"`, which means:
- Kubernetes networking is NOT configured by default
- You need to install a CNI plugin

**Options:**

#### Option 1: Cilium (Recommended)
```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.16.5 \
  --namespace kube-system \
  --set kubeProxyReplacement=true
```

#### Option 2: Flannel (Simple)
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### Option 3: Let Talos handle it
Remove the CNI config patch in `talos-cluster.tf`:
```hcl
# Remove or comment out:
# cni = {
#   name = "none"
# }
```

Then re-apply:
```bash
tofu apply
```

### Kube-Proxy

Currently disabled (`proxy.disabled = true`) because modern CNIs (like Cilium) handle this.

If you use Flannel or another CNI that needs kube-proxy, remove that config patch.

## Operating the Cluster

### Talos OS Upgrades

```bash
# Check current version
talosctl version --nodes 192.168.1.57

# Upgrade Talos OS
talosctl upgrade \
  --nodes 192.168.1.57 \
  --image ghcr.io/siderolabs/installer:v1.9.1

# Update Terraform variable after successful upgrade
# In terraform.tfvars:
talos_version = "v1.9.1"

# Apply to update stored config
tofu apply
```

### Kubernetes Upgrades

```bash
# Upgrade Kubernetes version
talosctl upgrade-k8s \
  --nodes 192.168.1.57 \
  --to 1.32.0

# This handles:
# - Draining nodes
# - Upgrading control plane
# - Upgrading kubelets
# - Uncordoning nodes
```

### Configuration Changes

To modify Talos configuration:

1. Edit `talos-cluster.tf` config_patches
2. Run `tofu apply`
3. Talos will apply changes (may reboot if needed)

### Backup

**Critical files to backup:**
- `terraform/terraform.tfvars` (secrets)
- `terraform/terraform.tfstate` (cluster state)

**Do NOT commit:**
- `terraform.tfvars` (contains secrets)
- `terraform.tfstate` (contains sensitive data)
- `talos-kubeconfig` (cluster access)
- `talosconfig` (Talos API access)

Add to `.gitignore`:
```
terraform/*.tfvars
terraform/*.tfstate*
terraform/talos-kubeconfig
terraform/talosconfig
```

## Troubleshooting

### Talos VM Not Responding

```bash
# Check if Talos is reachable
ping 192.168.1.57

# Check Talos API
talosctl version --nodes 192.168.1.57

# View Proxmox console
# Proxmox UI → VM → Console
```

### Bootstrap Stuck

```bash
# Check bootstrap status
talosctl bootstrap --nodes 192.168.1.57

# View Talos logs
talosctl logs --nodes 192.168.1.57 -f

# Check etcd
talosctl etcd status --nodes 192.168.1.57
```

### Application Not Starting

```bash
# Check Helm releases
helm list -A

# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Terraform State Issues

If you need to rebuild but keep your apps:

```bash
# Remove just Talos resources from state
tofu state rm talos_machine_secrets.this
tofu state rm talos_machine_configuration_apply.controlplane
tofu state rm talos_machine_bootstrap.this

# Re-apply will recreate cluster
tofu apply
```

## Disaster Recovery

### Full Cluster Rebuild

If you need to completely rebuild:

1. **Backup Terraform state:**
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Destroy cluster:**
   ```bash
   tofu destroy
   ```

3. **Recreate Proxmox VM** (see PROXMOX_TALOS_VM.md)

4. **Update IP if changed:**
   ```bash
   # In terraform.tfvars
   talos_controlplane_ip = "new.ip.address"
   ```

5. **Re-apply:**
   ```bash
   tofu apply
   ```

### Secrets Recovery

All secrets are in `talos_machine_secrets` resource. If you lose state:
- Cluster PKI is lost
- You'll need to rebuild from scratch
- **Keep backups of `terraform.tfstate`!**

## Next Steps

After cluster is up:

1. ✅ Install CNI (Cilium or Flannel)
2. ✅ Verify all pods are running
3. ✅ Test ingress (access Grafana, Home Assistant, etc.)
4. ✅ Set up regular backups (Velero recommended)
5. ✅ Add monitoring for Talos itself
6. ✅ Plan for adding worker nodes (future expansion)

## Adding Worker Nodes

When you add more VMs to the cluster:

1. Create new Proxmox VM (same process)
2. Add to `talos-cluster.tf`:

```hcl
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.talos_controlplane_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = "192.168.1.XX" # Worker IP

  depends_on = [talos_machine_bootstrap.this]
}
```

3. Apply: `tofu apply`
4. Worker joins automatically

## Resources

- Talos Documentation: https://www.talos.dev/
- Talos Terraform Provider: https://registry.terraform.io/providers/siderolabs/talos/latest/docs
- Kubernetes Documentation: https://kubernetes.io/docs/
