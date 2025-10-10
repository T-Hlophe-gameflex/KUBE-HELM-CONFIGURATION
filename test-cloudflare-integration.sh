#!/bin/bash
# Quick Cloudflare Integration Test Script
# This script helps you quickly test the Cloudflare + AWX integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Step 1: Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm not found. Please install helm."
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        error "curl not found. Please install curl."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Step 2: Get Cloudflare API details
setup_cloudflare_credentials() {
    log "Setting up Cloudflare credentials..."
    
    if [ -z "$CLOUDFLARE_API_TOKEN" ] && [ -z "$CLOUDFLARE_EMAIL" ]; then
        echo
        echo "Please provide your Cloudflare credentials:"
        echo "Option 1: API Token (Recommended)"
        echo "  - Go to https://dash.cloudflare.com/profile/api-tokens"
        echo "  - Create token with Zone:DNS:Edit permissions"
        echo
        echo "Option 2: Global API Key (Legacy)"
        echo "  - Go to https://dash.cloudflare.com/profile/api-tokens"
        echo "  - Get Global API Key"
        echo
        
        read -p "Do you have an API Token? (y/n): " has_token
        
        if [[ $has_token =~ ^[Yy]$ ]]; then
            read -s -p "Enter your Cloudflare API Token: " CLOUDFLARE_API_TOKEN
            echo
            export CLOUDFLARE_API_TOKEN
        else
            read -p "Enter your Cloudflare email: " CLOUDFLARE_EMAIL
            read -s -p "Enter your Global API Key: " CLOUDFLARE_API_KEY
            echo
            export CLOUDFLARE_EMAIL
            export CLOUDFLARE_API_KEY
        fi
    fi
    
    success "Cloudflare credentials configured"
}

# Step 3: Test Cloudflare API
test_cloudflare_api() {
    log "Testing Cloudflare API connectivity..."
    
    if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
                       -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                       -H "Content-Type: application/json")
    else
        response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
                       -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                       -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                       -H "Content-Type: application/json")
    fi
    
    if echo "$response" | grep -q '"success":true'; then
        success "Cloudflare API connection successful"
        
        # Extract and display domains
        domains=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$domains" ]; then
            echo "Available domains:"
            echo "$domains" | while read -r domain; do
                echo "  - $domain"
            done
            
            # Save first domain for testing
            FIRST_DOMAIN=$(echo "$domains" | head -n1)
            export FIRST_DOMAIN
        fi
    else
        error "Cloudflare API connection failed"
        echo "Response: $response"
        exit 1
    fi
}

# Step 4: Deploy AWX
deploy_awx() {
    log "Deploying AWX..."
    
    if kubectl get namespace awx &> /dev/null; then
        warning "AWX namespace already exists, skipping deployment"
    else
        log "Running Ansible playbook to deploy AWX..."
        ansible-playbook playbooks/main.yml -e deploy_awx=true
        
        log "Waiting for AWX to be ready..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=awx -n awx --timeout=900s
    fi
    
    success "AWX deployment completed"
}

# Step 5: Get AWX access details
get_awx_details() {
    log "Getting AWX access details..."
    
    # Get admin password
    AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx 2>/dev/null | base64 --decode)
    
    if [ -z "$AWX_PASSWORD" ]; then
        error "Could not retrieve AWX admin password"
        exit 1
    fi
    
    # Get service details
    AWX_NODEPORT=$(kubectl get svc -n awx -o jsonpath='{.items[0].spec.ports[0].nodePort}' 2>/dev/null)
    
    if [ -z "$AWX_NODEPORT" ]; then
        error "Could not retrieve AWX NodePort"
        exit 1
    fi
    
    export AWX_PASSWORD
    export AWX_NODEPORT
    
    success "AWX credentials retrieved"
    echo "  URL: http://<your-node-ip>:$AWX_NODEPORT"
    echo "  Username: admin"
    echo "  Password: $AWX_PASSWORD"
}

