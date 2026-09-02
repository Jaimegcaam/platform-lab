#!/bin/bash
set -euo pipefail

echo "==> Creating k3d cluster (single node)..."
k3d cluster create --config bootstrap/k3d-config.yaml

kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Installing Argo CD..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/argocd-values.yaml

kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

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
