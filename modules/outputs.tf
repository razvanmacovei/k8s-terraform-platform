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

output "vault_root_token" {
  description = "Vault root token (only available when auto_init is enabled)"
  sensitive   = true
  value       = length(data.kubernetes_secret.vault_unseal_keys) > 0 ? data.kubernetes_secret.vault_unseal_keys[0].data["root-token"] : null
}

output "vault_unseal_keys" {
  description = "Vault unseal keys as JSON array (only available when auto_init is enabled)"
  sensitive   = true
  value       = length(data.kubernetes_secret.vault_unseal_keys) > 0 ? data.kubernetes_secret.vault_unseal_keys[0].data["unseal-keys-json"] : null
}

output "vault_credentials_help" {
  description = "How to retrieve Vault credentials"
  value       = length(data.kubernetes_secret.vault_unseal_keys) > 0 ? "Run: terraform -chdir=./modules output -raw vault_root_token" : null
}
