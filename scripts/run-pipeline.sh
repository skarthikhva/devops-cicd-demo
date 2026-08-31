#!/usr/bin/env bash
#
# run-pipeline.sh — bring up the entire local CD + observability stack for
# devops-cicd-demo with one command.
#
# What this does NOT do: the CI part (build/test/SonarCloud/Trivy/GHCR push)
# already runs automatically in GitHub Actions on every push -- see
# .github/workflows/ci.yml. This script reproduces everything downstream of
# that, locally: build the jar, build the image, stand up (or reuse) a kind
# cluster, deploy the app, deploy Prometheus/Grafana/Loki/Alertmanager, wire
# the dashboard and alert rules, and print how to reach all of it. It's
# idempotent -- safe to re-run any time you change code, a chart, or a
# values file.
#
# Usage:
#   ./scripts/run-pipeline.sh              full up (build, deploy, observe)
#   ./scripts/run-pipeline.sh --no-tests    skip the JUnit suite for a faster loop
#   ./scripts/run-pipeline.sh --down        remove the app + observability stack, keep the cluster
#   ./scripts/run-pipeline.sh --destroy     tear down everything, including the kind cluster
#   ./scripts/run-pipeline.sh --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CLUSTER_NAME="devops-demo"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE_MONITORING="monitoring"
IMAGE_NAME="devops-demo"
IMAGE_TAG="local"

SKIP_TESTS=false
MODE="up"

for arg in "$@"; do
  case "$arg" in
    --no-tests) SKIP_TESTS=true ;;
    --down) MODE="down" ;;
    --destroy) MODE="destroy" ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (use --help)" >&2
      exit 1
      ;;
  esac
done

# ---------- output helpers ----------
BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
step()  { printf "\n${BOLD}▶ %s${RESET}\n" "$1"; }
info()  { printf "  ${DIM}%s${RESET}\n" "$1"; }
ok()    { printf "  ${GREEN}✓ %s${RESET}\n" "$1"; }
warn()  { printf "  ${YELLOW}! %s${RESET}\n" "$1"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1 ($2)" >&2
    exit 1
  fi
}

uninstall_release() {
  # $1: release name, $2: namespace (optional -- omit for the default namespace).
  # Written without arrays: macOS ships bash 3.2 by default, where `set -u`
  # treats expanding an empty array as an unbound-variable error.
  local name="$1" ns="${2:-}"
  local ns_flag=""
  [[ -n "$ns" ]] && ns_flag="-n $ns"
  # shellcheck disable=SC2086 # ns_flag is intentionally unquoted: it's either
  # empty or exactly "-n <name>", never contains spaces of its own.
  if helm uninstall "$name" $ns_flag --kube-context "$KUBE_CONTEXT" 2>/dev/null; then
    ok "$name release removed"
  else
    info "$name release not installed"
  fi
}

# ---------- teardown paths ----------
if [[ "$MODE" == "down" || "$MODE" == "destroy" ]]; then
  step "Tearing down app and observability stack"
  uninstall_release devops-demo
  uninstall_release kube-prometheus-stack "$NAMESPACE_MONITORING"
  uninstall_release loki "$NAMESPACE_MONITORING"
  kubectl --context "$KUBE_CONTEXT" delete -f observability/devops-demo-alerts.yaml --ignore-not-found 2>/dev/null || true
  kubectl --context "$KUBE_CONTEXT" delete configmap devops-demo-dashboard -n "$NAMESPACE_MONITORING" --ignore-not-found 2>/dev/null || true

  if [[ "$MODE" == "destroy" ]]; then
    step "Deleting kind cluster '$CLUSTER_NAME'"
    if kind delete cluster --name "$CLUSTER_NAME"; then
      ok "cluster deleted"
    else
      warn "cluster delete failed (may not exist)"
    fi
  fi
  echo
  ok "Teardown complete."
  exit 0
fi

# ---------- preflight ----------
step "Checking required tools"
require_cmd docker "https://www.docker.com/products/docker-desktop"
require_cmd kind    "brew install kind"
require_cmd kubectl "brew install kubectl"
require_cmd helm    "brew install helm"
require_cmd java    "https://adoptium.net"
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon isn't running. Start Docker Desktop and retry." >&2
  exit 1
