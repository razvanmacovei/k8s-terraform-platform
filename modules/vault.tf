resource "helm_release" "vault" {
  count      = lookup(local.values.vault, "enabled", false) == true ? 1 : 0
  name       = local.values.vault.name
  namespace  = local.values.vault.namespace
  repository = local.values.vault.repository
  chart      = local.values.vault.chart
  version    = local.values.vault.version

  values = [yamlencode(local.values.vault.values)]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.ingress_nginx,
    null_resource.selfsigned_issuer,
  ]

  wait          = true
  wait_for_jobs = true
}
