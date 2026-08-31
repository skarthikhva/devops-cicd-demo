# serviceMonitor.enabled=true creates a ServiceMonitor custom resource, whose CRD is
# installed by kube-prometheus-stack -- so this release has to come after it.
locals {
  app_set_values = concat(
    [
      { name = "image.repository", value = var.app_image_repository },
      { name = "image.tag", value = var.app_image_tag },
      { name = "image.pullPolicy", value = "IfNotPresent" },
      { name = "serviceMonitor.enabled", value = "true" },
    ],
    # Helm only sees a diff -- and rolls the deployment -- when something in the release's
    # values actually changes. The image tag here is a fixed string ("local") across every
    # rebuild, so without this, a `terraform apply` after a code change would report
    # "up to date" and leave the OLD image running. Stamping the content hash into a pod
    # annotation makes the pod template genuinely different whenever the image is, which is
    # what actually triggers the rollout -- the same problem `kubectl rollout restart`
    # solves imperatively in run-pipeline.sh, solved declaratively here instead.
    var.build_image_locally ? [
      { name = "podAnnotations.source-hash", value = local.app_source_hash }
    ] : []
  )
}

resource "helm_release" "devops_demo" {
  name      = "devops-demo"
  namespace = "default"
  chart     = "${path.module}/../helm/devops-demo"

  dynamic "set" {
    for_each = local.app_set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  wait    = true
  timeout = 180

  depends_on = [
    helm_release.kube_prometheus_stack,
    null_resource.app_image,
  ]
}
