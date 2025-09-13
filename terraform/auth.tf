# PostgreSQL database for Hydra
resource "helm_release" "hydra_postgresql" {
  name       = "hydra-postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.2.5"
  namespace  = "auth"
  timeout    = 60
  atomic     = true

  values = [
    templatefile("${path.module}/values/postgresql.yaml", {
      postgres_password = var.hydra_postgres_password
    })
  ]

  depends_on = [kubernetes_namespace.namespaces]
}

# Hydra database migration job
resource "kubernetes_job" "hydra_migration" {
  metadata {
    name      = "hydra-migration"
    namespace = "auth"
  }

  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "hydra-migration"
          image = "oryd/hydra:v2.3.0"

          command = ["hydra"]
          args = ["migrate", "sql", "-e", "--yes"]

          env {
            name  = "DSN"
            value = "postgres://postgres:${var.hydra_postgres_password}@hydra-postgresql:5432/hydra?sslmode=disable"
          }
        }
      }
    }
  }

  depends_on = [helm_release.hydra_postgresql]
}

# Ory Hydra OAuth2 server
resource "helm_release" "hydra" {
  name       = "hydra"
  repository = "https://k8s.ory.sh/helm/charts"
  chart      = "hydra"
  version    = "0.57.2"
  namespace  = "auth"
  timeout    = 120
  atomic     = true

  values = [
    templatefile("${path.module}/values/hydra.yaml", {
      postgres_password    = var.hydra_postgres_password
      hydra_system_secret  = var.hydra_system_secret
      hydra_cookie_secret  = var.hydra_cookie_secret
      hydra_salt          = var.hydra_salt
    })
  ]

  depends_on = [kubernetes_job.hydra_migration]
}

# Ory Oathkeeper auth proxy
resource "helm_release" "oathkeeper" {
  name       = "oathkeeper"
  repository = "https://k8s.ory.sh/helm/charts"
  chart      = "oathkeeper"
  version    = "0.58.0"
  namespace  = "auth"
  timeout    = 60
  atomic     = false

  values = [
    file("${path.module}/values/oathkeeper.yaml")
  ]

  depends_on = [helm_release.hydra]
}

# OAuth client configuration for MCP
resource "kubernetes_job" "hydra_client_setup" {
  metadata {
    name      = "hydra-client-setup"
    namespace = "auth"
  }

  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "hydra-client-setup"
          image = "oryd/hydra:v2.3.0"

          command = ["/bin/sh"]
          args = [
            "-c",
            <<-EOT
              # Wait for Hydra to be ready
              until hydra --endpoint http://hydra-admin:4445 version; do
                echo "Waiting for Hydra..."
                sleep 5
              done

              # Create MCP client for client credentials flow
              hydra --endpoint http://hydra-admin:4445 create client \
                --id mcp-client \
                --name "MCP HTTP Client" \
                --grant-type client_credentials \
                --scope api:read,api:write \
                --token-endpoint-auth-method client_secret_basic || true

              echo "OAuth clients configured successfully"
            EOT
          ]
        }
      }
    }
  }

  depends_on = [helm_release.hydra]
}
