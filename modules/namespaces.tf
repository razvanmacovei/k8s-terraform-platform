resource "kubernetes_namespace" "namespaces" {
  for_each = toset(local.values.namespaces)

  metadata {
    name = each.key
  }
}
