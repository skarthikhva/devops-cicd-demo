#!/usr/bin/env bash
#
# apply.sh -- one-command Terraform apply for the local pipeline.
#
# Why this isn't just `terraform apply`: the kubernetes/helm providers validate their
# target context when they're configured, which happens before Terraform decides what to
# create -- so on a completely fresh machine, with no kind cluster yet, they fail immediately
# ("context kind-devops-demo does not exist") before ever reaching the null_resource that
# would have created it. This is a known limitation of provisioning a cluster and deploying
# into it in the same Terraform run; the standard fix is two applies: one narrowly targeted
# at just the cluster, then a normal one for everything else, once the context is real.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

terraform init -input=false
terraform apply -target=null_resource.kind_cluster -auto-approve
terraform apply -auto-approve
