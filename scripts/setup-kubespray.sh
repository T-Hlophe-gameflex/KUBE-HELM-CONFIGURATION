#!/bin/bash

# Kubespray Kubernetes Cluster Setup for ELK Stack Platform
# Single-node local deployment with MetalLB + Auto ELK deployment + Log generation

set -euo pipefail

# Configuration
KUBESPRAY_DIR="/Users/thami.hlophe/kubespray"
INVENTORY_NAME="helm-kube-cluster"
INVENTORY_DIR="$KUBESPRAY_DIR/inventory/$INVENTORY_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for Kubespray deployment..."
    
    local missing=()
    
    if ! command -v python3 >/dev/null 2>&1; then
        missing+=("python3")
    fi
    
    if ! command -v ansible >/dev/null 2>&1; then
        missing+=("ansible")
    fi
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing+=("kubectl")
    fi
    
    if ! command -v helm >/dev/null 2>&1; then
        missing+=("helm")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install with: brew install ${missing[*]}"
        exit 1
    fi
    
    if [ ! -d "$KUBESPRAY_DIR" ]; then
        log_error "Kubespray directory not found: $KUBESPRAY_DIR"
        exit 1
    fi
    
    if [ ! -d "$INVENTORY_DIR" ]; then
        log_error "Inventory not found: $INVENTORY_DIR"
        exit 1
    fi
    
    log_success "All prerequisites installed"
}

# Deploy cluster with Kubespray
setup_cluster() {
    log_info "Deploying Kubernetes cluster with Kubespray..."
    log_warning "This will install Kubernetes on localhost (your Mac)"
    log_warning "Estimated time: 15-30 minutes"
    log_warning "Sudo password will be required"
    
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    cd "$KUBESPRAY_DIR"
    
    log_info "Running Kubespray playbook..."
    log_warning "You will be prompted for your sudo password..."
    ansible-playbook -i "$INVENTORY_DIR/inventory.ini" \
        --become \
        --become-user=root \
        --ask-become-pass \
        cluster.yml
    
    log_success "Cluster deployment complete!"
}

# Configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl access..."
    
    local kubeconfig="/etc/kubernetes/admin.conf"
    local dest="$HOME/.kube/config"
    
    if [ -f "$kubeconfig" ]; then
        mkdir -p "$HOME/.kube"
        sudo cp "$kubeconfig" "$dest"
        sudo chown $(id -u):$(id -g) "$dest"
        log_success "kubectl configured"
    else
        log_warning "Kubeconfig not found, may need manual setup"
    fi
}

# Verify cluster
verify_setup() {
    log_info "Verifying cluster setup..."
    
    kubectl cluster-info
    echo ""
    kubectl get nodes -o wide
    echo ""
    
    log_success "Cluster verification completed!"
}

# Deploy ELK stack
deploy_elk_stack() {
    log_info "Ready to deploy ELK stack..."
    
    echo ""
    read -p "Deploy ELK stack now? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping ELK stack deployment"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    log_info "Deploying with Ansible..."
    ansible-playbook playbooks/main.yml -e action=deploy
    
    log_success "ELK stack deployment initiated!"
    
    # Wait for pods to be ready
    log_info "Waiting for pods to become ready (this may take a few minutes)..."
    sleep 20
    
    log_info "Checking monitoring namespace..."
    kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s 2>/dev/null || log_warning "Some monitoring pods still starting"
    
    log_info "Checking backend namespace..."
    kubectl wait --for=condition=Ready pods --all -n backend --timeout=300s 2>/dev/null || log_warning "Some backend pods still starting"
    
    log_info "Checking database namespace..."
    kubectl wait --for=condition=Ready pods --all -n database --timeout=300s 2>/dev/null || log_warning "Some database pods still starting"
    
    echo ""
    log_info "Current pod status:"
    kubectl get pods -A
}

# Generate sample logs
generate_logs() {
    echo ""
    log_info "Checking if services are ready for log generation..."
    
    # Check if order-service and user-service are running
    local order_pods=$(kubectl get pods -n backend -l app=order-service --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local user_pods=$(kubectl get pods -n backend -l app=user-service --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$order_pods" -gt 0 && "$user_pods" -gt 0 ]]; then
        echo ""
        read -p "Generate sample logs to test the ELK stack? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_info "Starting log generation in background..."
            
            # Make sure the script is executable
            chmod +x "$SCRIPT_DIR/generate-sample-logs.sh"
            
            # Start log generation in background
            nohup "$SCRIPT_DIR/generate-sample-logs.sh" > /dev/null 2>&1 &
            local log_pid=$!
            
            log_success "Log generation started (PID: $log_pid)"
            log_info "Logs are being generated continuously"
            log_info "Stop with: pkill -f generate-sample-logs"
            
            # Give it a few seconds to generate some logs
            sleep 5
        else
            log_info "Skipping log generation"
            log_info "Generate logs later with: ./scripts/generate-sample-logs.sh"
        fi
    else
        log_warning "Backend services not fully ready yet"
        log_info "You can generate logs later with: ./scripts/generate-sample-logs.sh"
    fi
}

# Display final summary
show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 Complete Setup Finished!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 What was deployed:"
    echo "  ✅ Kubernetes cluster (Kubespray)"
    echo "  ✅ MetalLB LoadBalancer (172.18.255.200-250)"
    echo "  ✅ Elasticsearch cluster"
    echo "  ✅ Kibana dashboard"
    echo "  ✅ Logstash pipeline"
    echo "  ✅ Filebeat agent"
    echo "  ✅ PostgreSQL database"
    echo "  ✅ Order & User services"
    echo "  ✅ Sample log generation (running)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🌐 Access your services:"
    echo ""
    echo "  Kibana Dashboard:"
    echo "    kubectl port-forward -n monitoring svc/kibana 5601:5601"
    echo "    Then open: http://localhost:5601"
    echo ""
    echo "  Or use shortcut:"
    echo "    make kibana-forward"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Useful commands:"
    echo ""
    echo "  Check all pods:        kubectl get pods -A"
    echo "  Check services:        kubectl get svc -A"
    echo "  View logs:             kubectl logs -n backend <pod-name>"
    echo "  Stop log generation:   pkill -f generate-sample-logs"
    echo "  Generate more logs:    ./scripts/generate-sample-logs.sh"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Cluster: helm-kube-cluster"
    log_info "MetalLB IP range: 172.18.255.200-250"
    echo ""
}

# Main execution
main() {
    echo "🚀 Complete ELK Stack Platform Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Kubespray + MetalLB + ELK + Log Generation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_prerequisites
    setup_cluster
    configure_kubectl
    verify_setup
    deploy_elk_stack
    generate_logs
    show_summary
}

main "$@"
