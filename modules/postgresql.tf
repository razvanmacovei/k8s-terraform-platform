resource "helm_release" "postgresql" {
  count      = lookup(local.values.postgresql, "enabled", false) == true ? 1 : 0
  name       = local.values.postgresql.name
  namespace  = local.values.postgresql.namespace
  repository = local.values.postgresql.repository
  chart      = local.values.postgresql.chart
  version    = local.values.postgresql.version

  values = [yamlencode(local.values.postgresql.values)]

  set {
    name  = "auth.username"
    value = var.POSTGRESQL_USERNAME
  }

  set {
    name  = "auth.password"
    value = var.POSTGRESQL_PASSWORD
  }

  set {
    name  = "auth.database"
    value = var.POSTGRESQL_DATABASE
  }

  set {
    name  = "auth.postgresPassword"
    value = var.POSTGRESQL_PASSWORD
  }

  set {
    name  = "auth.replicationPassword"
    value = var.POSTGRESQL_REPLICATION_PASSWORD
  }

  depends_on = [kubernetes_namespace.namespaces]

  wait          = true
  wait_for_jobs = true
}
