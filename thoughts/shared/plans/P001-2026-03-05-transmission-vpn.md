# PLAN 1: Transmission with Mullvad VPN Sidecar

## Overview

Deploy Transmission torrent client on Seldon, replacing the broken Synology Docker setup. All torrent traffic routes through Mullvad VPN via a gluetun sidecar container. Downloads land on the Synology NFS share so Sonarr/etc. can pick them up.

## Current State Analysis

- No transmission chart or config exists yet
- `charts/_vpn.tpl` is a ready-made gluetun sidecar template
- `variables.tf` already has the `mullvad` variable (WireGuard key, address, server countries)
- `media.tf` has helm releases for prowlarr, sonarr, lazylibrarian, calibre-web-automated
- `var.nfs.downloads_path` is the shared downloads NFS path (same folder transmission should use)
- Homepage already has a Transmission entry pointing at `schwengel.local:9091`
- Auth pattern: all media apps use `ory-auth` middleware in namespace `auth` for Google login

### Key Discoveries:
- Sonarr deployment pattern at `charts/sonarr/templates/deployment.yaml` is the closest model
- NFS volumes are mounted directly (no PV/PVC for NFS, just inline `nfs:` in the volume spec)
- Config persistence uses local-path PVCs
- IngressRoutes use Traefik with `websecure` entrypoint, `letsencrypt` cert resolver, `ory-auth` middleware
- The VPN template expects ports to be defined on the gluetun container (not the app container) when VPN is enabled
- `_vpn.tpl` needs to be copied into each chart's templates directory (not shared)

## Desired End State

- Transmission web UI accessible at `https://transmission.kieranajp.uk` behind Google auth
- RPC endpoint accessible from LAN (192.168.0.0/16) without Google auth, using Transmission's built-in username/password auth instead
- All torrent traffic routed through Mullvad VPN via gluetun sidecar
- Downloads written to the NFS downloads share
- Config persisted in a local-path PVC
- Peer port 51413 open through the VPN firewall for inbound connections

### Verification:
1. `kubectl get pods -n homelab -l app=transmission` shows Running with 2/2 containers
2. `kubectl exec -n homelab <pod> -c gluetun -- /gluetun-entrypoint healthcheck` succeeds
3. `kubectl exec -n homelab <pod> -c transmission -- curl -s https://am.i.mullvad.net/ip` returns a Mullvad IP
4. Web UI loads at `https://transmission.kieranajp.uk` (requires Google auth)
5. RPC works from LAN client with Transmission username/password auth
6. RPC is rejected from non-LAN IPs without Google auth

## What We're NOT Doing