# Step 6: Test direct Cloudflare chart deployment
test_cloudflare_chart() {
    log "Testing Cloudflare chart deployment..."
    
    if [ -z "$FIRST_DOMAIN" ]; then
        error "No domain available for testing"
        return 1
    fi
    
    # Create test values
    cat > /tmp/test-cloudflare-values.yaml << EOF
cloudflare:
  apiToken: "${CLOUDFLARE_API_TOKEN}"
  email: "${CLOUDFLARE_EMAIL}"
  globalApiKey: "${CLOUDFLARE_API_KEY}"
  domain: "${FIRST_DOMAIN}"
  dnsRecords:
    - name: "awx-test"
      type: "TXT"
      value: "AWX integration test - $(date)"
      ttl: 300
      proxied: false

job:
  name: "cloudflare-test-job"
  ttlSecondsAfterFinished: 300
EOF

    # Deploy the chart
    helm upgrade --install cloudflare-test ./helm-charts/charts/cloudflare \
        -f /tmp/test-cloudflare-values.yaml \
        -n dns-automation --create-namespace
    
    # Wait for job completion
    log "Waiting for job to complete..."
    sleep 10
    
    # Check job status
    job_status=$(kubectl get job cloudflare-test-job -n dns-automation -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "NotFound")
    
    if [ "$job_status" = "Complete" ]; then
        success "Cloudflare DNS job completed successfully"
        
        # Show job logs
        log "Job output:"
        kubectl logs job/cloudflare-test-job -n dns-automation
        
        # Verify DNS record
        log "Verifying DNS record creation..."
        sleep 5
        if dig +short awx-test.$FIRST_DOMAIN TXT | grep -q "AWX integration test"; then
            success "DNS record verified successfully"
        else
            warning "DNS record not yet propagated (this is normal, try again in a few minutes)"
        fi
        
    else
        error "Cloudflare DNS job failed"
        kubectl logs job/cloudflare-test-job -n dns-automation 2>/dev/null || echo "No logs available"
    fi
    
    # Cleanup
    rm -f /tmp/test-cloudflare-values.yaml
}

# Step 7: Manual AWX configuration instructions
show_awx_configuration() {
    log "AWX Manual Configuration Instructions:"
    echo
    echo "1. Access AWX at: http://<your-node-ip>:$AWX_NODEPORT"
    echo "   Username: admin"
    echo "   Password: $AWX_PASSWORD"
    echo
    echo "2. Create Cloudflare credentials:"
    echo "   - Go to Resources → Credentials"
    echo "   - Click '+' to add new"
    echo "   - Name: 'Cloudflare API Credentials'"
    echo "   - Type: 'Cloudflare API' (if available) or create custom"
    if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        echo "   - API Token: $CLOUDFLARE_API_TOKEN"
    else
        echo "   - Email: $CLOUDFLARE_EMAIL"
        echo "   - Global API Key: $CLOUDFLARE_API_KEY"
    fi
    echo
    echo "3. Your available domains:"
    if [ -n "$FIRST_DOMAIN" ]; then
        echo "   - $FIRST_DOMAIN"
    fi
    echo
    echo "4. Test the integration by creating a DNS record for:"
    echo "   - Domain: $FIRST_DOMAIN"
    echo "   - Name: awx-manual-test"
    echo "   - Type: A"
    echo "   - Value: 192.168.1.100"
    echo
}

# Main execution
main() {
    echo "🚀 Cloudflare + AWX Integration Test"
    echo "==================================="
    echo
    
    check_prerequisites
    setup_cloudflare_credentials
    test_cloudflare_api
    
    echo
    read -p "Deploy AWX? (y/n): " deploy_awx_choice
    if [[ $deploy_awx_choice =~ ^[Yy]$ ]]; then
        deploy_awx
        get_awx_details
    fi
    
    echo
    read -p "Test Cloudflare chart deployment? (y/n): " test_chart_choice
    if [[ $test_chart_choice =~ ^[Yy]$ ]]; then
        test_cloudflare_chart
    fi
    
    echo
    show_awx_configuration
    
    echo
    success "Integration test completed!"
    echo
    echo "Next steps:"
    echo "1. Access AWX web interface and configure credentials"
    echo "2. Import job templates from helm-charts/charts/awx/config/"
    echo "3. Customize domain lists in surveys"
    echo "4. Test DNS operations through AWX interface"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi