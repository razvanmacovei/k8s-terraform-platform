resource "helm_release" "cert_manager" {
  count      = lookup(local.values.cert_manager, "enabled", false) == true ? 1 : 0
  name       = local.values.cert_manager.name
  namespace  = local.values.cert_manager.namespace
  chart      = local.values.cert_manager.chart
  version    = local.values.cert_manager.version
  repository = local.values.cert_manager.repository

  values = [yamlencode(local.values.cert_manager.values)]

  depends_on = [kubernetes_namespace.namespaces]

  wait          = true
  wait_for_jobs = true
}

# Create ClusterIssuer after cert-manager CRDs are installed.
# Uses kubectl apply because kubernetes_manifest validates the GVK at plan time,
# which fails on first apply when cert-manager CRDs don't exist yet.
resource "null_resource" "selfsigned_issuer" {
  count = lookup(local.values.cert_manager, "enabled", false) == true ? 1 : 0

  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOF
      kubectl apply -f - <<YAML
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: selfsigned-issuer
      spec:
        selfSigned: {}
      YAML
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete clusterissuer selfsigned-issuer --ignore-not-found"
  }
}
