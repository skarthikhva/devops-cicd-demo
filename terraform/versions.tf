terraform {
  required_version = ">= 1.5"

  required_providers {
    null       = { source = "hashicorp/null", version = "~> 3.2" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.31" }
    helm       = { source = "hashicorp/helm", version = "~> 2.14" }
    # hashicorp/kubernetes' own kubernetes_manifest resource validates CRD schemas at
    # `plan` time against the live API server -- which fails on a brand-new cluster where
    # the PrometheusRule CRD (installed by the kube-prometheus-stack chart) doesn't exist
    # yet. kubectl_manifest sidesteps that by not requiring the schema at plan time.
    kubectl = { source = "gavinbunney/kubectl", version = "~> 1.14" }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_path
  config_context   = var.kube_context
  load_config_file = true
}
