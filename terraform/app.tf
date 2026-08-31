# The runtime half of secrets management: a Kubernetes Secret managed declaratively here,
# never committed to git, never written into a Helm values file. Terraform state does hold
# the plaintext (as it does for any resource attribute) -- state is protected the same way
# .tfvars/.tfstate secrets always are, out of scope for this demo. What matters for the
# chart and for git is that only the Secret's *name* flows into the app_set_values below.
resource "kubernetes_secret" "devops_demo" {
  metadata {
    name = "devops-demo-secrets"
  }

  data = {
    DEMO_API_KEY = "demo-value-not-a-real-secret"
  }
}

# serviceMonitor.enabled=true creates a ServiceMonitor custom resource, whose CRD is
# installed by kube-prometheus-stack -- so this release has to come after it.
locals {
  app_set_values = concat(
    [
      { name = "image.repository", value = var.app_image_repository },
      { name = "image.tag", value = var.app_image_tag },
      { name = "image.pullPolicy", value = "IfNotPresent" },
      { name = "serviceMonitor.enabled", value = "true" },
      { name = "envFrom[0].secretRef.name", value = kubernetes_secret.devops_demo.metadata[0].name },
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
