#!/bin/bash
set -euo pipefail

CLUSTER_NAME="helm-kube-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🚀 Complete Platform Setup with AWX & Cloudflare"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Load environment variables
load_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log_info "Loading environment variables..."
        export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
    else
        log_warning "No .env file found. Cloudflare features will be limited."
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kind >/dev/null; then
        log_error "Kind not installed. Install: brew install kind"
        exit 1
    fi
    
    if ! command -v helm >/dev/null; then
        log_error "Helm not installed. Install: brew install helm"
        exit 1
    fi
    
    if ! command -v ansible-playbook >/dev/null; then
        log_error "Ansible not installed. Install: pip install ansible"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker not running. Please start Docker Desktop."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Test Cloudflare API if token is available
test_cloudflare() {
    if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
        log_info "Testing Cloudflare API access..."
        
        local response
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
                       -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                       -H "Content-Type: application/json")
        
        if echo "$response" | grep -q '"success":true'; then
            log_success "Cloudflare API access verified"
            
            # Extract first domain for testing
            local first_domain
            first_domain=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -1)
            if [ -n "$first_domain" ]; then
                export FIRST_DOMAIN="$first_domain"
                log_info "Using domain for testing: $first_domain"
            fi
        else
            log_warning "Cloudflare API access failed - continuing without Cloudflare features"
        fi
    else
        log_warning "No Cloudflare API token found - skipping Cloudflare features"
    fi
}

# Create Kind cluster with AWX port mapping
create_cluster() {
    log_info "Creating Kind cluster with AWX support..."
    
    cat > /tmp/kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: helm-kube-cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30601
    hostPort: 30601
    protocol: TCP
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
    log_success "Cluster created with AWX port mapping!"
}

# Deploy MetalLB
deploy_metallb() {
    log_info "Deploying MetalLB..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
    kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s

    # Configure MetalLB IP pool
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
}

# Install required Ansible collections
install_collections() {
    log_info "Installing required Ansible collections..."
    ansible-galaxy collection install kubernetes.core --force > /dev/null 2>&1
    ansible-galaxy collection install cloudflare.cloudflare --force > /dev/null 2>&1
    log_success "Ansible collections installed"
}

# Deploy the complete stack
deploy_stack() {
    log_info "Deploying complete platform stack..."
    cd "$PROJECT_ROOT"
    
    # Deploy everything including AWX
    ansible-playbook playbooks/main.yml \
        -e action=deploy \
        -e deploy_awx=true \
        -e deploy_postgres=true \
        -e deploy_metallb=false \
        -e deploy_order_service=true \
        -e deploy_user_service=true \
        -v
    
    log_success "Platform stack deployed!"
}

# Wait for AWX to be ready
wait_for_awx() {
    log_info "Waiting for AWX to be ready (this may take 5-10 minutes)..."
    
    # Wait for AWX namespace
    until kubectl get namespace awx >/dev/null 2>&1; do
        sleep 5
    done
    
    # Wait for AWX operator
    log_info "Waiting for AWX operator..."
    kubectl wait --for=condition=available deployment/awx-operator-controller-manager -n awx-system --timeout=300s || true
    
    # Wait for AWX instance
    log_info "Waiting for AWX instance..."
    local timeout=600
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get awx ansible-awx -n awx >/dev/null 2>&1; then
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        if [ $((elapsed % 60)) -eq 0 ]; then
            log_info "Still waiting for AWX... ($elapsed/$timeout seconds)"
        fi
    done
    
    # Wait for AWX pods
    log_info "Waiting for AWX pods..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=600s
    
    log_success "AWX is ready!"
}

# Get AWX access information
get_awx_info() {
    log_info "Retrieving AWX access information..."
    
    local awx_password
    awx_password=$(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode)
    
    export AWX_PASSWORD="$awx_password"
    export AWX_HOST="http://localhost:30080"
    
    log_success "AWX access information retrieved"
}

