resource "helm_release" "vault" {
  count      = lookup(local.values.vault, "enabled", false) == true ? 1 : 0
  name       = local.values.vault.name
  namespace  = local.values.vault.namespace
  repository = local.values.vault.repository
  chart      = local.values.vault.chart
  version    = local.values.vault.version

  values = [yamlencode(local.values.vault.values)]

  depends_on = [
    kubernetes_namespace.namespaces,
    helm_release.ingress_nginx,
    null_resource.selfsigned_issuer,
  ]

  # When auto_init is enabled, Vault pods won't pass readiness probes until
  # unsealed — so Helm must not wait (the null_resource handles the wait).
  wait          = lookup(lookup(local.values.vault, "auto_init", {}), "enabled", false) == true ? false : true
  wait_for_jobs = lookup(lookup(local.values.vault, "auto_init", {}), "enabled", false) == true ? false : true
}

# Auto-initialize and unseal Vault after Helm deploys it.
# Credentials are stored in a K8s Secret so Terraform can read them back.
resource "null_resource" "vault_init_unseal" {
  count = (
    lookup(local.values.vault, "enabled", false) == true &&
    lookup(lookup(local.values.vault, "auto_init", {}), "enabled", false) == true
  ) ? 1 : 0

  depends_on = [helm_release.vault]

  triggers = {
    vault_release_id = helm_release.vault[0].id
  }

  provisioner "local-exec" {
    command = "${path.module}/../scripts/vault-init-unseal.sh"
    environment = {
      VAULT_NAMESPACE     = local.values.vault.namespace
      VAULT_POD_PREFIX    = local.values.vault.name
      VAULT_KEY_SHARES    = tostring(local.values.vault.auto_init.key_shares)
      VAULT_KEY_THRESHOLD = tostring(local.values.vault.auto_init.key_threshold)
      VAULT_SECRET_NAME   = lookup(local.values.vault.auto_init, "secret_name", "vault-unseal-keys")
      VAULT_HA_ENABLED    = tostring(lookup(lookup(local.values.vault.values, "server", {}), "ha", null) != null ? lookup(lookup(local.values.vault.values.server, "ha", {}), "enabled", false) : false)
      VAULT_HA_REPLICAS   = tostring(lookup(lookup(lookup(local.values.vault.values, "server", {}), "ha", {}), "replicas", 1))
    }
  }
}

data "kubernetes_secret" "vault_unseal_keys" {
  count = (
    lookup(local.values.vault, "enabled", false) == true &&
    lookup(lookup(local.values.vault, "auto_init", {}), "enabled", false) == true
  ) ? 1 : 0

  depends_on = [null_resource.vault_init_unseal]

  metadata {
    name      = lookup(local.values.vault.auto_init, "secret_name", "vault-unseal-keys")
    namespace = local.values.vault.namespace
  }
}
