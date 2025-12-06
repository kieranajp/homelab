variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "seldon"
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_id" {
  description = "Cloudflare tunnel ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_name" {
  description = "Cloudflare tunnel name"
  type        = string
  default     = "homelab-tunnel"
}

variable "cloudflare_tunnel_secret" {
  description = "Cloudflare tunnel secret"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub token for accessing ghcr.io"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
}

variable "cookie_secret" {
  description = "Secret used for cookie encryption"
  type        = string
  sensitive   = true
}

variable "hydra_postgres_password" {
  description = "PostgreSQL password for Hydra database"
  type        = string
  sensitive   = true
}

variable "hydra_system_secret" {
  description = "Hydra system secret (32+ chars)"
  type        = string
  sensitive   = true
}

variable "hydra_cookie_secret" {
  description = "Hydra cookie secret (32+ chars)"
  type        = string
  sensitive   = true
}

variable "hydra_salt" {
  description = "Hydra pairwise salt (32+ chars)"
  type        = string
  sensitive   = true
}

# Talos Linux Configuration
variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.5"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "seldon"
}

variable "talos_controlplane_ip" {
  description = "IP address of Talos controlplane node"
  type        = string
  default     = "192.168.1.57"
}

variable "talos_hostname" {
  description = "Hostname for Talos node"
  type        = string
  default     = "talos-cp1"
}
