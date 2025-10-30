#!/usr/bin/env bash

#===============================================================================
# AWX Survey Auto-Updater Schedule Setup
#===============================================================================
# This script sets up AWX schedules for automatic survey dropdown updates
#===============================================================================

set -euo pipefail

# Configuration
readonly AWX_HOST="${AWX_HOST:-localhost:8052}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         AWX Survey Auto-Updater Schedule Setup                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

info "Setting up AWX schedules for automatic survey updates..."
echo ""

# Get AWX admin password
info "Retrieving AWX admin password..."
AWX_ADMIN_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 --decode)

if [[ -z "$AWX_ADMIN_PASSWORD" ]]; then
    echo "❌ Failed to retrieve AWX admin password"
    exit 1
fi

success "AWX credentials retrieved"

# Install awx.awx collection if needed
info "Checking AWX collection availability..."
if ! ansible-galaxy collection list | grep -q "awx.awx"; then
    info "Installing awx.awx collection..."
    ansible-galaxy collection install awx.awx
    success "AWX collection installed"
else
    success "AWX collection already available"
fi

# Run the schedule setup playbook
info "Executing schedule setup playbook..."
cd "$PROJECT_ROOT"

ansible-playbook automation/playbooks/cloudflare/setup-survey-schedules.yml \
    -e "awx_admin_password=$AWX_ADMIN_PASSWORD" \
    -e "controller_host=$AWX_HOST" \
    -v

if [[ $? -eq 0 ]]; then
    echo ""
    success "AWX schedules configured successfully!"
    echo ""
    echo "📋 What was created:"
    echo "   • Job Template: 'Cloudflare Survey Auto-Updater'"
    echo "   • Schedule: 'Survey Auto-Update - Hourly' (business hours)"
    echo "   • Schedule: 'Survey Auto-Update - After Main Job' (manual)"
    echo "   • Schedule: 'Survey Auto-Update - Weekly Refresh'"
    echo "   • Workflow: 'Cloudflare DNS + Survey Update Workflow'"
    echo ""
    echo "🔧 Next steps:"
    echo "   1. Go to AWX UI → Templates → Schedules"
    echo "   2. Verify schedules are enabled as desired"
    echo "   3. Test manual execution of survey updater template"
    echo "   4. Monitor schedule execution logs"
    echo ""
    echo "💡 Tips:"
    echo "   • Hourly updates during business hours keep dropdowns fresh"
    echo "   • Weekly refresh ensures comprehensive data updates"
    echo "   • Use workflow template for combined DNS + survey operations"
    echo "   • Disable schedules if not needed to reduce API usage"
else
    echo ""
    echo "❌ Schedule setup failed. Check the output above for details."
    exit 1
fi