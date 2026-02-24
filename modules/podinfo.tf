resource "helm_release" "podinfo" {
  count      = lookup(local.values, "podinfo", null) != null ? (lookup(local.values.podinfo, "enabled", false) == true ? 1 : 0) : 0
  name       = local.values.podinfo.name
  namespace  = local.values.podinfo.namespace
  repository = local.values.podinfo.repository
  chart      = local.values.podinfo.chart
  version    = local.values.podinfo.version

  values = [yamlencode(local.values.podinfo.values)]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.ingress_nginx,
    null_resource.selfsigned_issuer,
  ]

  wait          = true
  wait_for_jobs = true
}