# Test Cloudflare integration
test_cloudflare_integration() {
    if [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && [ -n "${FIRST_DOMAIN:-}" ]; then
        log_info "Testing Cloudflare DNS integration..."
        
        helm upgrade --install cloudflare-test "$PROJECT_ROOT/helm-charts/charts/cloudflare" \
            --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
            --set cloudflare.domain="$FIRST_DOMAIN" \
            --set cloudflare.dnsRecords[0].name="kind-test" \
            --set cloudflare.dnsRecords[0].type="TXT" \
            --set cloudflare.dnsRecords[0].value="Kind cluster test - $(date)" \
            --set cloudflare.dnsRecords[0].ttl=300 \
            --set job.ttlSecondsAfterFinished=300 \
            -n dns-automation --create-namespace \
            --wait --timeout=5m
        
        log_success "Cloudflare integration tested successfully!"
    else
        log_warning "Skipping Cloudflare test - no API token or domain available"
    fi
}

# Wait for all services
wait_for_services() {
    log_info "Waiting for all services to be ready..."
    
    # Wait with timeout and better error handling
    kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s || log_warning "Some monitoring pods may not be ready"
    kubectl wait --for=condition=Ready pods --all -n backend --timeout=300s || log_warning "Some backend pods may not be ready"
    kubectl wait --for=condition=Ready pods --all -n database --timeout=300s || log_warning "Some database pods may not be ready"
    
    log_success "Core services are ready!"
}

# Generate sample logs
generate_sample_logs() {
    log_info "Starting sample log generation..."
    if [ -f "$SCRIPT_DIR/generate-sample-logs.sh" ]; then
        chmod +x "$SCRIPT_DIR/generate-sample-logs.sh"
        nohup "$SCRIPT_DIR/generate-sample-logs.sh" > /dev/null 2>&1 &
        log_success "Log generation started (PID: $!)"
    else
        log_warning "Sample log generator not found"
    fi
}

# Show final status and access information
show_access_info() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 Complete Platform Setup Finished!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "🔗 Access Points:"
    echo "  📊 Kibana Dashboard:"
    echo "      kubectl port-forward -n monitoring svc/kibana 5601:5601"
    echo "      📱 Then open: http://localhost:5601"
    echo ""
    
    if [ -n "${AWX_PASSWORD:-}" ]; then
        echo "  🤖 AWX Automation Platform:"
        echo "      📱 Direct access: http://localhost:30080"
        echo "      👤 Username: admin"
        echo "      🔑 Password: $AWX_PASSWORD"
        echo ""
    fi
    
    echo "  🚀 Application Services:"
    echo "      Order Service: kubectl port-forward -n backend svc/order-service 8080:8080"
    echo "      User Service:  kubectl port-forward -n backend svc/user-service 8081:8081"
    echo "      PostgreSQL:    kubectl port-forward -n database svc/postgres 5432:5432"
    echo ""
    
    if [ -n "${FIRST_DOMAIN:-}" ]; then
        echo "  ☁️  Cloudflare DNS:"
        echo "      🌐 Test domain: $FIRST_DOMAIN"
        echo "      ✅ Integration tested successfully"
        echo ""
    fi
    
    echo "📋 Quick Commands:"
    echo "  kubectl get pods -A                    # Check all pods"
    echo "  kubectl logs -n awx deployment/ansible-awx-web  # AWX logs"
    echo "  helm list -A                          # List all releases"
    echo "  kind delete cluster --name $CLUSTER_NAME  # Clean up"
    echo ""
    
    echo "🚀 Next Steps:"
    echo "  1. Access AWX web interface and create Cloudflare credentials"
    echo "  2. Import job templates from helm-charts/charts/awx/config/"
    echo "  3. Test DNS management through AWX surveys"
    echo "  4. Explore monitoring dashboards in Kibana"
    echo "  5. Check application logs and metrics"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    load_env
    test_cloudflare
    create_cluster
    deploy_metallb
    install_collections
    deploy_stack
    wait_for_awx
    get_awx_info
    test_cloudflare_integration
    wait_for_services
    generate_sample_logs
    show_access_info
}

# Run main function
main