resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init"
    namespace = "auth"
  }

  data = {
    "init.sql" = <<-EOT
      SELECT 'CREATE DATABASE hydra' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'hydra')\gexec
      SELECT 'CREATE DATABASE kratos' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'kratos')\gexec
    EOT
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_stateful_set" "auth_postgres" {
  metadata {
    name      = "auth-postgres"
    namespace = "auth"
    labels = {
      app = "auth-postgres"
    }
  }

  spec {
    service_name = "auth-postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "auth-postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "auth-postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:18-alpine"

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = var.auth_postgres_password
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env {
            name  = "POSTGRES_INITDB_ARGS"
            value = "-c max_connections=100"
          }

          port {
            container_port = 5432
            name          = "postgres"
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "init-script"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        volume {
          name = "init-script"
          config_map {
            name = kubernetes_config_map.postgres_init.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "postgres-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "local-path"

        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_service" "auth_postgres" {
  metadata {
    name      = "auth-postgresql"
    namespace = "auth"
  }

  spec {
    selector = {
      app = "auth-postgres"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    cluster_ip = "None"
  }

  depends_on = [kubernetes_namespace.namespaces]
}
