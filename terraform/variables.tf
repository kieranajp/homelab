variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "k8s_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = "Seldon"
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
