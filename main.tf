terraform {
  required_version = ">= 1.10"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    checkly = {
      source  = "checkly/checkly"
      version = "~> 1.0"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.k8s_context
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.k8s_context
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "checkly" {
  api_key    = var.checkly_api_key
  account_id = var.checkly_account_id
}
