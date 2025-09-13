# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dual-layer infrastructure repository for managing a Kubernetes homelab called "seldon". It combines Ansible automation for initial system setup with OpenTofu/Terraform for Kubernetes application deployment. The infrastructure deploys authentication, monitoring, home automation, and custom applications using a combination of Ansible roles and Helm charts.

## Architecture

The infrastructure is organized in two main layers:

### Ansible Layer (System Setup)
- **Base System**: Fundamental system configuration and packages
- **BTRFS Snapshots**: Filesystem snapshot management for system recovery  
- **Networking**: Network configuration and firewall setup
- **K3s**: Lightweight Kubernetes cluster installation and configuration

### Terraform/OpenTofu Layer (Application Deployment)
- **OpenTofu**: Infrastructure as code using Helm and Kubernetes providers
- **Helm Charts**: Custom charts in `terraform/charts/` directory for application deployments
- **Values**: Configuration files in `terraform/values/` directory for each service
- **OAuth/Auth**: Ory Hydra-based OAuth 2.0 authentication with Google OAuth upstream
- **Ingress**: Traefik-based routing with authentication middleware
- **Monitoring**: Victoria Metrics and Grafana stack

## Common Commands

### Ansible Operations (Initial Setup)
```bash
# Run full system setup
ansible-playbook -i inventory.ini playbook.yml

# Run specific role tags
ansible-playbook -i inventory.ini playbook.yml --tags setup
ansible-playbook -i inventory.ini playbook.yml --tags k3s
ansible-playbook -i inventory.ini playbook.yml --tags networking
```

### OpenTofu Operations (Application Management)
```bash
# Change to terraform directory
cd terraform

# Initialize and plan
tofu init
tofu plan

# Apply changes
tofu apply

# Validate configuration
tofu validate
tofu fmt -check

# Show current state
tofu show
tofu state list
```

### Generate Required Secrets
```bash
# Hydra OAuth secrets (add to terraform/terraform.tfvars)
openssl rand -hex 32  # hydra_system_secret
openssl rand -hex 32  # hydra_cookie_secret  
openssl rand -hex 32  # hydra_oidc_salt

# Cookie secret for oauth2-proxy
openssl rand -base64 32  # cookie_secret
```

### Kubernetes Debugging
```bash
# Check application status
kubectl -n apps get pods
kubectl -n monitoring get pods
kubectl -n auth get pods

# View logs
kubectl -n auth logs -l app=hydra
kubectl -n apps logs -l app=mcp-server
```

## Key Configuration

### Ansible Configuration
- **Inventory**: `inventory.ini` defines target host "seldon.local"
- **Config**: `ansible.cfg` sets role paths to `./roles/external:./roles/internal`
- **SSH**: Uses user "kieran" with key-based authentication

### OpenTofu Variables
All sensitive configuration is managed through `terraform/terraform.tfvars` (use `terraform/terraform.tfvars.example` as template):
- Kubernetes context: defaults to "seldon"
- OAuth credentials for Google authentication
- Cloudflare tunnel configuration
- GitHub container registry access
- Hydra OAuth secrets (generate with `openssl rand -hex 32`)

### Kubernetes Context
The default Kubernetes context is "seldon". Configuration assumes kubeconfig at `~/.kube/config`.

## Directory Structure

### Root Level
- `playbook.yml` - Main Ansible playbook defining role execution order
- `ansible.cfg` - Ansible configuration with role paths and settings
- `inventory.ini` - Target host definition
- `roles/internal/` - Custom Ansible roles for system setup
- `terraform/` - OpenTofu/Terraform infrastructure code

### Terraform Directory
- `*.tf` - Main OpenTofu configuration files, organized by service
- `charts/` - Custom Helm charts for applications
  - `traefik-resources/` - Traefik middlewares, ingress routes, and auth components
  - `hydra/` - Ory Hydra OAuth server
  - `oauth2-proxy/` - OAuth2 proxy for authentication
- `values/` - Helm values files corresponding to each service
- `variables.tf` - All OpenTofu variable definitions with sensitive marking

## Ansible Roles Structure

### Internal Roles (roles/internal/)
- `base_system/` - System packages, users, and basic configuration
- `btrfs_snapshots/` - BTRFS snapshot management and scheduling
- `k3s/` - K3s Kubernetes cluster installation and configuration
- `networking/` - Network setup, firewall rules, and connectivity

## Authentication Architecture

The system uses a two-tier authentication approach:

1. **Ory Hydra OAuth 2.0 Server** (`auth` namespace)
   - RFC 8414 compliant authorization server
   - Google OAuth as upstream identity provider
   - Auto-approval for specific email domains
   - MCP-compatible token exchange

2. **Traefik Middleware** 
   - `hydra-oauth` middleware for web applications
   - `api-oauth` middleware for API authentication
   - JWT token validation and forwarding

### OAuth Endpoints
- Authorization: `https://auth.kieranajp.uk/oauth2/auth`
- Token: `https://auth.kieranajp.uk/oauth2/token` 
- Discovery: `https://auth.kieranajp.uk/.well-known/oauth-authorization-server`

## Service Namespaces

- `apps` - Application deployments (mcp-server, etc.)
- `auth` - Authentication services (Hydra)
- `monitoring` - Metrics and observability (Victoria Metrics, Grafana)
- `networking` - Network-related services
- `home-automation` - Home Assistant and related services

## Important Files

- `terraform/HYDRA_SETUP.md` - Detailed OAuth 2.0 setup instructions and architecture
- `terraform/OAUTH2_API_AUTH.md` - API authentication configuration guide
- `terraform/terraform.tfvars.example` - Template for sensitive configuration
- `terraform/traefik-resources.tf` - Main ingress and auth configuration
- `terraform/variables.tf` - Complete variable definitions with security annotations

## Development Workflow

1. **Initial Setup**: Run Ansible playbook to configure system and install K3s
2. **Application Deployment**: Use OpenTofu in terraform/ directory to deploy applications
3. **Configuration Changes**: Modify values files and apply with `tofu apply`
4. **Debugging**: Use kubectl commands to inspect pod status and logs

## YAML File Preferences

- Prefer separate YAML files over multi-document files with `---` separators
- Instead of combining deployment and service in one file, create separate `deployment.yaml` and `service.yaml` files
- This applies to all Kubernetes manifests and Helm chart templates