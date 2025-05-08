resource "helm_release" "n8n" {
  count      = lookup(local.values.n8n, "enabled", false) == true ? 1 : 0
  name       = local.values.n8n.name
  namespace  = local.values.n8n.namespace
  repository = local.values.n8n.repository
  chart      = local.values.n8n.chart
  version    = local.values.n8n.version

  values = [yamlencode(local.values.n8n.values)]

  set {
    name  = "externalPostgresql.username"
    value = var.POSTGRESQL_USERNAME
  }

  set {
    name  = "externalPostgresql.password"
    value = var.POSTGRESQL_PASSWORD
  }

  set {
    name  = "externalPostgresql.database"
    value = var.POSTGRESQL_DATABASE
  }
  
  depends_on = [
    helm_release.postgresql
  ]

  wait          = true
  wait_for_jobs = true
}