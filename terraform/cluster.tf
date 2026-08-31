# Terraform's kubernetes/helm providers assume a cluster already exists -- same as real
# Terraform for AKS/EKS doesn't provision the subscription or account underneath it. Since a
# local kind cluster IS cheap to create declaratively, this null_resource brings it up as part
# of `terraform apply`, so the whole stack is still reachable with one command.
resource "null_resource" "kind_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    config_hash  = filesha1("${path.module}/kind-config.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if kind get clusters 2>/dev/null | grep -qx "${var.cluster_name}"; then
        echo "kind cluster '${var.cluster_name}' already exists"
      else
        kind create cluster --config "${path.module}/kind-config.yaml"
      fi
    EOT
  }

  # local-exec only runs on create by default -- without `when = destroy`, `terraform
  # destroy` would just drop this resource from state and leave the actual kind cluster
  # running. Destroy-time provisioners can only reference `self`, which is why the cluster
  # name is read back out of this resource's own triggers instead of `var.cluster_name`.
  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name \"${self.triggers.cluster_name}\" || true"
  }
}

# Building the application image is arguably CI's job, not IaC's -- in a real pipeline the
# image would already be sitting in a registry (GHCR) by the time Terraform runs, and
# app_image_repository/app_image_tag would just point at it. build_image_locally=true keeps
# this workshop's `terraform apply` fully self-contained without a registry; flip it to false
# once you're deploying a CI-built image instead.
locals {
  app_source_files = var.build_image_locally ? sort(fileset("${path.module}/..", "src/**")) : []
  app_source_hash = var.build_image_locally ? sha1(join("", concat(
    [filesha1("${path.module}/../Dockerfile")],
    [filesha1("${path.module}/../pom.xml")],
    [for f in local.app_source_files : filesha1("${path.module}/../${f}")]
  ))) : "external-image"
}

resource "null_resource" "app_image" {
  count      = var.build_image_locally ? 1 : 0
  depends_on = [null_resource.kind_cluster]

  triggers = {
    source_hash = local.app_source_hash
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command     = <<-EOT
      set -euo pipefail
      docker build -t "${var.app_image_repository}:${var.app_image_tag}" .
      kind load docker-image "${var.app_image_repository}:${var.app_image_tag}" --name "${var.cluster_name}"
    EOT
  }
}
