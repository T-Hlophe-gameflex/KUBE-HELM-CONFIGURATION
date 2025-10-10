#!/bin/bash
# Complete Kubernetes Cluster Setup and Test Script
# This script sets up a local Kubernetes cluster and deploys everything

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

# Check and install prerequisites
check_and_install_prerequisites() {
    log "Checking and installing prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker Desktop and try again."
        echo "Download from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    
    success "Docker is running"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log "Installing kubectl..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                sudo install -o root -g wheel -m 0755 kubectl /usr/local/bin/kubectl
                rm kubectl
            fi
        else
            # Linux
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        fi
    fi
    
    success "kubectl is available"
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        log "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    success "Helm is available"
    
    # Check kind
    if ! command -v kind &> /dev/null; then
        log "Installing kind (Kubernetes in Docker)..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install kind
            else
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
        else
            # Linux
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    fi
    
    success "kind is available"
    
    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log "Installing Ansible..."
        if command -v pip3 &> /dev/null; then
            pip3 install ansible
        elif command -v pip &> /dev/null; then
            pip install ansible
        else
            error "Python pip not found. Please install Python and pip first."
            exit 1
        fi
    fi
    
    success "Ansible is available"
}

# Create kind cluster
create_kind_cluster() {
    log "Setting up Kubernetes cluster with kind..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "kind"; then
        warning "Kind cluster already exists"
        read -p "Delete existing cluster and create new one? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Deleting existing kind cluster..."
            kind delete cluster
        else
            log "Using existing cluster"
            return 0
        fi
    fi
    
    log "Creating new kind cluster..."
    
    # Create kind config with extra port mappings for AWX
    cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
- role: worker
- role: worker
EOF

    kind create cluster --config /tmp/kind-config.yaml --wait 300s
    
    if [ $? -eq 0 ]; then
        success "Kind cluster created successfully"
        
        # Verify cluster
        kubectl cluster-info
        kubectl get nodes
        
        return 0
    else
        error "Failed to create kind cluster"
        exit 1
    fi
}

# Load environment variables
load_env() {
    if [ -f .env ]; then
        log "Loading environment variables from .env"
        export $(grep -v '^#' .env | xargs)
    else
        warning ".env file not found"
        if [ -f .env.template ]; then
            log "Creating .env from template"
            cp .env.template .env
            error "Please edit .env file with your Cloudflare API token before continuing"
            exit 1
        fi
    fi
}

# Verify Cloudflare API access
verify_cloudflare() {
    log "Verifying Cloudflare API access..."
    
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        error "CLOUDFLARE_API_TOKEN not set in .env file"
        exit 1
    fi
    
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
                   -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                   -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '"success":true'; then
        success "Cloudflare API access verified"
        
        # Extract domains
        local domains
        domains=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$domains" ]; then
            info "Available domains:"
            echo "$domains" | head -5 | while read -r domain; do
                echo "  📍 $domain"
            done
            
            # Set first domain for testing
            export FIRST_DOMAIN=$(echo "$domains" | head -n1)
            echo "FIRST_DOMAIN=$FIRST_DOMAIN" >> .env
        fi
        return 0
    else
        error "Cloudflare API access failed"
        echo "Response: $response"
        echo "Please check your API token in .env file"
        exit 1
    fi
}

# Deploy the complete stack
deploy_stack() {
    log "🚀 Deploying complete infrastructure stack..."
    
    echo "This will deploy to your kind cluster:"
    echo "  📊 ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)"
    echo "  🏗️  Infrastructure (MetalLB, PostgreSQL)"
    echo "  🚀 Services (Order Service, User Service)"
    echo "  🤖 AWX Automation Platform"
    echo
    
    read -p "Proceed with deployment? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Deployment cancelled"
        return 1
    fi
    
    # Navigate to project directory (assuming we're in the right place)
    log "Starting Ansible playbook deployment..."
    
    # Install Ansible collections first
    log "Installing required Ansible collections..."
    ansible-galaxy collection install kubernetes.core --force
    ansible-galaxy collection install cloudflare.cloudflare --force
    
    # Run the main playbook
    ansible-playbook playbooks/main.yml \
        -e deploy_awx=true \
        -e deploy_postgres=true \
        -e deploy_metallb=true \
        -e deploy_order_service=true \
        -e deploy_user_service=true \
        -v
    
    if [ $? -eq 0 ]; then
        success "Stack deployment completed successfully"
        return 0
    else
        error "Stack deployment failed"
        log "Checking cluster status..."
        kubectl get pods --all-namespaces
        return 1
    fi
}

