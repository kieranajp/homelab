resource "kubernetes_service_account" "pod_sweeper" {
  metadata {
    name      = "pod-sweeper"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "pod_sweeper" {
  metadata {
    name = "pod-sweeper"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "delete"]
  }
}

resource "kubernetes_cluster_role_binding" "pod_sweeper" {
  metadata {
    name = "pod-sweeper"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.pod_sweeper.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.pod_sweeper.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_cron_job_v1" "pod_sweeper" {
  metadata {
    name      = "pod-sweeper"
    namespace = "kube-system"
  }

  spec {
    schedule = "0 */6 * * *"

    job_template {
      metadata {}
      spec {
        ttl_seconds_after_finished = 300
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account.pod_sweeper.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = "sweeper"
              image = "bitnami/kubectl:latest"

              command = ["/bin/sh"]
              args = [
                "-c",
                "kubectl get pods -A --field-selector=status.phase==Succeeded -o json | kubectl delete -f - || true"
              ]
            }
          }
        }
      }
    }
  }
}