- No Mullvad port forwarding setup (Mullvad doesn't support it any more anyway)
- No custom transmission settings.json beyond the env vars for built-in auth — use the web UI for further config after first boot
- No VPN kill switch beyond what gluetun already provides (it handles this natively)
- Not adding a `transmission_path` NFS variable — using the existing `downloads_path`

## Phase 1: Transmission Helm Chart

### Overview
Create the chart following the sonarr pattern, with the gluetun VPN sidecar wired in.

### Changes Required:

#### 1. Chart.yaml
**File**: `charts/transmission/Chart.yaml`

```yaml
apiVersion: v2
name: transmission
version: 0.1.0
description: Transmission torrent client with VPN sidecar
```

#### 2. VPN helper template
**File**: `charts/transmission/templates/_vpn.tpl`

Copy of `charts/_vpn.tpl` (per the established pattern documented in `docs/VPN_SIDECAR.md`).

#### 3. Deployment
**File**: `charts/transmission/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        {{- if .Values.vpn.enabled }}
        {{- include "vpn.container" . | nindent 8 }}
        {{- end }}
        - name: transmission
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          {{- if not .Values.vpn.enabled }}
          ports:
            - name: web
              containerPort: 9091
            - name: peer-tcp
              containerPort: 51413
              protocol: TCP
            - name: peer-udp
              containerPort: 51413
              protocol: UDP
          {{- end }}
          env:
            - name: PUID
              value: "{{ .Values.puid }}"
            - name: PGID
              value: "{{ .Values.pgid }}"
            - name: TZ
              value: "{{ .Values.timezone }}"
            - name: USER
              value: "{{ .Values.auth.username }}"
            - name: PASS
              value: "{{ .Values.auth.password }}"
          volumeMounts:
            - name: config
              mountPath: /config
            - name: downloads
              mountPath: /downloads
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      volumes:
        - name: config
          persistentVolumeClaim:
            claimName: {{ .Release.Name }}-config
        - name: downloads
          nfs:
            server: {{ .Values.nfs.server }}
            path: {{ .Values.nfs.downloadsPath | quote }}
        {{- if .Values.vpn.enabled }}
        {{- include "vpn.volumes" . | nindent 8 }}
        {{- end }}
```

Note: No liveness/readiness probe on the transmission container. Transmission doesn't have a `/ping` endpoint. The gluetun container has its own health probes which cover network connectivity.

#### 4. Service
**File**: `charts/transmission/templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
spec:
  type: ClusterIP
  selector:
    app: {{ .Release.Name }}
  ports:
    - name: web
      port: 9091
      targetPort: 9091
```

#### 5. PVC
**File**: `charts/transmission/templates/pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-config
  namespace: {{ .Release.Namespace }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
```

#### 6. IPAllowList Middleware
**File**: `charts/transmission/templates/middleware.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: lan-only
  namespace: {{ .Release.Namespace }}
spec:
  ipAllowList:
    sourceRange:
      - 192.168.0.0/16
```

#### 7. IngressRoute
**File**: `charts/transmission/templates/ingressroute.yaml`

Two routes on the same IngressRoute:
- RPC path from LAN IPs: no Google auth (Transmission's built-in auth handles it)
- Everything else: Google auth via ory-auth

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: {{ .Values.ingress.match | quote }} && PathPrefix(`/transmission/rpc`)
      middlewares:
        - name: lan-only
      services:
        - name: {{ .Release.Name }}
          port: 9091
    - kind: Rule
      match: {{ .Values.ingress.match | quote }}
      middlewares:
        - name: ory-auth
          namespace: auth
      services:
        - name: {{ .Release.Name }}
          port: 9091
  tls:
    certResolver: letsencrypt
{{- end }}
```

Traefik evaluates routes in order and uses the most specific match. The RPC path rule is more specific (has `PathPrefix`), so LAN clients hitting `/transmission/rpc` get through without Google auth. Everything else (including the web UI and RPC from non-LAN IPs) goes through ory-auth.

### Success Criteria:

#### Automated Verification:
- [x] `helm template ./charts/transmission -f values/transmission.yaml` renders valid YAML
- [x] Chart contains all 7 files: Chart.yaml, _vpn.tpl, deployment.yaml, service.yaml, pvc.yaml, middleware.yaml, ingressroute.yaml

#### Manual Verification:
- [x] Templates look correct on visual inspection

---

## Phase 2: Values File and Terraform Wiring

### Overview
Create the values file and add the helm_release to media.tf with VPN credentials and NFS mounts.

### Changes Required:

#### 1. Values file
**File**: `values/transmission.yaml`

```yaml
image:
  repository: linuxserver/transmission
  tag: latest

timezone: Europe/Berlin

persistence:
  size: 1Gi

ingress:
  enabled: true
  match: Host(`transmission.kieranajp.uk`)

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 256Mi
```

#### 2. Terraform variable
**File**: `variables.tf` (append)

```hcl
variable "transmission" {
  description = "Transmission built-in auth credentials (for RPC access from LAN)"
  type = object({
    username = string
    password = string
  })
  sensitive = true
}
```

**File**: `terraform.tfvars.example` (append)

```hcl
# Transmission
transmission = {
  username = "admin"
  password = ""
}
```

And add the actual values to `terraform.tfvars`.

#### 3. Terraform helm release
**File**: `media.tf` (append)

```hcl
resource "helm_release" "transmission" {
  name      = "transmission"
  chart     = "./charts/transmission"
  namespace = "homelab"
  timeout   = 120
  atomic    = true

  values = [
    file("${path.module}/values/transmission.yaml"),
    yamlencode({
      puid = var.nfs.puid
      pgid = var.nfs.pgid
      vpn = {
        enabled             = true
        provider            = "mullvad"
        wireguardPrivateKey = var.mullvad.wireguard_private_key
        wireguardAddresses  = var.mullvad.wireguard_addresses
        serverCountries     = var.mullvad.server_countries
        inputPorts          = "51413"
        ports = [
          { name = "web", port = 9091 },
          { name = "peer-tcp", port = 51413, protocol = "TCP" },
          { name = "peer-udp", port = 51413, protocol = "UDP" }
        ]
      }
      auth = {
        username = var.transmission.username
        password = var.transmission.password
      }
      nfs = {
        server        = var.nfs.server
        downloadsPath = var.nfs.downloads_path
      }
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}
```

### Success Criteria:

#### Automated Verification:
- [x] `tofu validate` passes
- [x] `tofu plan` shows the new helm_release resource to be created

#### Manual Verification:
- [x] `tofu apply` deploys successfully
- [x] Pod starts with 2/2 containers ready
- [x] Gluetun healthcheck passes
- [x] IP check shows Mullvad exit IP (not home IP)
- [x] Web UI accessible at `https://transmission.kieranajp.uk` (requires Google auth)
- [x] RPC accessible from LAN with Transmission username/password (no Google auth)
- [ ] RPC rejected from non-LAN IPs without Google auth

---

## Phase 3: Homepage Update

### Overview
Update the homepage entry to point at the new cluster-hosted URL instead of the Synology.

### Changes Required:

#### 1. Homepage config
**File**: `values/homepage.yaml`

Change the Transmission entry from:
```yaml
- Transmission:
    href: http://schwengel.local:9091/transmission/web/
    description: Torrents
    icon: transmission.png
```

To:
```yaml
- Transmission:
    href: https://transmission.kieranajp.uk
    description: Torrents
    icon: transmission.png
```

### Success Criteria:

#### Manual Verification:
- [x] Homepage shows updated Transmission link
- [x] Link works and reaches the web UI

---

## References

- VPN sidecar docs: `docs/VPN_SIDECAR.md`
- VPN template: `charts/_vpn.tpl`
- Sonarr chart (model): `charts/sonarr/`
- Mullvad variable: `variables.tf:159`
- Media helm releases: `media.tf`