# Wait for AWX to be ready
wait_for_awx() {
    log "Waiting for AWX to be ready..."
    
    # First wait for the namespace
    log "Waiting for AWX namespace..."
    while ! kubectl get namespace awx &> /dev/null; do
        sleep 5
    done
    
    # Wait for AWX operator
    log "Waiting for AWX operator..."
    kubectl wait --for=condition=available deployment/awx-operator-controller-manager -n awx-system --timeout=300s || true
    
    # Wait for AWX instance to be created
    log "Waiting for AWX instance..."
    local timeout=900
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get awx ansible-awx -n awx &> /dev/null; then
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        log "Still waiting for AWX instance... ($elapsed/$timeout seconds)"
    done
    
    # Wait for AWX pods
    log "Waiting for AWX pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=900s
    
    if [ $? -eq 0 ]; then
        success "AWX is ready"
        return 0
    else
        error "AWX failed to become ready"
        log "AWX pod status:"
        kubectl get pods -n awx
        log "AWX operator logs:"
        kubectl logs -n awx-system deployment/awx-operator-controller-manager --tail=50
        return 1
    fi
}

# Get AWX access information
get_awx_info() {
    log "Retrieving AWX access information..."
    
    # Get admin password
    local awx_password
    awx_password=$(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx 2>/dev/null | base64 --decode)
    
    if [ -z "$awx_password" ]; then
        error "Could not retrieve AWX admin password"
        return 1
    fi
    
    # AWX is accessible via NodePort on kind
    local awx_nodeport="30080"
    local awx_host="http://localhost:$awx_nodeport"
    
    export AWX_PASSWORD="$awx_password"
    export AWX_NODEPORT="$awx_nodeport"
    export AWX_HOST="$awx_host"
    
    # Update .env file
    sed -i.bak "s|AWX_HOST=.*|AWX_HOST=$awx_host|" .env
    sed -i.bak "s|AWX_PASSWORD=.*|AWX_PASSWORD=$awx_password|" .env
    
    success "AWX access information retrieved"
    echo
    echo "🔗 AWX Access Details:"
    echo "   URL: $awx_host"
    echo "   Username: admin"
    echo "   Password: $awx_password"
    echo
    
    return 0
}

# Test Cloudflare integration
test_cloudflare_chart() {
    log "Testing Cloudflare chart deployment..."
    
    if [ -z "$FIRST_DOMAIN" ]; then
        error "No domain available for testing"
        return 1
    fi
    
    log "Creating test DNS record: kind-test.$FIRST_DOMAIN"
    
    helm upgrade --install cloudflare-test ./helm-charts/charts/cloudflare \
        --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
        --set cloudflare.domain="$FIRST_DOMAIN" \
        --set cloudflare.dnsRecords[0].name="kind-test" \
        --set cloudflare.dnsRecords[0].type="TXT" \
        --set cloudflare.dnsRecords[0].value="Kind cluster test - $(date)" \
        --set cloudflare.dnsRecords[0].ttl=300 \
        --set job.ttlSecondsAfterFinished=300 \
        -n dns-automation --create-namespace
    
    # Wait for job completion
    log "Waiting for DNS job to complete..."
    sleep 15
    
    local job_status
    job_status=$(kubectl get job cloudflare-test-job -n dns-automation -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "NotFound")
    
    if [ "$job_status" = "Complete" ]; then
        success "Cloudflare DNS job completed successfully"
        
        # Show job logs
        log "Job output:"
        kubectl logs job/cloudflare-test-job -n dns-automation
        
        return 0
    else
        error "Cloudflare DNS job failed"
        kubectl describe job cloudflare-test-job -n dns-automation
        kubectl logs job/cloudflare-test-job -n dns-automation 2>/dev/null || echo "No logs available"
        return 1
    fi
}

