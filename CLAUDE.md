# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

IMPORTANT: always make sure you're on the `seldon` context in kube - I really don't want to run commands against my work cluster! A quick `ktx seldon` is enough.

## Repository Overview

This is a fully declarative Infrastructure as Code repository for managing a Kubernetes homelab called "seldon". The entire infrastructure - from OS to applications - is managed via OpenTofu/Terraform. The cluster runs on Talos Linux (immutable Kubernetes OS) in a Proxmox VM, deploying monitoring, home automation, and custom applications using Helm charts.

## Architecture

The infrastructure is single-layer, fully declarative:

### Talos Linux (Immutable OS)
- **OS Management**: Talos Linux v1.11.5, API-driven, no SSH
- **Provisioning**: VM on Proxmox (reed.local)
- **Configuration**: Declarative YAML via Terraform Talos provider
- **Updates**: Atomic OS upgrades via `talosctl`

### Terraform/OpenTofu Layer (Everything)
- **Cluster Bootstrap**: Talos machine configuration, secrets, and Kubernetes bootstrap
- **CNI**: Cilium with kube-proxy replacement and Hubble observability
- **Storage**: local-path-provisioner for dynamic volume provisioning
- **Ingress**: Traefik with hostPort :80/:443 (no LoadBalancer needed)
- **Helm Charts**: Custom charts in `terraform/charts/` and upstream charts
- **Values**: Configuration files in `terraform/values/` for each service
- **Monitoring**: Victoria Metrics, Grafana, and node-exporter
- **Authentication**: Ory Hydra OAuth 2.0 server with Oathkeeper auth proxy

## Key Non-Obvious Details

### Infrastructure Gotchas
- **Single-node cluster**: Control plane taints removed via `allowSchedulingOnControlPlanes = true`
- **No LoadBalancer**: Traefik uses `hostPort` for direct :80/:443 access
- **Monitoring namespace**: Pod security set to `privileged` (node-exporter needs host access)
- **Storage**: `WaitForFirstConsumer` binding - PVCs only bind when pods start
- **Cilium bootstrap**: Uses `k8sServiceHost` to connect directly to node IP, not service IP
- **Cloudflare grey cloud**: DNS records are not proxied (grey cloud, not orange). This is because Spanish ISPs (particularly Telefónica/Movistar) block Cloudflare's proxy IP ranges due to La Liga court orders targeting piracy. Direct routing via port forwarding (80/443) bypasses this. The `favonia/cloudflare-ddns` deployment keeps DNS records updated with the dynamic public IP.

### Talos Specifics
- **Node IP**: 192.168.1.57
- **Kubeconfig**: Generated at `terraform/talos-kubeconfig`, context `admin@seldon`
- **Talosconfig**: Generated at `terraform/talosconfig`
- **No kube-proxy**: Disabled in Talos config, Cilium handles it

### Critical Files to Backup
- `terraform/terraform.tfvars` - All secrets and configuration
- `terraform/terraform.tfstate` - Infrastructure state

## YAML File Preferences

- Prefer separate YAML files over multi-document files with `---` separators
- Instead of combining deployment and service in one file, create separate `deployment.yaml` and `service.yaml` files
- This applies to all Kubernetes manifests and Helm chart templates

## Documentation

- `docs/PROXMOX_TALOS_VM.md` - Complete VM setup guide with optimal settings
- `docs/TALOS_TERRAFORM_SETUP.md` - Terraform bootstrap workflow and operations guide
