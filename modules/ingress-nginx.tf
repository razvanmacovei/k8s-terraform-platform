resource "helm_release" "ingress_nginx" {
  count      = lookup(local.values.ingress_nginx, "enabled", false) == true ? 1 : 0
  name       = local.values.ingress_nginx.name
  namespace  = local.values.ingress_nginx.namespace
  chart      = local.values.ingress_nginx.chart
  version    = local.values.ingress_nginx.version
  repository = local.values.ingress_nginx.repository
  
  values = [yamlencode(local.values.ingress_nginx.values)]
  
  wait = true
  wait_for_jobs = true
}
