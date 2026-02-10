# ServiceAccount and RBAC for external agents access to the agents namespace
resource "kubernetes_service_account" "agents_external" {
  metadata {
    name      = "agents-external"
    namespace = "agents"
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_role" "agents_external" {
  metadata {
    name      = "agents-external"
    namespace = "agents"
  }

  rule {
    api_groups = ["", "apps", "networking.k8s.io", "batch"]
    resources  = ["pods", "pods/log", "pods/exec", "deployments", "services", "ingresses", "secrets", "configmaps", "persistentvolumeclaims", "jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_role_binding" "agents_external" {
  metadata {
    name      = "agents-external"
    namespace = "agents"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.agents_external.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.agents_external.metadata[0].name
    namespace = "agents"
  }
}

# Long-lived token for the ServiceAccount
resource "kubernetes_secret" "agents_external_token" {
  metadata {
    name      = "agents-external-token"
    namespace = "agents"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.agents_external.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.agents_external]
}
