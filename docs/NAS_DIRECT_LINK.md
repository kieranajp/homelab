# NAS Direct Link Setup

Guide for setting up a point-to-point 2.5GbE connection between the Talos cluster and Synology NAS for dedicated storage traffic.

## Why

- Dedicated 2.5GbE bandwidth for NFS traffic (no sharing with LAN)
- Lower latency (no router hops)
- Enables moving Plex to the cluster without network I/O bottleneck
- Main network switch doesn't see storage traffic

## Hardware

- Ryzen mini PC (Talos cluster): Spare 2.5GbE port
- Synology DS218+: Spare 2.5GbE port
- Direct ethernet cable between them

## Setup Steps

### 1. Proxmox Host

Bridge the second 2.5GbE interface on the Proxmox host.

Check available interfaces:
```bash
ip link show
```

Edit `/etc/network/interfaces` on Proxmox host:
```bash
auto vmbr1
iface vmbr1 inet manual
    bridge-ports <second-nic-name>  # e.g., enp2s0
    bridge-stp off
    bridge-fd 0
```

Apply config:
```bash
ifreload -a
```

### 2. Proxmox VM

Add second network interface to Talos VM:
- Hardware → Add → Network Device
- Bridge: `vmbr1`
- Model: VirtIO

Restart the VM.

### 3. Talos Configuration

Update Talos machine config in `talos-cluster.tf` to configure the second interface.

First, check interface name in Talos:
```bash
talosctl -n 192.168.1.57 get links
```

Add to machine config (adjust interface name as needed):
```yaml
machine:
  network:
    interfaces:
      - interface: eth0  # Existing primary interface
        dhcp: true

      - interface: eth1  # Second interface - check actual name
        addresses:
          - 10.0.0.2/24
```

Apply with:
```bash
tofu apply
```

### 4. Synology NAS

Configure the spare 2.5GbE port:
- Control Panel → Network → Network Interface
- Select the spare interface
- IPv4 Configuration: Manual
  - IP Address: `10.0.0.1`
  - Subnet Mask: `255.255.255.0`
  - No gateway needed

### 5. Update NFS Configuration

Update `terraform.tfvars`:
```hcl
nfs = {
  server         = "10.0.0.1"  # Point-to-point IP instead of LAN IP
  tv_path        = "/path/to/tv"
  downloads_path = "/path/to/downloads"
  puid           = 1000
  pgid           = 1000
}
```

Apply:
```bash
tofu apply
```

### 6. Verification

Test NFS connectivity from the cluster:
```bash
kubectl exec -it -n apps deployment/sonarr -- sh
# Inside the pod:
ls -la /tv
```

Should see your media files over the direct link.

## Testing Before Plex Migration

Leave Plex on the Synology initially. Verify the *arr stack works over the direct NFS link. Once stable, tackle Plex migration separately.

## Plex Migration Considerations

When ready to move Plex to the cluster:

1. **Hardware transcoding**: Need to pass `/dev/dri` to Plex container for VAAPI
2. **State migration**: Export Plex database/metadata from Synology, import to cluster
3. **Helm chart**: Use official Plex chart or k8s-at-home chart
4. **Storage**: Media via NFS mount, Plex config on local PVC

The Ryzen 7 5825U will significantly outperform the Celeron J3355 for transcoding.
