variable "kubeconfig_path" {
  description = "Path to the kubeconfig file kind wrote when the cluster was created."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context for the local kind cluster."
  type        = string
  default     = "kind-devops-demo"
}

variable "cluster_name" {
  description = "Name of the kind cluster (must match kube_context's kind-<name> suffix)."
  type        = string
  default     = "devops-demo"
}

variable "monitoring_namespace" {
  description = "Namespace for Prometheus, Grafana, Alertmanager, and Loki."
  type        = string
  default     = "monitoring"
}

variable "app_image_repository" {
  description = "Image repository for the app. Kept local for this workshop; point at a registry (e.g. GHCR) to deploy an image built in CI instead of locally."
  type        = string
  default     = "devops-demo"
}

variable "app_image_tag" {
  description = "Image tag for the app."
  type        = string
  default     = "local"
}

variable "build_image_locally" {
  description = "If true, Terraform builds the image with `docker build` and loads it into kind before deploying. Set to false once you're deploying a pre-built image from a registry instead (e.g. after CI has pushed one) -- Terraform provisioning infrastructure and CI building the image are separate concerns in a real pipeline."
  type        = bool
  default     = true
}
