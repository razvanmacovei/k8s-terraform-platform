resource "helm_release" "argocd" {
  count      = lookup(local.values, "argocd", null) != null ? (lookup(local.values.argocd, "enabled", false) == true ? 1 : 0) : 0
  name       = local.values.argocd.name
  namespace  = local.values.argocd.namespace
  repository = local.values.argocd.repository
  chart      = local.values.argocd.chart
  version    = local.values.argocd.version

  values = [yamlencode(local.values.argocd.values)]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.ingress_nginx,
    null_resource.selfsigned_issuer,
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}