fi
ok "docker, kind, kubectl, helm, java all present; Docker daemon is up"

# ---------- build & test ----------
step "Building the application"
if [[ "$SKIP_TESTS" == "true" ]]; then
  warn "skipping tests (--no-tests)"
  ./mvnw clean package -DskipTests
else
  ./mvnw clean verify
fi
ok "jar built at target/devops-demo-*.jar"

# ---------- containerize ----------
step "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
ok "image built"

# ---------- cluster ----------
step "Ensuring kind cluster '$CLUSTER_NAME' exists"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  ok "cluster already running"
else
  info "creating cluster (this takes a minute)..."
  cat <<EOF | kind create cluster --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
EOF
  ok "cluster created"
fi

step "Loading image into the cluster"
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "$CLUSTER_NAME"
ok "image loaded"

step "Ensuring namespace '$NAMESPACE_MONITORING' exists"
kubectl --context "$KUBE_CONTEXT" get ns "$NAMESPACE_MONITORING" >/dev/null 2>&1 \
  || kubectl --context "$KUBE_CONTEXT" create ns "$NAMESPACE_MONITORING"
ok "namespace ready"

# ---------- observability stack ----------
step "Adding/updating Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
ok "repos ready"

# Loki must land before kube-prometheus-stack: its chart provisions a Grafana
# datasource ConfigMap that the kube-prometheus-stack Grafana sidecar picks up
# on first boot. See observability/README.md for the two gotchas this avoids.
step "Installing/upgrading Loki + Promtail"
helm upgrade --install loki grafana/loki-stack \
  --namespace "$NAMESPACE_MONITORING" \
  -f observability/loki-stack-values.yaml \
  --kube-context "$KUBE_CONTEXT" \
  --wait --timeout 5m
ok "loki ready"

step "Installing/upgrading kube-prometheus-stack (Prometheus, Grafana, Alertmanager)"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE_MONITORING" \
  -f observability/kube-prometheus-stack-values.yaml \
  --kube-context "$KUBE_CONTEXT" \
  --wait --timeout 8m
ok "prometheus stack ready"

# ---------- app ----------
step "Installing/upgrading the app"
helm upgrade --install devops-demo helm/devops-demo \
  --set image.repository="$IMAGE_NAME" \
  --set image.tag="$IMAGE_TAG" \
  --set image.pullPolicy=IfNotPresent \
  --set serviceMonitor.enabled=true \
  --kube-context "$KUBE_CONTEXT"

# The image tag string never changes between local rebuilds, so Kubernetes
# won't see a diff and won't restart the pod on its own -- force it.
step "Rolling out the latest image"
kubectl --context "$KUBE_CONTEXT" rollout restart deployment/devops-demo
kubectl --context "$KUBE_CONTEXT" rollout status deployment/devops-demo --timeout=90s
ok "app running on the new image"

# ---------- dashboard + alerts ----------
step "Provisioning the Grafana dashboard"
kubectl --context "$KUBE_CONTEXT" create configmap devops-demo-dashboard \
  --from-file=devops-demo-dashboard.json=observability/devops-demo-dashboard.json \
  --namespace "$NAMESPACE_MONITORING" --dry-run=client -o yaml \
  | kubectl label -f - --local -o yaml grafana_dashboard=1 \
  | kubectl --context "$KUBE_CONTEXT" apply -f - >/dev/null
ok "dashboard configmap applied"

step "Applying Prometheus alert rules"
kubectl --context "$KUBE_CONTEXT" apply -f observability/devops-demo-alerts.yaml >/dev/null
ok "alert rules applied"

# ---------- summary ----------
step "Done"
cat <<SUMMARY

${GREEN}${BOLD}Pipeline is up.${RESET}

  App:            kubectl port-forward svc/devops-demo 8080:8080
                  → http://localhost:8080

  Grafana:        kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
                  → http://localhost:3000/d/devops-demo/devops-demo  (admin / admin)

  Prometheus:     kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
  Alertmanager:   kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093

  Tear down:      ./scripts/run-pipeline.sh --down       (keep the cluster)
                  ./scripts/run-pipeline.sh --destroy     (delete the cluster too)

  Re-run any time you change code, a chart, or a values file -- it's idempotent.
SUMMARY
