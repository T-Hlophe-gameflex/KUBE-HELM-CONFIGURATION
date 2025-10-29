#!/usr/bin/env bash

#===============================================================================
# AWX Survey Dropdown Auto-Updater
#===============================================================================
# This script dynamically updates AWX job template survey dropdowns with:
# 1. All Cloudflare domains in the account
# 2. All DNS records for each domain
# 
# Run this script:
# - Manually when you want to refresh dropdowns
# - As a post-task in AWX workflows (after create_domain/create_record)
# - Via cron job for periodic updates
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWX_HOST="${AWX_HOST:-localhost:8052}"
AWX_PROJECT_ID="${AWX_PROJECT_ID:-8}"
AWX_JOB_TEMPLATE_ID="${AWX_JOB_TEMPLATE_ID:-21}"  # Cloudflare Automation template
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

# Check if running in AWX or local
if [[ -f /var/lib/awx/.kube/config ]]; then
    echo -e "${BLUE}📍 Running inside AWX container${NC}"
    AWX_MODE="container"
else
    echo -e "${BLUE}📍 Running locally${NC}"
    AWX_MODE="local"
fi

#===============================================================================
# Helper Functions
#===============================================================================

error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

#===============================================================================
# AWX Authentication
#===============================================================================

get_awx_token() {
    if [[ "$AWX_MODE" == "container" ]]; then
        # Inside AWX container, use service account or env var
        if [[ -n "${AWX_TOKEN:-}" ]]; then
            echo "$AWX_TOKEN"
        else
            error_exit "AWX_TOKEN not set in container environment"
        fi
    else
        # Local mode - get password from K8s secret
        if command -v kubectl &> /dev/null; then
            kubectl get secret ansible-awx-admin-password \
                -n awx \
                -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode || error_exit "Failed to get AWX password"
        else
            error_exit "kubectl not found. Please set AWX_TOKEN environment variable"
        fi
    fi
}

#===============================================================================
# Cloudflare API Functions
#===============================================================================

fetch_cloudflare_domains() {
    info "Fetching Cloudflare domains..." >&2
    
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        error_exit "CLOUDFLARE_API_TOKEN environment variable not set"
    fi
    
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        error_exit "Failed to fetch Cloudflare zones: $(echo "$response" | jq -r '.errors[0].message // "Unknown error"')"
    fi
    
    # Extract domain names and return as JSON array
    echo "$response" | jq -r '[.result[] | .name] | sort'
}

fetch_cloudflare_records() {
    local zone_id="$1"
    local zone_name="$2"
    
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        warn "Failed to fetch records for zone $zone_id"
        echo "[]"
        return
    fi
    
    # Extract record names and strip domain suffix to get only subdomain/record name
    # Example: "www.example.com" with zone "example.com" → "www"
    # Example: "example.com" (apex) → "@" (root)
    echo "$response" | jq -r --arg zone "$zone_name" '
        [.result[] | 
            if .name == $zone then "@"
            else .name | sub("\\." + ($zone | @text) + "$"; "")
            end
        ] | sort | unique'
}

fetch_all_records_from_all_zones() {
    info "Fetching all DNS records from all zones..." >&2
    
    local zones_data
    zones_data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[] | "\(.id)|\(.name)"')
    
    local all_records="[]"
    
    while IFS='|' read -r zone_id zone_name; do
        [ -z "$zone_id" ] && continue
        local records
        records=$(fetch_cloudflare_records "$zone_id" "$zone_name")
        all_records=$(echo "$all_records" | jq --argjson new "$records" '. + $new | sort | unique')
    done <<< "$zones_data"
    
    echo "$all_records"
}

#===============================================================================
# AWX API Functions
#===============================================================================

update_awx_survey() {
    local job_template_id="$1"
    local field_name="$2"
    local choices="$3"  # JSON array
    
    info "Updating AWX survey field: $field_name" >&2
    
    # Get current survey spec
    local awx_password
    awx_password=$(get_awx_token)
    
    local survey_spec
    survey_spec=$(curl -s -X GET "http://${AWX_HOST}/api/v2/job_templates/${job_template_id}/survey_spec/" \
        -u "admin:${awx_password}" \
        -H "Content-Type: application/json")
    
    if [[ -z "$survey_spec" ]] || ! echo "$survey_spec" | jq -e '.' > /dev/null 2>&1; then
        error_exit "Failed to fetch survey spec from AWX"
    fi
    
    # Check if survey has the field
    if ! echo "$survey_spec" | jq -e ".spec[] | select(.variable == \"$field_name\")" > /dev/null 2>&1; then
        warn "Field $field_name not found in survey, skipping"
        return
    fi
    
    # Update the choices for the specific field
    local updated_survey
    updated_survey=$(echo "$survey_spec" | jq \
        --arg field "$field_name" \
        --argjson choices "$choices" \
        '.spec |= map(if .variable == $field then .choices = $choices else . end)')
    
    # POST the updated survey back
    local http_code
    http_code=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://${AWX_HOST}/api/v2/job_templates/${job_template_id}/survey_spec/" \
        -u "admin:${awx_password}" \
        -H "Content-Type: application/json" \
        -d "$updated_survey")
    
    if [[ "$http_code" == "200" ]]; then
        success "Updated $field_name with $(echo "$choices" | jq -r 'length') choices"
    else
        error_exit "Failed to update survey: HTTP $http_code"
    fi
}

#===============================================================================
# Main Logic
#===============================================================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       AWX Survey Dropdown Auto-Updater for Cloudflare         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Fetch Cloudflare domains
    local domains
    domains=$(fetch_cloudflare_domains)
    local domain_count
    domain_count=$(echo "$domains" | jq -r 'length')
    
    success "Fetched $domain_count domains from Cloudflare"
    echo "$domains" | jq -r '.[]' | sed 's/^/  - /'
    echo ""
    
    # Fetch all DNS records
    local records
    records=$(fetch_all_records_from_all_zones)
    local record_count
    record_count=$(echo "$records" | jq -r 'length')
    
    success "Fetched $record_count unique DNS records from all zones"
    if [[ $record_count -gt 10 ]]; then
        echo "  (showing first 10)"
        echo "$records" | jq -r '.[:10][]' | sed 's/^/  - /'
    else
        echo "$records" | jq -r '.[]' | sed 's/^/  - /'
    fi
    echo ""
    
    # Update AWX survey dropdowns
    info "Updating AWX Job Template #${AWX_JOB_TEMPLATE_ID} survey..."
    
    # Add [MANUAL_ENTRY] option to domains
    local domains_with_manual
    domains_with_manual=$(echo "$domains" | jq '. + ["[MANUAL_ENTRY]"]')
    
    # Add [NONE] option to records
    local records_with_none
    records_with_none=$(echo "$records" | jq '["[NONE]"] + .')
    
    # Update existing_domain dropdown
    update_awx_survey "$AWX_JOB_TEMPLATE_ID" "existing_domain" "$domains_with_manual"
    
    # Update existing_record dropdown
    update_awx_survey "$AWX_JOB_TEMPLATE_ID" "existing_record" "$records_with_none"
    
    echo ""
    success "Survey dropdowns updated successfully!"
    echo ""
    echo "📝 Updated fields:"
    echo "  - domain: $domain_count choices"
    echo "  - existing_record_name: $record_count choices"
    echo ""
    echo "🎯 Next steps:"
    echo "  1. Go to AWX UI → Templates → Cloudflare Automation"
    echo "  2. Click 'Survey' tab to verify updated dropdowns"
    echo "  3. Launch the template and select from updated domains/records"
}

# Run main function
main "$@"
