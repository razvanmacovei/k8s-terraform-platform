resource "helm_release" "redis" {
  count      = lookup(local.values, "redis", null) != null ? (lookup(local.values.redis, "enabled", false) == true ? 1 : 0) : 0
  name       = local.values.redis.name
  namespace  = local.values.redis.namespace
  repository = local.values.redis.repository
  chart      = local.values.redis.chart
  version    = local.values.redis.version

  values = [yamlencode(local.values.redis.values)]

  dynamic "set" {
    for_each = var.REDIS_PASSWORD != "" ? [1] : []
    content {
      name  = "auth.password"
      value = var.REDIS_PASSWORD
    }
  }

  depends_on = [kubernetes_namespace.namespaces]

  wait          = true
  wait_for_jobs = true
}
