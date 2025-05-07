resource "helm_release" "open_webui" {
  count      = lookup(local.values.open_webui, "enabled", false) == true ? 1 : 0
  name       = local.values.open_webui.name
  namespace  = local.values.open_webui.namespace
  chart      = local.values.open_webui.chart
  version    = local.values.open_webui.version
  repository = local.values.open_webui.repository

  values = [yamlencode(local.values.open_webui.values)]

  depends_on = [null_resource.add_open_webui_repo]

  wait = true
  wait_for_jobs = true
}