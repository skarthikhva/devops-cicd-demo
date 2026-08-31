# Observability stack

Prometheus + Grafana + Alertmanager (via `kube-prometheus-stack`) and Loki + Promtail
(via `loki-stack`), deployed to a local `kind` cluster's `monitoring` namespace.

## Install order matters

Loki must go in **before** `kube-prometheus-stack`, because its chart provisions a Grafana
datasource ConfigMap that `kube-prometheus-stack`'s Grafana sidecar picks up on first boot.
Installing (or fixing) it after Grafana is already running requires deleting the Grafana pod
to clear its in-memory/SQLite datasource state (see the note in `loki-stack-values.yaml` about
`uid` only being set on initial creation).

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install loki grafana/loki-stack \
  --namespace monitoring \
  -f observability/loki-stack-values.yaml

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f observability/kube-prometheus-stack-values.yaml \
  --wait --timeout 8m
```

## Deploy the app with monitoring wired up

```bash
helm install devops-demo helm/devops-demo \
  --set image.repository=devops-demo \
  --set image.tag=local \
  --set image.pullPolicy=IfNotPresent \
  --set serviceMonitor.enabled=true
```

## Load the dashboard

```bash
kubectl create configmap devops-demo-dashboard \
  --from-file=devops-demo-dashboard.json=observability/devops-demo-dashboard.json \
  --namespace monitoring --dry-run=client -o yaml \
  | kubectl label -f - --local -o yaml grafana_dashboard=1 \
  | kubectl apply -f -
```

The `kube-prometheus-stack` Grafana sidecar auto-discovers it within a few seconds
(no restart needed for this one, since it doesn't set a `uid` that needs to be locked in
at creation time).

## Access

```bash
# Grafana (admin / admin -- set in kube-prometheus-stack-values.yaml)
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000/d/devops-demo/devops-demo

# Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Alertmanager
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093

# App
kubectl port-forward svc/devops-demo 8080:8080
```

## Known local-cluster quirks

- **Rollout restarts don't happen automatically on `helm upgrade` if the image tag string is
  unchanged** (e.g. always `:local` during dev). Force one with
  `kubectl rollout restart deployment/devops-demo` after `kind load docker-image`.
- **Loki has no persistent volume** (`loki.persistence.enabled: false`) -- log history is lost
  whenever the `loki-0` pod restarts. Fine for a demo; add a PVC for anything longer-lived.
- **Grafana has no persistent volume either** -- its admin password, dashboards, and
  datasources all come from provisioning (Helm values + the sidecar), not from state that
  needs to survive a pod restart. That's intentional here: it keeps the whole stack
  reproducible from files in this repo instead of from a stateful DB.
