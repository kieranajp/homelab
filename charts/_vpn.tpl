{{/*
VPN Sidecar Template - Reusable gluetun container for any chart

Usage in deployment.yaml:
  1. Include this file at the top of your templates directory (copy or symlink)
  2. Add to containers section:
     {{- if .Values.vpn.enabled }}
     {{- include "vpn.container" . | nindent 8 }}
     {{- end }}
  3. Add to volumes section:
     {{- if .Values.vpn.enabled }}
     {{- include "vpn.volumes" . | nindent 8 }}
     {{- end }}
  4. When VPN enabled, ports should be on gluetun container, not main app

Required values.yaml structure:
  vpn:
    enabled: false
    provider: mullvad
    wireguardPrivateKey: ""
    wireguardAddresses: ""
    serverCountries: ""  # Optional: "Sweden,Switzerland"
*/}}

{{- define "vpn.container" -}}
- name: gluetun
  image: qmcgaw/gluetun:latest
  securityContext:
    capabilities:
      add:
        - NET_ADMIN
  env:
    - name: VPN_SERVICE_PROVIDER
      value: {{ .Values.vpn.provider | default "mullvad" }}
    - name: VPN_TYPE
      value: wireguard
    - name: WIREGUARD_PRIVATE_KEY
      value: {{ .Values.vpn.wireguardPrivateKey | quote }}
    - name: WIREGUARD_ADDRESSES
      value: {{ .Values.vpn.wireguardAddresses | quote }}
    {{- if .Values.vpn.serverCountries }}
    - name: SERVER_COUNTRIES
      value: {{ .Values.vpn.serverCountries | quote }}
    {{- end }}
    - name: FIREWALL_VPN_INPUT_PORTS
      value: {{ .Values.vpn.inputPorts | default "" | quote }}
    - name: TZ
      value: {{ .Values.timezone | default "UTC" }}
  {{- if .Values.vpn.ports }}
  ports:
    {{- range .Values.vpn.ports }}
    - name: {{ .name }}
      containerPort: {{ .port }}
      protocol: {{ .protocol | default "TCP" }}
    {{- end }}
  {{- end }}
  volumeMounts:
    - name: vpn-tun
      mountPath: /dev/net/tun
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  livenessProbe:
    exec:
      command:
        - /gluetun-entrypoint
        - healthcheck
    initialDelaySeconds: 30
    periodSeconds: 30
  readinessProbe:
    exec:
      command:
        - /gluetun-entrypoint
        - healthcheck
    initialDelaySeconds: 10
    periodSeconds: 10
{{- end }}

{{- define "vpn.volumes" -}}
- name: vpn-tun
  hostPath:
    path: /dev/net/tun
    type: CharDevice
{{- end }}

{{/*
Use this in the main container when VPN is enabled to remove ports
(gluetun handles all network traffic)
*/}}
{{- define "vpn.mainContainerPorts" -}}
{{- if not .Values.vpn.enabled }}
ports:
  {{- range .Values.ports }}
  - name: {{ .name }}
    containerPort: {{ .port }}
  {{- end }}
{{- end }}
{{- end }}
