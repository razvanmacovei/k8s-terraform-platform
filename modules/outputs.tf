output "values" {
  description = "Values from configuration"
  value       = local.values
}

output "namespaces" {
  description = "List of created Kubernetes namespaces"
  value       = [for ns in kubernetes_namespace.namespaces : ns.metadata[0].name]
}

output "ingress_nginx_enabled" {
  description = "Whether Ingress NGINX is deployed"
  value       = length(helm_release.ingress_nginx) > 0
}

output "monitoring_enabled" {
  description = "Whether the monitoring stack is deployed"
  value       = length(helm_release.monitoring) > 0
}

output "argocd_enabled" {
  description = "Whether ArgoCD is deployed"
  value       = length(helm_release.argocd) > 0
}

output "environment" {
  description = "Current deployment environment"
  value       = local.values.defaults.env
}
