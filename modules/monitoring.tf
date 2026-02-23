resource "helm_release" "monitoring" {
  count      = lookup(local.values, "monitoring", null) != null ? (lookup(local.values.monitoring, "enabled", false) == true ? 1 : 0) : 0
  name       = local.values.monitoring.name
  namespace  = local.values.monitoring.namespace
  repository = local.values.monitoring.repository
  chart      = local.values.monitoring.chart
  version    = local.values.monitoring.version

  values = [yamlencode(local.values.monitoring.values)]

  depends_on = [helm_release.ingress_nginx]

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}
