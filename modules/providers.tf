terraform {
  required_version = ">= 1.5.7"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
  }
}

provider "kubernetes" {
  config_path    = local.values.defaults.kubeconfig_path
  config_context = local.values.defaults.cluster_name
}

provider "helm" {
  kubernetes {
    config_path    = local.values.defaults.kubeconfig_path
    config_context = local.values.defaults.cluster_name
  }
}