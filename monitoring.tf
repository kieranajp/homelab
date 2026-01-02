resource "helm_release" "victoria-metrics" {
  name       = "victoria-metrics"
  repository = "https://victoriametrics.github.io/helm-charts/"
  chart      = "victoria-metrics-single"
  version    = "0.23.0"
  namespace  = "monitoring"

  values = [file("${path.module}/values/victoria-metrics.yaml")]
}

resource "helm_release" "node_exporter" {
  name       = "node-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-node-exporter"
  version    = "4.47.1"
  namespace  = "monitoring"
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "9.2.10"
  namespace  = "monitoring"

  values = [file("${path.module}/values/grafana.yaml")]
}

resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = "11.6.1"
  namespace  = "monitoring"

  values = [file("${path.module}/values/blackbox-exporter.yaml")]
}
