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

variable "cluster_public_ip" {
  description = "Public IP of cluster"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for managing DNS records"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for kieranajp.uk domain"
  type        = string
  sensitive   = true
}

variable "cloudflare_agilewithedele_zone_id" {
  description = "Cloudflare zone ID for agilewithedele.com domain"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
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

variable "auth_postgres_password" {
  description = "PostgreSQL password for auth databases (Hydra and Kratos)"
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

variable "kratos_secret" {
  description = "Kratos secrets key (32+ chars)"
  type        = string
  sensitive   = true
}

variable "kratos_identities" {
  description = "List of Kratos identities to create"
  type = list(object({
    email      = string
    first_name = string
    last_name  = string
  }))
  sensitive = true
  default   = []
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

variable "nfs" {
  description = "NFS configuration for media storage"
  type = object({
    server         = string
    tv_path        = string
    movies_path    = string
    books_path     = string
    downloads_path = string
    docs_path      = string
    puid           = number
    pgid           = number
  })
}

variable "plex_claim_token" {
  description = "Plex claim token from https://plex.tv/claim (4 min validity, first boot only)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "paperless_secret_key" {
  description = "Secret key for Paperless-ngx (32+ chars)"
  type        = string
  sensitive   = true
}

# VPN Configuration (Mullvad)
variable "mullvad" {
  description = "Mullvad VPN configuration for gluetun sidecar"
  type = object({
    wireguard_private_key = string
    wireguard_addresses   = string # e.g., "10.66.212.123/32"
    server_countries      = string # e.g., "Sweden,Switzerland"
  })
  sensitive = true
  default = {
    wireguard_private_key = ""
    wireguard_addresses   = ""
    server_countries      = ""
  }
}

# Checkly Monitoring
variable "checkly_api_key" {
  description = "Checkly API key from https://app.checklyhq.com/settings/account/api-keys"
  type        = string
  sensitive   = true
}

variable "checkly_account_id" {
  description = "Checkly account ID from https://app.checklyhq.com/settings/account/general"
  type        = string
  sensitive   = true
}

# OpenClaw Configuration
variable "anthropic_api_key" {
  description = "Anthropic API key for Claude models"
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token from @BotFather"
  type        = string
  sensitive   = true
}

variable "openclaw_gateway_token" {
  description = "OpenClaw gateway authentication token (generate with: openssl rand -hex 32)"
  type        = string
  sensitive   = true
}

variable "openclaw_model" {
  description = "OpenClaw AI model (e.g., google/gemini-3-flash-preview, anthropic/claude-sonnet-4-5)"
  type        = string
  default     = "google/gemini-3-flash-preview"
}
