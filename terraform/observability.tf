resource "kubernetes_namespace" "monitoring" {
  depends_on = [null_resource.kind_cluster]

  metadata {
    name = var.monitoring_namespace
  }
}

# Loki must land before kube-prometheus-stack: its chart provisions a Grafana datasource
# ConfigMap that kube-prometheus-stack's Grafana sidecar picks up on first boot. Installing
# it after Grafana is already running needs a Grafana pod restart to pick up a changed
# datasource UID (see observability/README.md) -- ordering this dependency in Terraform
# means `terraform apply` always gets it right, on the first run and every run after.
resource "helm_release" "loki" {
  name       = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"

  values = [file("${path.module}/../observability/loki-stack-values.yaml")]

  wait    = true
  timeout = 300
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  values = [file("${path.module}/../observability/kube-prometheus-stack-values.yaml")]

  wait    = true
  timeout = 480

  depends_on = [helm_release.loki]
}

resource "kubernetes_config_map" "devops_demo_dashboard" {
  metadata {
    name      = "devops-demo-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "devops-demo-dashboard.json" = file("${path.module}/../observability/devops-demo-dashboard.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubectl_manifest" "devops_demo_alerts" {
  yaml_body = file("${path.module}/../observability/devops-demo-alerts.yaml")

  depends_on = [helm_release.kube_prometheus_stack]
}
