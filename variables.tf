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
    books_path     = string
    downloads_path = string
    docs_path      = string
    puid           = number
    pgid           = number
  })
}

variable "paperless_secret_key" {
  description = "Secret key for Paperless-ngx (32+ chars)"
  type        = string
  sensitive   = true
}
