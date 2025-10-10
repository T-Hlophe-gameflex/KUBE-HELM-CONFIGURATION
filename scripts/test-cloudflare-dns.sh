#!/bin/bash
set -euo pipefail

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

echo "☁️  Cloudflare DNS Integration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    log_info "Loading environment variables..."
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
else
    log_error "No .env file found. Please create one with your Cloudflare API token."
    exit 1
fi

# Check if we have required variables
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    log_error "CLOUDFLARE_API_TOKEN not set in .env file"
    exit 1
fi

if [ -z "${FIRST_DOMAIN:-}" ]; then
    log_error "FIRST_DOMAIN not set in .env file"
    exit 1
fi

# Test API access
log_info "Testing Cloudflare API access..."
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
               -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
               -H "Content-Type: application/json")

if echo "$response" | grep -q '"success":true'; then
    log_success "Cloudflare API access verified"
else
    log_error "Cloudflare API access failed"
    echo "Response: $response"
    exit 1
fi

# Check if cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "No Kubernetes cluster found. Please run setup-kind-with-awx.sh first."
    exit 1
fi

log_success "Kubernetes cluster is accessible"

# Deploy Cloudflare test
log_info "Deploying Cloudflare DNS test..."
TEST_RECORD="script-test-$(date +%s)"

helm upgrade --install cloudflare-script-test "$PROJECT_ROOT/helm-charts/charts/cloudflare" \
    --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
    --set cloudflare.domain="$FIRST_DOMAIN" \
    --set cloudflare.dnsRecords[0].name="$TEST_RECORD" \
    --set cloudflare.dnsRecords[0].type="TXT" \
    --set cloudflare.dnsRecords[0].value="Automated test from script - $(date)" \
    --set cloudflare.dnsRecords[0].ttl=300 \
    --set job.ttlSecondsAfterFinished=300 \
    -n dns-automation --create-namespace \
    --wait --timeout=5m

# Check job result
log_info "Checking job results..."
kubectl wait --for=condition=complete job/cloudflare-script-test-job -n dns-automation --timeout=300s

if [ $? -eq 0 ]; then
    log_success "Cloudflare DNS job completed successfully!"
    
    # Show job logs
    echo ""
    echo "📋 Job Output:"
    kubectl logs job/cloudflare-script-test-job -n dns-automation
    
    # Verify DNS record
    log_info "Verifying DNS record creation..."
    sleep 5
    
    dns_result=$(dig +short "${TEST_RECORD}.${FIRST_DOMAIN}" TXT 2>/dev/null | head -1)
    if [ -n "$dns_result" ]; then
        log_success "DNS record verified: $dns_result"
    else
        log_warning "DNS record not yet propagated (this is normal, takes time)"
        log_info "You can verify later with: dig ${TEST_RECORD}.${FIRST_DOMAIN} TXT"
    fi
    
else
    log_error "Cloudflare DNS job failed"
    kubectl describe job/cloudflare-script-test-job -n dns-automation
    exit 1
fi

# Test bulk creation
log_info "Testing bulk DNS record creation..."
BULK_TEST_TIME=$(date +%s)

helm upgrade --install cloudflare-bulk-test "$PROJECT_ROOT/helm-charts/charts/cloudflare" \
    --set cloudflare.apiToken="$CLOUDFLARE_API_TOKEN" \
    --set cloudflare.domain="$FIRST_DOMAIN" \
    --set-json 'cloudflare.dnsRecords=[
        {
            "name": "bulk-test1-'$BULK_TEST_TIME'",
            "type": "TXT",
            "value": "Bulk test record 1",
            "ttl": 300
        },
        {
            "name": "bulk-test2-'$BULK_TEST_TIME'", 
            "type": "TXT",
            "value": "Bulk test record 2",
            "ttl": 300
        }
    ]' \
    -n dns-automation \
    --wait --timeout=5m

kubectl wait --for=condition=complete job/cloudflare-bulk-test-job -n dns-automation --timeout=300s

if [ $? -eq 0 ]; then
    log_success "Bulk DNS creation completed!"
    echo ""
    echo "📋 Bulk Job Output:"
    kubectl logs job/cloudflare-bulk-test-job -n dns-automation
else
    log_warning "Bulk DNS creation had issues"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "🎉 Cloudflare Integration Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Tests Performed:"
echo "   • API connectivity verified"
echo "   • Single DNS record creation"
echo "   • Bulk DNS record creation"
echo "   • Kubernetes job execution"
echo ""
echo "🌐 Domain tested: $FIRST_DOMAIN"
echo "📝 Records created:"
echo "   • ${TEST_RECORD}.${FIRST_DOMAIN}"
echo "   • bulk-test1-${BULK_TEST_TIME}.${FIRST_DOMAIN}"
echo "   • bulk-test2-${BULK_TEST_TIME}.${FIRST_DOMAIN}"
echo ""
echo "🔍 Verify records:"
echo "   dig ${TEST_RECORD}.${FIRST_DOMAIN} TXT"
echo "   dig bulk-test1-${BULK_TEST_TIME}.${FIRST_DOMAIN} TXT"
echo ""
echo "🧹 Cleanup jobs:"
echo "   kubectl delete job -n dns-automation cloudflare-script-test-job"
echo "   kubectl delete job -n dns-automation cloudflare-bulk-test-job"
echo ""