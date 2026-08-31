# Terraform (declarative alternative to run-pipeline.sh)

`scripts/run-pipeline.sh` brings up the same environment imperatively (bash + `helm`/`kubectl`
CLI calls in a fixed order). This directory does it declaratively instead: `terraform plan`
shows you what would change before it happens, and `terraform apply` converges the cluster to
match the `.tf` files, tracked in state. Both read the *same* underlying files
(`observability/*.yaml`, `helm/devops-demo/`) — there's one source of truth for what gets
deployed, just two different ways of driving it.

## What it manages

- The `kind` cluster itself (create-if-missing)
- The application image (`docker build` + `kind load docker-image`) — see `build_image_locally`
  below if you'd rather deploy an already-published image instead
- `monitoring` namespace, Loki, kube-prometheus-stack (Prometheus + Grafana + Alertmanager),
  in that order — Loki has to land first, see the comment in `observability.tf`
- The app's Helm release, with `serviceMonitor.enabled=true`
- The Grafana dashboard ConfigMap and the `PrometheusRule` alert rules

## Usage

```bash
./apply.sh          # one command: bootstrap the cluster, then deploy everything into it
terraform plan       # see what would change, once the cluster exists
terraform destroy    # tear down everything, including the kind cluster
```

### Why `apply.sh` instead of just `terraform apply`

The `kubernetes` and `helm` providers validate their target context *when they're
configured* — before Terraform has decided what to create. On a machine with no `kind`
cluster yet, that fails immediately (`context "kind-devops-demo" does not exist`), before ever
reaching the resource that would have created it. This isn't a bug in this configuration; it's
a known limitation of provisioning a cluster and deploying into it in one Terraform run. The
standard fix — and what `apply.sh` does — is two applies: one narrowly targeted at just the
cluster (`-target=null_resource.kind_cluster`), then a normal one for everything else, once the
context is real.

### Forcing a rollout when only the image changed

The image tag (`local`) is a fixed string across every rebuild, so Helm never sees a diff in
the release's values and won't roll the deployment on its own — the same problem
`run-pipeline.sh` solves imperatively with `kubectl rollout restart`. Here it's solved
declaratively: a hash of `Dockerfile`, `pom.xml`, and `src/**` is stamped into a
`podAnnotations.source-hash` value on the Helm release. Whenever the source actually changes,
the pod template genuinely changes too, which is what triggers the rollout.

### Deploying a pre-built image instead of building locally

Set `build_image_locally = false` (in a `.tfvars` file, or `-var`) and point
`app_image_repository`/`app_image_tag` at a real image — e.g. the one CI already built and
pushed to GHCR. Building the image is arguably CI's job, not IaC's; `build_image_locally=true`
just keeps this workshop's `apply.sh` fully self-contained without needing a registry.

## Verified

Ran the full cycle against a real (local) cluster, from nothing:
`terraform destroy` (including the `kind` cluster) → `./apply.sh` from a completely clean
machine state → confirmed every pod `Running`, the app healthy, the custom Prometheus metric
scraping, the Grafana dashboard and Loki datasource provisioned correctly on the *first* boot
(no manual pod restart needed, unlike the imperative path — Terraform's dependency graph
enforces the Loki-before-Grafana ordering automatically, every time) → re-ran `terraform apply`
and confirmed "No changes" (idempotent) → edited a source file, confirmed `terraform plan`
detected it and rolled a new pod → reverted, reapplied, confirmed it rolled back to the
original image deterministically → `terraform destroy` again, confirmed the `kind` cluster was
actually deleted, not just dropped from state.
