# VPN Sidecar Pattern

Route pod traffic through Mullvad VPN using gluetun as a sidecar container.

## Setup

### 1. Get Mullvad WireGuard Config

1. Go to https://mullvad.net/en/account/wireguard-config
2. Generate a new key or use existing
3. Note your **Private Key** and **Address**

### 2. Add to terraform.tfvars

```hcl
mullvad = {
  wireguard_private_key = "YOUR_PRIVATE_KEY"
  wireguard_addresses   = "10.x.x.x/32"
  server_countries      = "Sweden"  # Optional
}
```

## Enabling VPN for a Chart

### Step 1: Copy the helper template

Copy `charts/_vpn.tpl` to your chart's templates directory:

```bash
cp charts/_vpn.tpl charts/sonarr/templates/_vpn.tpl
```

### Step 2: Update deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  template:
    spec:
      containers:
        {{- if .Values.vpn.enabled }}
        {{- include "vpn.container" . | nindent 8 }}
        {{- end }}
        - name: sonarr
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          # When VPN enabled, ports go on gluetun container
          {{- if not .Values.vpn.enabled }}
          ports:
            - name: web
              containerPort: 8989
          {{- end }}
          # ... rest of container spec
      volumes:
        # ... existing volumes
        {{- if .Values.vpn.enabled }}
        {{- include "vpn.volumes" . | nindent 8 }}
        {{- end }}
```

### Step 3: Add VPN values

In `values/sonarr.yaml`:

```yaml
vpn:
  enabled: false
  # These are populated from Terraform
```

### Step 4: Pass credentials from Terraform

In `media.tf`:

```hcl
resource "helm_release" "sonarr" {
  # ...
  values = [
    file("${path.module}/values/sonarr.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      vpn = {
        enabled              = true  # Enable VPN
        provider             = "mullvad"
        wireguardPrivateKey  = var.mullvad.wireguard_private_key
        wireguardAddresses   = var.mullvad.wireguard_addresses
        serverCountries      = var.mullvad.server_countries
        ports = [
          { name = "web", port = 8989 }
        ]
      }
      nfs = { ... }
    })
  ]
}
```

## How It Works

1. **Gluetun sidecar** runs alongside your main container
2. **Shared network namespace** - all containers in the pod share networking
3. **All traffic routes through VPN** - gluetun creates a tunnel, all egress goes through it
4. **Ports exposed on gluetun** - ingress traffic comes through gluetun's ports

## Verification

Check VPN is working:

```bash
# Get pod name
kubectl get pods -n homelab -l app=sonarr

# Check gluetun logs
kubectl logs -n homelab sonarr-xxx -c gluetun

# Verify IP (should show Mullvad exit IP)
kubectl exec -n homelab sonarr-xxx -c sonarr -- curl -s https://am.i.mullvad.net/ip
```

## Notes

- **NET_ADMIN capability** required - gluetun needs to create tun device
- **hostPath for /dev/net/tun** - pod security may need adjustment
- **Firewall ports** - use `vpn.inputPorts` for services that need inbound connections (e.g., torrent clients)
