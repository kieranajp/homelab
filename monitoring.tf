resource "helm_release" "victoria-metrics" {
  name      = "victoria-metrics"
  chart     = local.cached_chart["victoria-metrics-single"]
  namespace = "monitoring"

  values = [file("${path.module}/values/victoria-metrics.yaml")]
}

resource "helm_release" "node_exporter" {
  name      = "node-exporter"
  chart     = local.cached_chart["prometheus-node-exporter"]
  namespace = "monitoring"
}

resource "helm_release" "grafana" {
  name      = "grafana"
  chart     = local.cached_chart["grafana"]
  namespace = "monitoring"

  values = [file("${path.module}/values/grafana.yaml")]
}

resource "helm_release" "blackbox_exporter" {
  name      = "blackbox-exporter"
  chart     = local.cached_chart["prometheus-blackbox-exporter"]
  namespace = "monitoring"

  values = [file("${path.module}/values/blackbox-exporter.yaml")]
}
