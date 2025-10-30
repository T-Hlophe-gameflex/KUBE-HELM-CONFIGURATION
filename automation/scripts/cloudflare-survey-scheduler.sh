#!/usr/bin/env bash

#===============================================================================
# AWX Cloudflare Survey Auto-Updater (Scheduled Job)
#===============================================================================
# 
# This script updates AWX job template survey dropdowns with live Cloudflare data.
# Designed to run as a scheduled job after Cloudflare template executions.
#
# Usage:
#   - Run manually: ./cloudflare-survey-scheduler.sh
#   - Run via cron: Add to crontab for automatic updates
#   - Run via AWX: Create separate job template for this script
#
# Requirements:
#   - kubectl access to AWX namespace
#   - CLOUDFLARE_API_TOKEN environment variable
#   - AWX admin access
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly AWX_HOST="${AWX_HOST:-localhost:8052}"
readonly AWX_TEMPLATE_ID="${AWX_TEMPLATE_ID:-21}"
readonly LOG_FILE="/tmp/cloudflare-survey-update.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#===============================================================================
# Logging Functions
#===============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO" "$1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS" "$1"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARN" "$1"
}

error() {
    echo -e "${RED}❌ $1${NC}" >&2
    log "ERROR" "$1"
}

error_exit() {
    error "$1"
    exit 1
}

#===============================================================================
# Prerequisites Check
#===============================================================================

check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error_exit "kubectl is required but not installed"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        error_exit "curl is required but not installed"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required but not installed"
    fi
    
    # Check AWX access
    if ! kubectl get pods -n awx &> /dev/null; then
        error_exit "Cannot access AWX namespace. Check kubectl configuration"
    fi
    
    success "Prerequisites check passed"
}

#===============================================================================
# AWX Functions
#===============================================================================

get_awx_password() {
    info "Retrieving AWX admin password..."
    if ! kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode; then
        error_exit "Failed to retrieve AWX admin password"
    fi
}

