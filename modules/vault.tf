resource "helm_release" "vault" {
  count      = lookup(local.values.vault, "enabled", false) == true ? 1 : 0
  name       = local.values.vault.name
  namespace  = local.values.vault.namespace
  repository = local.values.vault.repository
  chart      = local.values.vault.chart
  version    = local.values.vault.version

  values = [yamlencode(local.values.vault.values)]
  
  wait = true
  wait_for_jobs = true
}