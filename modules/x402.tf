resource "helm_release" "x402" {
  count     = lookup(local.values, "x402", null) != null ? (lookup(local.values.x402, "enabled", false) == true ? 1 : 0) : 0
  name      = local.values.x402.name
  namespace = local.values.x402.namespace
  chart     = lookup(local.values.x402, "local_chart_path", null) != null ? local.values.x402.local_chart_path : local.values.x402.chart

  repository = lookup(local.values.x402, "local_chart_path", null) != null ? null : local.values.x402.repository
  version    = lookup(local.values.x402, "local_chart_path", null) != null ? null : local.values.x402.version

  values = [yamlencode(local.values.x402.values)]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.ingress_nginx,
  ]

  wait          = true
  wait_for_jobs = true
}
