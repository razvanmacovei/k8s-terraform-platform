terraform {
  required_version = ">= 1.5.7"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path    = local.values.defaults.kubeconfig_path
  config_context = local.values.defaults.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = local.values.defaults.kubeconfig_path
    config_context = local.values.defaults.kube_context
  }
}