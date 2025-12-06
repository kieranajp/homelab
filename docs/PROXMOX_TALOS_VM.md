# Talos VM Setup on Proxmox

This guide covers creating a Talos Linux VM on Proxmox, optimized for the homelab Kubernetes cluster.

## Prerequisites

- Proxmox VE installed and accessible
- Talos Linux ISO downloaded and uploaded to Proxmox storage (`/var/lib/vz/template/iso/`)
- Download from: https://github.com/siderolabs/talos/releases

## Hardware Reference

Current homelab specs (reed.local):
- **CPU:** AMD Ryzen 7 5825U (8 cores / 16 threads)
- **RAM:** 32GB DDR4
- **Storage:** 1TB NVMe

## VM Creation Steps

### 1. Create VM

**Proxmox Web UI** → Top right **"Create VM"**

### 2. General Tab
- **Node:** reed (or your Proxmox node name)
- **VM ID:** `100` (or your preference)
- **Name:** `talos-cp1` (controlplane-1)
- ✅ **Start at boot:** Enabled
- **Start/Shutdown order:** `order=1,up=30,down=60`
  - `up=30`: Wait 30s after Proxmox boots before starting VM
  - `down=60`: Allow 60s for graceful Kubernetes shutdown

### 3. OS Tab
- **Use CD/DVD disc image file (iso):** Selected
- **Storage:** local
- **ISO image:** Select Talos ISO (e.g., `metal-amd64.iso`)
- **Guest OS Type:** Linux
- **Version:** 6.x - 2.6 Kernel

### 4. System Tab ⚠️ Critical Settings

- **Graphic card:** Default
- **Machine:** q35
- **BIOS:** OVMF (UEFI)
- **Add EFI Disk:** ✅ Enabled
  - **EFI Storage:** local-lvm
  - ⚠️ **Pre-Enroll keys:** ❌ **DISABLED** (critical - Talos ISOs aren't signed)
- **SCSI Controller:** VirtIO SCSI single
- **Qemu Agent:** ✅ Enabled (Talos includes qemu-guest-agent)
- **Add TPM:** ❌ Disabled

**Common Issue:** If you get "Access Denied" when booting, Secure Boot is enabled. Make sure "Pre-Enroll keys" is disabled.

### 5. Disks Tab (NVMe Optimized)

- **Bus/Device:** SCSI / 0
- **Storage:** local-lvm
- **Disk size (GiB):** `512` (adjust based on available storage)
  - Minimum: 32GB
  - Recommended: 100GB+
  - Generous: 512GB (leaves room for persistent volumes, container images)
- **Cache:** Default (No cache)
- ✅ **Discard:** Enabled (TRIM support for NVMe)
- ✅ **SSD emulation:** Enabled (for NVMe/SSD storage)
- ✅ **IO thread:** Enabled (better I/O performance)

### 6. CPU Tab (Performance Optimized)

- **Sockets:** 1
- **Cores:** `7` (leave 1 core for Proxmox host)
  - Single VM: Use most cores (7-8 of 8)
  - Multiple VMs: Divide appropriately
- ⚠️ **Type:** **host** (critical for performance!)
  - Enables CPU passthrough
  - Near-native performance
  - Do NOT use "kvm64" or other emulated types

### 7. Memory Tab

- **Memory (MiB):** `28672` (28GB)
  - Leaves ~4GB for Proxmox host
  - Minimum: 8192 (8GB)
  - Recommended: 16384+ (16GB+)
- **Ballooning Device:** ✅ Enabled (allows dynamic memory allocation)

### 8. Network Tab

- **Bridge:** vmbr0 (default Proxmox bridge)
- **VLAN Tag:** (leave blank unless using VLANs)
- **Model:** VirtIO (paravirtualized)
  - Near-native network performance
  - Talos includes virtio network drivers
- **MAC address:** Auto-generated
- **Firewall:** ❌ Disabled (Talos has built-in firewall)

### 9. Confirm

- Review all settings
- ✅ **Start after created:** Enabled
- **Finish**

## Post-Creation

### First Boot

1. VM will boot from ISO
2. Talos will start in maintenance mode
3. Console will show IP address assigned via DHCP
4. Note this IP for Terraform configuration

### Optional: Remove CD-ROM After Install

Once Talos is installed to disk (after first config apply):

1. **Hardware** tab
2. Select **CD/DVD Drive (ide2)**
3. **Remove**

Talos is now installed to the VM disk and doesn't need the ISO.

## Troubleshooting

### Boot Error: "Access Denied" on ISO

**Cause:** UEFI Secure Boot is rejecting unsigned Talos ISO

**Fix:**
1. Stop VM
2. Hardware → Remove EFI Disk
3. Add → EFI Disk
4. Ensure **"Pre-Enroll keys"** is DISABLED
5. Start VM

### VM Won't Auto-Start After Reboot

**Check:**
```bash
# On Proxmox host
qm config 100 | grep -E "onboot|startup"
```

**Should show:**
```
onboot: 1
startup: order=1,up=30,down=60
```

**Fix:**
```bash
qm set 100 --onboot 1 --startup order=1,up=30,down=60
```

### No Network / No IP Address

**Check bridge configuration:**
```bash
# On Proxmox host
ip link show vmbr0
```

**Verify VM network:**
- Hardware → Network Device → Should be VirtIO on vmbr0
- Make sure DHCP server is running on your network

## Summary: Optimal Configuration

For a **single Talos VM on dedicated homelab server** (Ryzen 7 5825U, 32GB RAM, 1TB NVMe):

```yaml
VM ID: 100
Name: talos-cp1
BIOS: UEFI (OVMF) - Secure Boot DISABLED
CPU: 7 cores, type=host
Memory: 28GB (28672 MiB)
Disk: 512GB NVMe (VirtIO SCSI, discard, SSD emulation, IO thread)
Network: VirtIO on vmbr0
Qemu Agent: Enabled
Auto-start: Yes (order=1, up=30, down=60)
```

## Next Steps

After VM is created and booted:

1. Note the IP address from Talos console
2. Configure Talos via Terraform (see `terraform/talos.tf`)
3. Bootstrap Kubernetes cluster
4. Deploy applications

See main [README.md](../README.md) for Terraform and application deployment instructions.
