#!/usr/bin/env bash

#===============================================================================
# Manual AWX Schedule Creation via API
#===============================================================================
# Creates schedules directly via AWX API for survey auto-updater
#===============================================================================

set -euo pipefail

# Configuration
readonly AWX_HOST="${AWX_HOST:-localhost:8052}"
readonly TEMPLATE_NAME="Cloudflare Survey Auto-Updater"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Manual AWX Schedule Creation                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get AWX credentials
info "Getting AWX admin password..."
AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 --decode)

if [[ -z "$AWX_PASSWORD" ]]; then
    error "Failed to get AWX password"
    exit 1
fi

# Create survey updater job template
info "Creating Survey Updater Job Template..."

# Check if template exists
TEMPLATE_ID=$(curl -s "http://$AWX_HOST/api/v2/job_templates/" \
    -u "admin:$AWX_PASSWORD" | jq -r ".results[] | select(.name==\"$TEMPLATE_NAME\") | .id" 2>/dev/null || echo "")

if [[ -n "$TEMPLATE_ID" ]]; then
    success "Template already exists (ID: $TEMPLATE_ID)"
else
    # Get required IDs
    PROJECT_ID=$(curl -s "http://$AWX_HOST/api/v2/projects/" -u "admin:$AWX_PASSWORD" | jq -r '.results[0].id')
    INVENTORY_ID=$(curl -s "http://$AWX_HOST/api/v2/inventories/" -u "admin:$AWX_PASSWORD" | jq -r '.results[0].id')
    CREDENTIAL_ID=$(curl -s "http://$AWX_HOST/api/v2/credentials/" -u "admin:$AWX_PASSWORD" | jq -r '.results[0].id')

    # Create template
    TEMPLATE_RESPONSE=$(curl -s -X POST "http://$AWX_HOST/api/v2/job_templates/" \
        -u "admin:$AWX_PASSWORD" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$TEMPLATE_NAME\",
            \"description\": \"Automated survey dropdown updater for Cloudflare templates\",
            \"job_type\": \"run\",
            \"inventory\": $INVENTORY_ID,
            \"project\": $PROJECT_ID,
            \"playbook\": \"automation/playbooks/cloudflare/scheduled-survey-updater.yml\",
            \"verbosity\": 1,
            \"timeout\": 300,
            \"extra_vars\": \"{\\\"awx_host\\\": \\\"$AWX_HOST\\\", \\\"template_id\\\": \\\"21\\\"}\"
        }")

    TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | jq -r '.id // empty')
    
    if [[ -n "$TEMPLATE_ID" ]]; then
        success "Created Survey Updater Template (ID: $TEMPLATE_ID)"
        
        # Add credential to template
        curl -s -X POST "http://$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/credentials/" \
            -u "admin:$AWX_PASSWORD" \
            -H "Content-Type: application/json" \
            -d "{\"id\": $CREDENTIAL_ID}" >/dev/null
    else
        error "Failed to create template: $(echo "$TEMPLATE_RESPONSE" | jq -r '.detail // "Unknown error"')"
        exit 1
    fi
fi

# Create schedules
info "Creating schedules..."

# Schedule 1: Hourly during business hours
info "Creating hourly business hours schedule..."
HOURLY_RESPONSE=$(curl -s -X POST "http://$AWX_HOST/api/v2/schedules/" \
    -u "admin:$AWX_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"Survey Auto-Update - Hourly Business\",
        \"description\": \"Updates survey dropdowns every hour during business hours\",
        \"enabled\": true,
        \"rrule\": \"DTSTART:20251030T080000Z RRULE:FREQ=HOURLY;BYHOUR=8,9,10,11,12,13,14,15,16,17;BYDAY=MO,TU,WE,TH,FR\",
        \"unified_job_template\": $TEMPLATE_ID
    }")

HOURLY_ID=$(echo "$HOURLY_RESPONSE" | jq -r '.id // empty')
if [[ -n "$HOURLY_ID" ]]; then
    success "Created hourly schedule (ID: $HOURLY_ID)"
else
    warn "Hourly schedule creation failed: $(echo "$HOURLY_RESPONSE" | jq -r '.name[0] // .detail // "Unknown error"')"
fi

# Schedule 2: Daily at 6 PM
info "Creating daily evening schedule..."
DAILY_RESPONSE=$(curl -s -X POST "http://$AWX_HOST/api/v2/schedules/" \
    -u "admin:$AWX_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"Survey Auto-Update - Daily Evening\",
        \"description\": \"Updates survey dropdowns daily at 6 PM\",
        \"enabled\": true,
        \"rrule\": \"DTSTART:20251030T180000Z RRULE:FREQ=DAILY;INTERVAL=1\",
        \"unified_job_template\": $TEMPLATE_ID
    }")

DAILY_ID=$(echo "$DAILY_RESPONSE" | jq -r '.id // empty')
if [[ -n "$DAILY_ID" ]]; then
    success "Created daily schedule (ID: $DAILY_ID)"
else
    warn "Daily schedule creation failed: $(echo "$DAILY_RESPONSE" | jq -r '.name[0] // .detail // "Unknown error"')"
fi

# Schedule 3: Weekly comprehensive refresh
info "Creating weekly refresh schedule..."
WEEKLY_RESPONSE=$(curl -s -X POST "http://$AWX_HOST/api/v2/schedules/" \
    -u "admin:$AWX_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{
        \"name\": \"Survey Auto-Update - Weekly Refresh\",
        \"description\": \"Weekly comprehensive refresh every Monday at 6 AM\",
        \"enabled\": true,
        \"rrule\": \"DTSTART:20251030T060000Z RRULE:FREQ=WEEKLY;BYDAY=MO\",
        \"unified_job_template\": $TEMPLATE_ID
    }")

WEEKLY_ID=$(echo "$WEEKLY_RESPONSE" | jq -r '.id // empty')
if [[ -n "$WEEKLY_ID" ]]; then
    success "Created weekly schedule (ID: $WEEKLY_ID)"
else
    warn "Weekly schedule creation failed: $(echo "$WEEKLY_RESPONSE" | jq -r '.name[0] // .detail // "Unknown error"')"
fi

echo ""
success "Schedule setup completed!"
echo ""
echo "📅 Created Schedules:"
echo "   • Hourly Business: Every hour 8 AM-5 PM, Mon-Fri"
echo "   • Daily Evening: Every day at 6 PM"
echo "   • Weekly Refresh: Every Monday at 6 AM"
echo ""
echo "🔧 Management:"
echo "   • Access AWX UI → Templates → Schedules"
echo "   • Template: $TEMPLATE_NAME (ID: $TEMPLATE_ID)"
echo "   • Enable/disable schedules as needed"
echo ""
echo "🎯 Next Steps:"
echo "   1. Test manual execution of the template"
echo "   2. Monitor first scheduled execution"
echo "   3. Adjust schedule frequency if needed"
echo "   4. Check survey dropdowns are updating correctly"