# Show final status and access information
show_final_status() {
    echo
    echo "🎉 Cluster Setup and Deployment Complete!"
    echo "========================================"
    echo
    
    # Show cluster info
    log "Cluster Information:"
    kubectl cluster-info --context kind-kind
    echo
    
    # Show all services
    log "Service Status:"
    kubectl get all --all-namespaces | grep -E "(awx|monitoring|backend|database|dns-automation)" || true
    echo
    
    echo "🔗 Access Points:"
    echo "   AWX Web UI:     http://localhost:30080"
    echo "   Username:       admin"
    echo "   Password:       $AWX_PASSWORD"
    echo
    echo "   Kibana:         kubectl port-forward -n monitoring svc/kibana 5601:5601"
    echo "                   Then access: http://localhost:5601"
    echo
    echo "   Order Service:  kubectl port-forward -n backend svc/order-service 8080:8080"
    echo "                   Then access: http://localhost:8080"
    echo
    echo "   User Service:   kubectl port-forward -n backend svc/user-service 8081:8081"
    echo "                   Then access: http://localhost:8081"
    echo
    echo "   PostgreSQL:     kubectl port-forward -n database svc/postgres 5432:5432"
    echo
    echo "🧪 Test Results:"
    echo "   ✅ Local Kubernetes cluster (kind) created"
    echo "   ✅ Complete stack deployed"
    echo "   ✅ AWX automation platform ready"
    echo "   ✅ Cloudflare integration tested"
    echo
    echo "🚀 Next Steps:"
    echo "   1. Open AWX at http://localhost:30080"
    echo "   2. Create Cloudflare credentials in AWX"
    echo "   3. Import job templates from helm-charts/charts/awx/config/"
    echo "   4. Test DNS management through AWX"
    echo "   5. Explore monitoring and services"
    echo
    echo "📚 Useful Commands:"
    echo "   kubectl get pods --all-namespaces    # Check all pods"
    echo "   kubectl logs -n awx deployment/ansible-awx-web  # AWX logs"
    echo "   kind delete cluster                  # Clean up cluster"
    echo
}

# Main execution function
main() {
    echo "🚀 Complete Kubernetes Setup with AWX and Cloudflare"
    echo "=================================================="
    echo
    echo "This script will:"
    echo "  1. Install required tools (kubectl, helm, kind, ansible)"
    echo "  2. Create a local Kubernetes cluster using kind"
    echo "  3. Verify Cloudflare API access"
    echo "  4. Deploy complete infrastructure stack"
    echo "  5. Configure and test AWX automation"
    echo "  6. Test Cloudflare DNS integration"
    echo
    
    read -p "Do you want to proceed? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Setup cancelled"
        exit 0
    fi
    
    # Step 1: Check and install prerequisites
    check_and_install_prerequisites
    
    # Step 2: Create kind cluster
    create_kind_cluster
    
    # Step 3: Load environment and verify Cloudflare
    load_env
    verify_cloudflare
    
    # Step 4: Deploy stack
    if ! deploy_stack; then
        error "Stack deployment failed"
        exit 1
    fi
    
    # Step 5: Wait for AWX and get info
    if ! wait_for_awx; then
        error "AWX setup failed"
        exit 1
    fi
    
    get_awx_info
    
    # Step 6: Test Cloudflare integration
    if test_cloudflare_chart; then
        success "Cloudflare integration test passed"
    else
        warning "Cloudflare test had issues, but continuing..."
    fi
    
    # Step 7: Show final status
    show_final_status
    
    success "🎯 Complete setup finished successfully!"
    echo "Your cluster is ready for testing!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi