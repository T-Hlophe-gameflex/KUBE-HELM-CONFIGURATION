#!/bin/bash
set -euo pipefail

CLUSTER_NAME="helm-kube-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 Complete ELK Stack Platform Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! command -v kind >/dev/null; then
    log_error "Kind not installed. Install: brew install kind"
    exit 1
fi

log_info "Creating Kind cluster..."
cat > /tmp/kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: helm-kube-cluster
nodes:
- role: control-plane
- role: worker
- role: worker
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
EOF

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    log_info "Cluster exists, deleting..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

kind create cluster --config /tmp/kind-config.yaml --wait 300s
log_success "Cluster created!"

log_info "Deploying MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s

SUBNET=$(docker network inspect -f '{{.IPAM.Config}}' kind | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | head -1)
SUBNET_PREFIX=$(echo $SUBNET | cut -d'.' -f1-3)

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - ${SUBNET_PREFIX}.200-${SUBNET_PREFIX}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
EOF

log_success "MetalLB configured!"

log_info "Deploying ELK stack..."
cd "$PROJECT_ROOT"
ansible-playbook playbooks/main.yml -e action=deploy

log_success "ELK stack deployed!"

log_info "Waiting for pods..."
sleep 20
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s || true
kubectl wait --for=condition=Ready pods --all -n backend --timeout=300s || true
kubectl wait --for=condition=Ready pods --all -n database --timeout=300s || true

log_info "Generating sample logs..."
chmod +x "$SCRIPT_DIR/generate-sample-logs.sh"
nohup "$SCRIPT_DIR/generate-sample-logs.sh" > /dev/null 2>&1 &
log_success "Log generation started (PID: $!)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Access Kibana:"
echo "  kubectl port-forward -n monitoring svc/kibana 5601:5601"
echo "  open http://localhost:5601"
echo ""
echo "Check status:"
echo "  kubectl get pods -A"
echo ""
