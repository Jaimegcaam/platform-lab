#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

trap 'echo "ERROR: bootstrap failed (line ${LINENO}). If the cluster is half-broken, run: k3d cluster delete platform-lab" >&2' ERR

check_prereqs() {
  local missing=0
  for cmd in docker kubectl helm k3d; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "ERROR: ${cmd} is not installed or not in PATH" >&2
      missing=1
    fi
  done

  if [[ "${missing}" -eq 1 ]]; then
    cat >&2 <<'EOF'

Install missing tools on Ubuntu/WSL:

  # Helm
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  # k3d
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

  # kubectl (official binary)
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl && sudo mv kubectl /usr/local/bin/

Docker: install Docker Desktop with WSL2 integration, or Docker Engine in WSL.
Then re-run: ./bootstrap/create-cluster.sh

EOF
    exit 1
  fi
}

check_prereqs

echo "==> Working directory: ${REPO_ROOT}"

echo "==> Preparing local storage directory..."
mkdir -p /tmp/platform-lab-storage

echo "==> Creating k3d cluster (single node)..."
if k3d cluster list 2>/dev/null | grep -q '^platform-lab'; then
  fail "cluster 'platform-lab' already exists. Delete it first: k3d cluster delete platform-lab"
fi

k3d cluster create --config bootstrap/k3d-config.yaml

echo "==> Waiting for the API server..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s
# Nodes can be Ready before the API accepts Helm installs on a fresh cluster.
for i in {1..30}; do
  kubectl get --raw /livez >/dev/null 2>&1 && break
  sleep 2
done
kubectl get --raw /livez >/dev/null 2>&1 || fail "Kubernetes API is not responding yet"

echo "==> Installing Argo CD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update || fail "helm repo update failed — check your network connection"

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/argocd-values.yaml \
  --wait \
  --timeout 10m

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "==> Setting Grafana credentials (Secret, not stored in Git)..."
read -s -p "Grafana admin password: " GRAFANA_PASS
echo ""

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic grafana-admin-credentials \
  --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$GRAFANA_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

unset GRAFANA_PASS

echo "==> Applying App of Apps..."
kubectl apply -f gitops/clusters/platform-lab/root-app.yaml

cat <<'EOF'

Done.

1. Add to your hosts file (Windows: C:\Windows\System32\drivers\etc\hosts | WSL: /etc/hosts):
     127.0.0.1 argocd.local grafana.local

2. Access via ingress (port 8080):
     http://argocd.local:8080   (admin — see argocd-initial-admin-secret)
     http://grafana.local:8080  (admin — password you just set)

3. Alternative Argo CD port-forward:
     kubectl port-forward svc/argocd-server -n argocd 8081:443

EOF
