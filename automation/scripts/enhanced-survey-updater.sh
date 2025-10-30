#!/usr/bin/env bash

#===============================================================================
# Enhanced AWX Survey Dropdown Auto-Updater for Cloudflare
#===============================================================================
# This script dynamically updates AWX job template survey dropdowns with:
# 1. All Cloudflare domains in the account
# 2. All DNS records for each domain
# 
# It can be run:
# - Manually when you want to refresh dropdowns
# - As part of the AWX job template execution (update_survey_dropdowns action)
# - Via scheduled job for automatic updates
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWX_HOST="${AWX_HOST:-localhost:8052}"
AWX_TEMPLATE_ID="${AWX_TEMPLATE_ID:-21}"  # Cloudflare Automation template

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Enhanced AWX Survey Dropdown Auto-Updater              ║"
echo "╚════════════════════════════════════════════════════════════════╝"

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
# Get AWX Credentials
#===============================================================================

get_awx_password() {
    if command -v kubectl &> /dev/null; then
        kubectl get secret ansible-awx-admin-password \
            -n awx \
            -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode || error_exit "Failed to get AWX password"
    else
        error_exit "kubectl not found. Cannot retrieve AWX credentials"
    fi
}

#===============================================================================
# Get Cloudflare Token
#===============================================================================

get_cloudflare_token() {
    # Try multiple methods to get the Cloudflare token
    
    # Method 1: Environment variable (for manual runs)
    if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        echo "$CLOUDFLARE_API_TOKEN"
        return 0
    fi
    
    # Method 2: AWX credential store (if available)
    if command -v kubectl &> /dev/null; then
        local token
        token=$(kubectl get secret cloudflare-api-token -n awx -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi
    
    # Method 3: Fallback - use placeholder
    warn "Cloudflare API token not found. Survey will use static domain list."
    echo ""
    return 1
}

#===============================================================================
# Cloudflare API Functions
#===============================================================================

fetch_cloudflare_domains() {
    local token
    if ! token=$(get_cloudflare_token); then
        # Return static domain list as fallback
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    info "Fetching live Cloudflare domains..." >&2
    
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json")
    
    if [[ -z "$response" ]]; then
        warn "Empty response from Cloudflare API" >&2
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    # Check if response is successful
    local success
    success=$(echo "$response" | jq -r '.success // false' 2>/dev/null || echo "false")
    
    if [[ "$success" != "true" ]]; then
        warn "Cloudflare API error: $(echo "$response" | jq -r '.errors[]?.message // "Unknown error"' 2>/dev/null || echo "Invalid response")" >&2
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    # Extract domain names
    local domains
    domains=$(echo "$response" | jq -r '.result[]?.name // empty' 2>/dev/null | sort -u | head -20)
    
    if [[ -z "$domains" ]]; then
        warn "No domains found in Cloudflare account" >&2
        echo '["[MANUAL_ENTRY]"]'
        return 0
    fi
    
    # Convert to JSON array and add manual entry option
    echo "$domains" | jq -R -s 'split("\n") | map(select(length > 0)) + ["[MANUAL_ENTRY]"]'
}

fetch_all_dns_records() {
    local token
    if ! token=$(get_cloudflare_token); then
        # Return static record list as fallback
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
        return 0
    fi
    
    info "Fetching DNS records from all domains..." >&2
    
    # First get all zone IDs
    local zones_response
    zones_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json")
    
    local zone_ids
    zone_ids=$(echo "$zones_response" | jq -r '.result[]?.id // empty' 2>/dev/null)
    
    if [[ -z "$zone_ids" ]]; then
        warn "No zones found" >&2
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
        return 0
    fi
    
    # Collect all record names from all zones
    local all_records=()
    
    while IFS= read -r zone_id; do
        if [[ -n "$zone_id" ]]; then
            local records_response
            records_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json")
            
            local records
            records=$(echo "$records_response" | jq -r '.result[]?.name // empty' 2>/dev/null | sed 's/\.[^.]*\.[^.]*$//' | sort -u)
            
            while IFS= read -r record; do
                if [[ -n "$record" && "$record" != "@" ]]; then
                    all_records+=("$record")
                fi
            done <<< "$records"
        fi
    done <<< "$zone_ids"
    
    # Remove duplicates and create JSON array
    if [[ ${#all_records[@]} -eq 0 ]]; then
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
    else
        printf '%s\n' "${all_records[@]}" | sort -u | head -50 | jq -R -s 'split("\n") | map(select(length > 0)) + ["[NONE]", "[REFRESH_NEEDED]"]'
    fi
}

#===============================================================================
# AWX Survey Update Functions
#===============================================================================

update_survey_dropdowns() {
    info "Getting AWX credentials..."
    local awx_password
    awx_password=$(get_awx_password)
    
    info "Fetching current survey configuration..."
    local current_survey
    current_survey=$(curl -s http://$AWX_HOST/api/v2/job_templates/$AWX_TEMPLATE_ID/survey_spec/ \
        -u "admin:$awx_password")
    
    if [[ -z "$current_survey" ]]; then
        error_exit "Failed to fetch current survey"
    fi
    
    info "Fetching updated domain list..."
    local domain_choices
    domain_choices=$(fetch_cloudflare_domains)
    
    info "Fetching updated DNS records list..."
    local record_choices
    record_choices=$(fetch_all_dns_records)
    
    info "Updating survey with new dropdown values..."
    
    # Save current survey and update it
    echo "$current_survey" > /tmp/current_survey_backup.json
    
    # Update the survey using jq - separate operations for clarity
    local updated_survey
    updated_survey=$(echo "$current_survey" | jq --argjson domains "$domain_choices" '
        .spec |= map(
            if .variable == "existing_domain" then 
                .choices = $domains
            else 
                .
            end
        )
    ')
    
    updated_survey=$(echo "$updated_survey" | jq --argjson records "$record_choices" '
        .spec |= map(
            if .variable == "existing_record" then 
                .choices = $records
            else 
                .
            end
        )
    ')
    
    # Save the updated survey to file
    echo "$updated_survey" > /tmp/updated_survey_final.json
    
    info "Applying updated survey to AWX..."
    local update_response
    update_response=$(curl -s -X POST http://$AWX_HOST/api/v2/job_templates/$AWX_TEMPLATE_ID/survey_spec/ \
        -H "Content-Type: application/json" \
        -u "admin:$awx_password" \
        -d @/tmp/updated_survey_final.json)
    
    if echo "$update_response" | jq -e '.spec' >/dev/null 2>&1; then
        success "Survey dropdowns updated successfully!"
        
        local domain_count record_count
        domain_count=$(echo "$domain_choices" | jq '. | length')
        record_count=$(echo "$record_choices" | jq '. | length')
        
        echo ""
        echo "📊 Updated Statistics:"
        echo "   • Domains: $domain_count options"
        echo "   • Records: $record_count options"
        echo "   • Last updated: $(date)"
        
    else
        echo "Update response: $update_response" >&2
        error_exit "Failed to update survey"
    fi
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    echo "🚀 Starting survey dropdown update process..."
    echo ""
    
    update_survey_dropdowns
    
    echo ""
    success "Survey dropdown update completed successfully!"
    echo ""
    echo "📝 Next steps:"
    echo "   • Go to AWX UI → Templates → Cloudflare Template"
    echo "   • Verify the dropdowns are populated with current data"
    echo "   • Run this script periodically to keep dropdowns fresh"
}

# Execute main function
main "$@"