get_current_survey() {
    local awx_password="$1"
    info "Fetching current survey configuration..."
    
    local response
    response=$(curl -s "http://$AWX_HOST/api/v2/job_templates/$AWX_TEMPLATE_ID/survey_spec/" \
        -u "admin:$awx_password" 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        error_exit "Empty response from AWX API"
    fi
    
    # Test if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        error_exit "Invalid JSON response from AWX API: $(echo "$response" | head -1)"
    fi
    
    # Test if it has the expected structure
    if ! echo "$response" | jq -e '.spec' >/dev/null 2>&1; then
        error_exit "Response missing 'spec' field: $(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "Invalid structure")"
    fi
    
    echo "$response"
}

#===============================================================================
# Cloudflare API Functions
#===============================================================================

get_cloudflare_token() {
    # Try environment variable first
    if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        echo "$CLOUDFLARE_API_TOKEN"
        return 0
    fi
    
    # Try kubectl secret
    local token
    if token=$(kubectl get secret cloudflare-api-token -n awx -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null); then
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi
    
    warn "Cloudflare API token not found. Using fallback domain list."
    return 1
}

fetch_cloudflare_domains() {
    local token
    if ! token=$(get_cloudflare_token); then
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    info "Fetching live Cloudflare domains..."
    
    local response
    response=$(curl -s "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [[ -z "$response" ]] || ! echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        warn "Cloudflare API request failed. Using fallback domain list."
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    local success
    success=$(echo "$response" | jq -r '.success // false')
    
    if [[ "$success" != "true" ]]; then
        warn "Cloudflare API returned error. Using fallback domain list."
        echo '["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
        return 0
    fi
    
    # Extract and format domains
    local domains
    domains=$(echo "$response" | jq -r '.result[]?.name // empty' | sort -u | head -20)
    
    if [[ -z "$domains" ]]; then
        echo '["[MANUAL_ENTRY]"]'
    else
        echo "$domains" | jq -R -s 'split("\n") | map(select(length > 0)) + ["[MANUAL_ENTRY]"]'
    fi
}

fetch_cloudflare_records() {
    local token
    if ! token=$(get_cloudflare_token); then
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
        return 0
    fi
    
    info "Fetching DNS records from all domains..."
    
    # Get all zone IDs
    local zones_response
    zones_response=$(curl -s "https://api.cloudflare.com/client/v4/zones" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [[ -z "$zones_response" ]] || ! echo "$zones_response" | jq -e '.success' >/dev/null 2>&1; then
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
        return 0
    fi
    
    local zone_ids
    zone_ids=$(echo "$zones_response" | jq -r '.result[]?.id // empty')
    
    if [[ -z "$zone_ids" ]]; then
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
        return 0
    fi
    
    # Collect all record names
    local all_records=()
    
    while IFS= read -r zone_id; do
        if [[ -n "$zone_id" ]]; then
            local records_response
            records_response=$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                -H "Authorization: Bearer $token" \
                -H "Content-Type: application/json" 2>/dev/null)
            
            if echo "$records_response" | jq -e '.success' >/dev/null 2>&1; then
                local records
                records=$(echo "$records_response" | jq -r '.result[]?.name // empty' | \
                         sed 's/\.[^.]*\.[^.]*$//' | grep -v '^@$' | sort -u)
                
                while IFS= read -r record; do
                    if [[ -n "$record" ]]; then
                        all_records+=("$record")
                    fi
                done <<< "$records"
            fi
        fi
    done <<< "$zone_ids"
    
    # Create JSON array
    if [[ ${#all_records[@]} -eq 0 ]]; then
        echo '["[NONE]", "[REFRESH_NEEDED]"]'
    else
        printf '%s\n' "${all_records[@]}" | sort -u | head -50 | \
        jq -R -s 'split("\n") | map(select(length > 0)) + ["[NONE]", "[REFRESH_NEEDED]"]'
    fi
}

#===============================================================================
# Survey Update Functions
#===============================================================================

update_survey() {
    local awx_password="$1"
    local domain_choices="$2"
    local record_choices="$3"
    
    info "Updating AWX survey with new dropdown values..."
    
    # Validate JSON inputs
    if ! echo "$domain_choices" | jq empty 2>/dev/null; then
        error_exit "Invalid domain_choices JSON"
    fi
    
    if ! echo "$record_choices" | jq empty 2>/dev/null; then
        error_exit "Invalid record_choices JSON"
    fi
    
    # Get current survey
    local current_survey
    current_survey=$(get_current_survey "$awx_password")
    
    # Update survey with new choices
    local updated_survey
    updated_survey=$(echo "$current_survey" | jq \
        --argjson domains "$domain_choices" \
        --argjson records "$record_choices" \
        '.spec |= map(
            if .variable == "existing_domain" then 
                .choices = $domains
            elif .variable == "existing_record" then 
                .choices = $records
            else 
                .
            end
        )')
    
    # Validate the updated survey
    if ! echo "$updated_survey" | jq empty 2>/dev/null; then
        error_exit "Failed to generate valid updated survey JSON"
    fi
    
    # Apply updated survey
    local response
    response=$(curl -s -X POST "http://$AWX_HOST/api/v2/job_templates/$AWX_TEMPLATE_ID/survey_spec/" \
        -H "Content-Type: application/json" \
        -u "admin:$awx_password" \
        -d "$updated_survey" 2>/dev/null)
    
    # Check response
    if [[ -z "$response" ]]; then
        error "Empty response from AWX update API"
        return 1
    fi
    
    if echo "$response" | jq -e '.spec' >/dev/null 2>&1; then
        success "Survey updated successfully!"
        
        local domain_count record_count
        domain_count=$(echo "$domain_choices" | jq '. | length')
        record_count=$(echo "$record_choices" | jq '. | length')
        
        info "Updated statistics:"
        info "  • Domains: $domain_count options"
        info "  • Records: $record_count options"
        info "  • Last updated: $(date)"
        
        return 0
    else
        error "Survey update failed - API response: $(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "Invalid response")"
        return 1
    fi
}

#===============================================================================
# Main Execution
#===============================================================================

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          AWX Cloudflare Survey Auto-Updater (Scheduled)       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    info "Started: $(date)"
    info "Script: $SCRIPT_NAME"
    info "AWX Host: $AWX_HOST"
    info "Template ID: $AWX_TEMPLATE_ID"
    info "Log file: $LOG_FILE"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWX credentials
    local awx_password
    awx_password=$(get_awx_password)
    
    # Fetch updated data
    info "Fetching updated Cloudflare data..."
    local domain_choices record_choices
    domain_choices=$(fetch_cloudflare_domains)
    record_choices=$(fetch_cloudflare_records)
    
    # Update survey
    if update_survey "$awx_password" "$domain_choices" "$record_choices"; then
        success "Survey update completed successfully!"
        echo ""
        echo "📝 Next steps:"
        echo "   • AWX survey dropdowns are now current"
        echo "   • Users can select from live Cloudflare data"
        echo "   • This script can be scheduled to run periodically"
        
        log "SUCCESS" "Survey update completed - Domains: $(echo "$domain_choices" | jq '. | length'), Records: $(echo "$record_choices" | jq '. | length')"
        
        exit 0
    else
        error_exit "Survey update failed"
    fi
}

# Execute main function
main "$@"