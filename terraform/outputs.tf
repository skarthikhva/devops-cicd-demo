output "app_port_forward" {
  description = "Command to reach the app."
  value       = "kubectl --context ${var.kube_context} port-forward svc/devops-demo 8080:8080"
}

output "grafana_port_forward" {
  description = "Command to reach Grafana (admin / admin -- see observability/kube-prometheus-stack-values.yaml)."
  value       = "kubectl --context ${var.kube_context} -n ${var.monitoring_namespace} port-forward svc/kube-prometheus-stack-grafana 3000:80"
}

output "grafana_dashboard_url" {
  description = "Dashboard URL once the Grafana port-forward above is running."
  value       = "http://localhost:3000/d/devops-demo/devops-demo"
}

output "prometheus_port_forward" {
  value = "kubectl --context ${var.kube_context} -n ${var.monitoring_namespace} port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
}

output "alertmanager_port_forward" {
  value = "kubectl --context ${var.kube_context} -n ${var.monitoring_namespace} port-forward svc/kube-prometheus-stack-alertmanager 9093:9093"
}
