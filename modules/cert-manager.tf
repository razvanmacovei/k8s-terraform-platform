resource "helm_release" "cert_manager" {
  count      = lookup(local.values.cert_manager, "enabled", false) == true ? 1 : 0
  name       = local.values.cert_manager.name
  namespace  = local.values.cert_manager.namespace
  chart      = local.values.cert_manager.chart
  version    = local.values.cert_manager.version
  repository = local.values.cert_manager.repository
  
  values = [yamlencode(local.values.cert_manager.values)]
}

resource "kubernetes_manifest" "selfsigned_issuer" {
  count = lookup(local.values.cert_manager, "enabled", false) == true ? 1 : 0

  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
}