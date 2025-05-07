output "values" {
  description = "Values from configuration"
  value       = local.values
}

output "namespaces" {
  description = "List of created Kubernetes namespaces"
  value       = [for ns in kubernetes_namespace.namespaces : ns.metadata[0].name]
}