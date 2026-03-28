locals {
  chart_cache  = "${path.module}/.chart-cache"
  cached_chart = { for c in jsondecode(file("${path.module}/charts.json")) : c.chart => "${local.chart_cache}/${c.chart}-${c.version}.tgz" }
}
