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
            value = "postgres://postgres:${var.auth_postgres_password}@auth-postgresql:5432/hydra?sslmode=disable"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.auth_postgres]
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
      postgres_password    = var.auth_postgres_password
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
              # Wait for Hydra to be ready using health endpoint
              until wget -q --spider http://hydra-admin:4445/health/ready; do
                echo "Waiting for Hydra..."
                sleep 5
              done

              # Create MCP client for client credentials flow
              hydra create client \
                --endpoint http://hydra-admin:4445 \
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

# Kratos database migration job
resource "kubernetes_job" "kratos_migration" {
  metadata {
    name      = "kratos-migration"
    namespace = "auth"
  }

  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "kratos-migration"
          image = "oryd/kratos:v1.3.0"

          command = ["kratos"]
          args = ["migrate", "sql", "-e", "--yes"]

          env {
            name  = "DSN"
            value = "postgres://postgres:${var.auth_postgres_password}@auth-postgresql:5432/kratos?sslmode=disable"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.auth_postgres]
}

# Ory Kratos identity management
resource "helm_release" "kratos" {
  name       = "kratos"
  repository = "https://k8s.ory.sh/helm/charts"
  chart      = "kratos"
  version    = "0.47.0"
  namespace  = "auth"
  timeout    = 120
  atomic     = true

  values = [
    templatefile("${path.module}/values/kratos.yaml", {
      postgres_password    = var.auth_postgres_password
      kratos_secret        = var.kratos_secret
      google_client_id     = var.google_client_id
      google_client_secret = var.google_client_secret
      identity_schema      = base64encode(file("${path.module}/schemas/kratos-identity.json"))
      oidc_mapper          = base64encode(file("${path.module}/schemas/kratos-oidc-mapper.json"))
    })
  ]

  depends_on = [kubernetes_job.kratos_migration]
}

# Kratos selfservice UI
resource "helm_release" "kratos_selfservice_ui" {
  name       = "kratos-selfservice-ui"
  repository = "https://k8s.ory.sh/helm/charts"
  chart      = "kratos-selfservice-ui-node"
  version    = "0.33.0"
  namespace  = "auth"

  values = [
    yamlencode({
      kratosPublicUrl = "http://kratos-public:4433"
      baseUrl         = "https://kratos.kieranajp.uk/ui"
      deployment = {
        extraVolumes = [{
          name     = "npm-cache"
          emptyDir = {}
        }]
        extraVolumeMounts = [{
          name      = "npm-cache"
          mountPath = "/home/node/.npm"
        }]
      }
    })
  ]

  depends_on = [helm_release.kratos]
}

# Identity import job
resource "kubernetes_job" "kratos_identity_import" {
  count = length(var.kratos_identities) > 0 ? 1 : 0

  metadata {
    name      = "kratos-identity-import-${substr(sha256(jsonencode(var.kratos_identities)), 0, 8)}"
    namespace = "auth"
  }

  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "identity-import"
          image = "oryd/kratos:v1.3.0"

          command = ["/bin/sh"]
          args = [
            "-c",
            <<-EOT
              for identity in /identities/*.json; do
                echo "Importing $identity..."
                kratos import identities "$identity" --endpoint http://kratos-admin:4434 || true
              done
            EOT
          ]

          volume_mount {
            name       = "identities"
            mount_path = "/identities"
          }
        }

        volume {
          name = "identities"
          config_map {
            name = kubernetes_config_map.kratos_identities[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [helm_release.kratos]
}

resource "kubernetes_config_map" "kratos_identities" {
  count = length(var.kratos_identities) > 0 ? 1 : 0

  metadata {
    name      = "kratos-identities"
    namespace = "auth"
  }

  data = {
    for idx, identity in var.kratos_identities :
    "identity-${idx}.json" => jsonencode({
      schema_id = "default"
      traits    = identity
    })
  }
}
