#!/bin/bash
set -euo pipefail

# AWX Survey Management Tool
# Comprehensive script to manage AWX survey configuration, template information, and verification
# Consolidates functionality from apply_survey_improvements.sh, verify_awx_changes.sh, and update_awx_template_description.sh

# Configuration
AWX_HOST="${AWX_HOST:-localhost:8052}"
AWX_TEMPLATE_ID="${AWX_TEMPLATE_ID:-21}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "AWX Survey Management Tool"
    echo "========================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  apply-survey        Apply improved survey configuration to AWX template"
    echo "  verify-changes      Verify that survey changes have been applied"
    echo "  update-template     Update template name and description"
    echo "  show-current        Display current survey configuration"
    echo "  help               Show this help message"
    echo ""
    echo "Options:"
    echo "  --template-id ID   AWX template ID (default: 21)"
    echo "  --host HOST        AWX host (default: localhost:8052)"
    echo ""
    echo "Examples:"
    echo "  $0 apply-survey"
    echo "  $0 verify-changes"
    echo "  $0 update-template"
    echo "  $0 show-current"
}

# Get AWX credentials
get_awx_credentials() {
    if ! AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" 2>/dev/null | base64 -d); then
        echo -e "${RED}Error: Could not get AWX password from Kubernetes secret${NC}"
        echo "Make sure you have kubectl access to the awx namespace"
        exit 1
    fi
}
    
    # Apply survey improvements
apply_survey() {
    echo -e "${BLUE}🚀 Applying AWX Survey Improvements...${NC}"
    echo "====================================="
    
    get_awx_credentials
    
    echo "📋 Getting current survey configuration..."
    CURRENT_SURVEY=$(curl -s -u "admin:${AWX_PASSWORD}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/")
    
    if [[ "$CURRENT_SURVEY" == *'"spec":'* ]]; then
        echo -e "${GREEN}✅ Successfully retrieved current survey${NC}"
    else
        echo -e "${RED}❌ Failed to get current survey configuration${NC}"
        exit 1
    fi
    
    echo "🔧 Creating improved survey configuration..."
    
    # Improved comprehensive survey with all the changes
    NEW_SURVEY='{
      "name": "Comprehensive DNS and Cloudflare Management Survey",
      "description": "Improved survey with cleaner field names and better defaults",
      "spec": [
        {
          "question_name": "Action",
          "question_description": "Select the action to perform",
          "required": true,
          "type": "multiplechoice",
          "variable": "cf_action",
          "choices": [
            "create_record",
            "update_record", 
            "delete_record",
            "clone_record",
            "create_domain",
            "update_settings",
            "sync"
          ],
          "default": "create_record"
        },
        {
          "question_name": "Domain",
          "question_description": "Choose domain from your Cloudflare account",
          "required": true,
          "type": "multiplechoice",
          "variable": "existing_domain",
          "choices": ["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"],
          "default": "efutechnologies.co.za"
        },
        {
          "question_name": "Manual Domain Entry",
          "question_description": "Enter domain name manually if not in dropdown",
          "required": false,
          "type": "text",
          "variable": "manual_domain",
          "default": ""
        },
        {
          "question_name": "Record Name",
          "question_description": "Name of the DNS record to create/update",
          "required": false,
          "type": "text",
          "variable": "record_name",
          "default": ""
        },
        {
          "question_name": "Existing Record",
          "question_description": "Choose existing record (populated dynamically)",
          "required": false,
          "type": "multiplechoice",
          "variable": "existing_record",
          "choices": ["[NONE]", "[REFRESH_NEEDED]"],
          "default": "[NONE]"
        },
        {
          "question_name": "Record Type",
          "question_description": "DNS record type",
          "required": true,
          "type": "multiplechoice",
          "variable": "record_type",
          "choices": ["A", "AAAA", "CNAME", "MX", "TXT", "SRV"],
          "default": "A"
        },
        {
          "question_name": "Record Value",
          "question_description": "Record content (IP, hostname, text value, etc.)",
          "required": false,
          "type": "text",
          "variable": "record_value",
          "default": ""
        },
        {
          "question_name": "TTL",
          "question_description": "Time to live in seconds",
          "required": false,
          "type": "multiplechoice",
          "variable": "record_ttl",
          "choices": ["auto", "60", "120", "300", "600", "1800", "3600", "7200", "18000", "43200", "86400"],
          "default": "auto"
        },
        {
          "question_name": "Priority",
          "question_description": "Priority for MX and SRV records",
          "required": false,
          "type": "integer",
          "variable": "record_priority",
          "default": 10,
          "min": 0,
          "max": 65535
        },
        {
          "question_name": "Proxy Through Cloudflare",
          "question_description": "Enable Cloudflare proxy (orange cloud)",
          "required": false,
          "type": "multiplechoice",
          "variable": "global_proxied",
          "choices": ["true", "false"],
          "default": "true"
        },
        {
          "question_name": "Edge Cache TTL",
          "question_description": "Edge cache TTL in seconds",
          "required": false,
          "type": "integer",
          "variable": "edge_ttl_value",
          "default": 14400,
          "min": 0,
          "max": 31536000
        },
        {
          "question_name": "Cache Level",
          "question_description": "Cloudflare cache level setting",
          "required": false,
          "type": "multiplechoice",
          "variable": "cache_level",
          "choices": ["aggressive", "basic", "simplified"],
          "default": "aggressive"
        },
        {
          "question_name": "Security Level",
          "question_description": "SSL/TLS security setting",
          "required": false,
          "type": "multiplechoice",
          "variable": "security_level",
          "choices": ["off", "flexible", "full", "strict"],
          "default": "full"
        }
      ]
    }'
    
    echo "🔄 Applying improved survey configuration..."
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/survey_update_response.json \
      -X POST "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/" \
      -u "admin:${AWX_PASSWORD}" \
      -H "Content-Type: application/json" \
      -d "$NEW_SURVEY")
    
    if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✅ Successfully applied improved survey configuration!${NC}"
        echo ""
        echo -e "${BLUE}🎯 Improvements Applied:${NC}"
        echo "   ✅ Clean field names (Record Name, Record Value)"
        echo "   ✅ Default proxy status: proxied=true"
        echo "   ✅ Optimized field organization"
        echo "   ✅ Professional descriptions"
    else
        echo -e "${RED}❌ Failed to apply survey configuration (HTTP ${HTTP_CODE})${NC}"
        if [[ -f /tmp/survey_update_response.json ]]; then
            echo "Error response:"
            cat /tmp/survey_update_response.json
        fi
        exit 1
    fi
    
    rm -f /tmp/survey_update_response.json
}

# Verify changes
verify_changes() {
    echo -e "${BLUE}🔍 Verifying AWX Survey Changes...${NC}"
    echo "=================================="
    
    get_awx_credentials
    
    echo "📋 Checking current survey configuration..."
    SURVEY_RESPONSE=$(curl -s -u "admin:${AWX_PASSWORD}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/" 2>/dev/null || echo "failed")
    
    if [[ "$SURVEY_RESPONSE" == "failed" ]]; then
        echo -e "${RED}❌ Could not connect to AWX API${NC}"
        echo "💡 Make sure AWX is accessible at ${AWX_HOST}"
        echo "💡 You might need to run: kubectl port-forward -n awx svc/ansible-awx-service 8052:80"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Connected to AWX API successfully${NC}"
    echo ""
    echo -e "${BLUE}🔍 Checking for improvements...${NC}"
    
    # Check improvements
    if echo "$SURVEY_RESPONSE" | grep -q '"Record Name"'; then
        echo -e "${GREEN}✅ Found 'Record Name' field${NC}"
    else
        echo -e "${RED}❌ 'Record Name' field not found${NC}"
    fi
    
    if echo "$SURVEY_RESPONSE" | grep -q '"Record Value"'; then
        echo -e "${GREEN}✅ Found 'Record Value' field${NC}"
    else
        echo -e "${RED}❌ 'Record Value' field not found${NC}"
    fi
    
    if echo "$SURVEY_RESPONSE" | jq -r '.spec[] | select(.variable == "global_proxied") | .default' 2>/dev/null | grep -q "true"; then
        echo -e "${GREEN}✅ Default proxy status set to 'true'${NC}"
    else
        echo -e "${RED}❌ Default proxy status not set to 'true'${NC}"
    fi
    
    if echo "$SURVEY_RESPONSE" | grep -q '"Rule to Apply"'; then
        echo -e "${RED}❌ 'Rule to Apply' field still present (should be removed)${NC}"
    else
        echo -e "${GREEN}✅ 'Rule to Apply' field removed${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🎯 Summary: Survey verification completed${NC}"
}

# Update template
update_template() {
    echo -e "${BLUE}🔧 Updating AWX Job Template...${NC}"
    echo "==============================="
    
    get_awx_credentials
    
    # Template information
    NEW_NAME="Cloudflare - Automation"
    NEW_DESCRIPTION="Cloudflare configuration management. Streamlined DNS operations, zone settings, and domain administration automation."
    
    echo "🔄 Applying template updates..."
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/template_update_response.json \
      -X PATCH "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/" \
      -u "admin:${AWX_PASSWORD}" \
      -H "Content-Type: application/json" \
      -d "{\"description\": \"${NEW_DESCRIPTION}\", \"name\": \"${NEW_NAME}\"}")
    
    if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✅ Successfully updated job template${NC}"
        echo "  Template ID: ${AWX_TEMPLATE_ID}"
        echo "  New Name: ${NEW_NAME}"
        echo "  New Description: ${NEW_DESCRIPTION}"
    else
        echo -e "${RED}❌ Failed to update job template (HTTP ${HTTP_CODE})${NC}"
        if [[ -f /tmp/template_update_response.json ]]; then
            echo "Error response:"
            cat /tmp/template_update_response.json
        fi
        exit 1
    fi
    
    rm -f /tmp/template_update_response.json
}

# Show current configuration
show_current() {
    echo -e "${BLUE}📋 Current AWX Survey Configuration${NC}"
    echo "==================================="
    
    get_awx_credentials
    
    echo "Retrieving current survey from AWX..."
    curl -s -u "admin:${AWX_PASSWORD}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/" | jq -r '.spec[] | "\(.question_name): \(.variable) | Type: \(.type) | Default: \(.default // "none")"'
}

# Main execution
main() {
    case "${1:-help}" in
        apply-survey)
            apply_survey
            ;;
        verify-changes)
            verify_changes
            ;;
        update-template)
            update_template
            ;;
        show-current)
            show_current
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '${1:-}'${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --template-id)
            AWX_TEMPLATE_ID="$2"
            shift 2
            ;;
        --host)
            AWX_HOST="$2"
            shift 2
            ;;
        *)
            main "$1"
            exit $?
            ;;
    esac
done

# If no arguments provided, show help
if [[ $# -eq 0 ]]; then
    usage
fi

apply_survey() {
    echo -e "${BLUE}Applying improved survey configuration...${NC}"
    local awx_password=$(get_awx_password)
    
    # Survey configuration with all improvements
    local survey_config='{
      "name": "Comprehensive DNS and Cloudflare Management Survey",
      "description": "Improved survey with cleaner field names and better defaults",
      "spec": [
        {
          "question_name": "Action",
          "question_description": "Select the action to perform",
          "required": true,
          "type": "multiplechoice",
          "variable": "cf_action",
          "choices": ["create_record", "update_record", "delete_record", "clone_record", "create_domain", "update_settings", "sync"],
          "default": "create_record"
        },
        {
          "question_name": "Domain",
          "question_description": "Choose domain from your Cloudflare account",
          "required": true,
          "type": "multiplechoice",
          "variable": "existing_domain",
          "choices": ["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"],
          "default": "efutechnologies.co.za"
        },
        {
          "question_name": "Manual Domain Entry",
          "question_description": "Enter domain name manually if not in dropdown",
          "required": false,
          "type": "text",
          "variable": "manual_domain",
          "default": ""
        },
        {
          "question_name": "Record Name",
          "question_description": "Name of the DNS record to create/update",
          "required": false,
          "type": "text",
          "variable": "record_name",
          "default": ""
        },
        {
          "question_name": "Existing Record",
          "question_description": "Choose existing record (populated dynamically)",
          "required": false,
          "type": "multiplechoice",
          "variable": "existing_record",
          "choices": ["[NONE]", "[REFRESH_NEEDED]"],
          "default": "[NONE]"
        },
        {
          "question_name": "Record Type",
          "question_description": "DNS record type",
          "required": true,
          "type": "multiplechoice",
          "variable": "record_type",
          "choices": ["A", "AAAA", "CNAME", "MX", "TXT", "SRV"],
          "default": "A"
        },
        {
          "question_name": "Record Value",
          "question_description": "Record content (IP, hostname, text value, etc.)",
          "required": false,
          "type": "text",
          "variable": "record_value",
          "default": ""
        },
        {
          "question_name": "TTL",
          "question_description": "Time to live in seconds",
          "required": false,
          "type": "multiplechoice",
          "variable": "record_ttl",
          "choices": ["auto", "60", "120", "300", "600", "1800", "3600", "7200", "18000", "43200", "86400"],
          "default": "auto"
        },
        {
          "question_name": "Priority",
          "question_description": "Priority for MX and SRV records",
          "required": false,
          "type": "integer",
          "variable": "record_priority",
          "default": 10,
          "min": 0,
          "max": 65535
        },
        {
          "question_name": "Proxy Through Cloudflare",
          "question_description": "Enable Cloudflare proxy (orange cloud)",
          "required": false,
          "type": "multiplechoice",
          "variable": "global_proxied",
          "choices": ["true", "false"],
          "default": "true"
        },
        {
          "question_name": "Edge Cache TTL",
          "question_description": "Edge cache TTL in seconds",
          "required": false,
          "type": "integer",
          "variable": "edge_ttl_value",
          "default": 14400,
          "min": 0,
          "max": 31536000
        },
        {
          "question_name": "Cache Level",
          "question_description": "Cloudflare cache level setting",
          "required": false,
          "type": "multiplechoice",
          "variable": "cache_level",
          "choices": ["aggressive", "basic", "simplified"],
          "default": "aggressive"
        },
        {
          "question_name": "Security Level",
          "question_description": "SSL/TLS security setting",
          "required": false,
          "type": "multiplechoice",
          "variable": "security_level",
          "choices": ["off", "flexible", "full", "strict"],
          "default": "full"
        }
      ]
    }'
    
    local http_code=$(curl -s -w "%{http_code}" -o /tmp/survey_apply_response.json \
        -X POST "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/" \
        -u "admin:${awx_password}" \
        -H "Content-Type: application/json" \
        -d "$survey_config")
    
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✅ Survey configuration applied successfully${NC}"
        echo ""
        echo "Improvements applied:"
        echo "  ✅ Clean field names (Record Name, Record Value)"
        echo "  ✅ Default proxy status: true"
        echo "  ✅ Comprehensive field coverage"
        echo "  ✅ User-friendly descriptions"
    else
        echo -e "${RED}❌ Failed to apply survey configuration (HTTP ${http_code})${NC}"
        if [[ -f /tmp/survey_apply_response.json ]]; then
            echo "Error response:"
            cat /tmp/survey_apply_response.json
        fi
        return 1
    fi
    
    rm -f /tmp/survey_apply_response.json
}

verify_survey() {
    echo -e "${BLUE}Verifying survey configuration...${NC}"
    local awx_password=$(get_awx_password)
    local response=$(curl -s -u "admin:${awx_password}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/")
    
    echo ""
    echo "Survey Field Verification:"
    
    # Check for improved field names
    if echo "$response" | grep -q '"Record Name"'; then
        echo -e "  ${GREEN}✅ Record Name field${NC}"
    else
        echo -e "  ${RED}❌ Record Name field not found${NC}"
    fi
    
    if echo "$response" | grep -q '"Record Value"'; then
        echo -e "  ${GREEN}✅ Record Value field${NC}"
    else
        echo -e "  ${RED}❌ Record Value field not found${NC}"
    fi
    
    # Check proxy default
    if echo "$response" | jq -e '.spec[] | select(.variable == "global_proxied") | select(.default == "true")' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Proxy default: true${NC}"
    else
        echo -e "  ${RED}❌ Proxy default not set to true${NC}"
    fi
    
    # Check for removed apply rules field
    if echo "$response" | grep -q '"Rule to Apply"'; then
        echo -e "  ${RED}❌ Apply rules field still present${NC}"
    else
        echo -e "  ${GREEN}✅ Apply rules field removed${NC}"
    fi
    
    echo ""
    echo "Field Count: $(echo "$response" | jq '.spec | length') fields configured"
}

update_template() {
    echo -e "${BLUE}Updating template name and description...${NC}"
    local awx_password=$(get_awx_password)
    
    local template_name="Cloudflare - Automation"
    local template_description="Cloudflare configuration management. Streamlined DNS operations, zone settings, and domain administration automation."
    
    local http_code=$(curl -s -w "%{http_code}" -o /tmp/template_update_response.json \
        -X PATCH "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/" \
        -u "admin:${awx_password}" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${template_name}\", \"description\": \"${template_description}\"}")
    
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✅ Template updated successfully${NC}"
        echo "  Name: ${template_name}"
        echo "  Description: ${template_description}"
    else
        echo -e "${RED}❌ Failed to update template (HTTP ${http_code})${NC}"
        if [[ -f /tmp/template_update_response.json ]]; then
            echo "Error response:"
            cat /tmp/template_update_response.json
        fi
        return 1
    fi
    
    rm -f /tmp/template_update_response.json
}

show_status() {
    echo -e "${BLUE}Current template status:${NC}"
    local awx_password=$(get_awx_password)
    local template_info=$(curl -s -u "admin:${awx_password}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/")
    
    echo ""
    echo "Template Information:"
    echo "  ID: $(echo "$template_info" | jq -r '.id')"
    echo "  Name: $(echo "$template_info" | jq -r '.name')"
    echo "  Description: $(echo "$template_info" | jq -r '.description')"
    echo "  Project: $(echo "$template_info" | jq -r '.summary_fields.project.name')"
    echo "  Playbook: $(echo "$template_info" | jq -r '.playbook')"
    echo ""
    
    local survey_info=$(curl -s -u "admin:${awx_password}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/")
    echo "Survey Information:"
    echo "  Survey Name: $(echo "$survey_info" | jq -r '.name')"
    echo "  Field Count: $(echo "$survey_info" | jq '.spec | length')"
    echo "  Description: $(echo "$survey_info" | jq -r '.description')"
}

backup_survey() {
    echo -e "${BLUE}Backing up current survey configuration...${NC}"
    local awx_password=$(get_awx_password)
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="/tmp/awx_survey_backup_${timestamp}.json"
    
    curl -s -u "admin:${awx_password}" "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/survey_spec/" > "$backup_file"
    
    if [[ -s "$backup_file" ]]; then
        echo -e "${GREEN}✅ Survey backed up to: ${backup_file}${NC}"
        echo "Backup contains $(jq '.spec | length' "$backup_file") survey fields"
    else
        echo -e "${RED}❌ Failed to create backup${NC}"
        return 1
    fi
}

main() {
    show_header
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    if ! check_awx_connection; then
        exit 1
    fi
    
    case "${1:-}" in
        "apply")
            apply_survey
            ;;
        "verify")
            verify_survey
            ;;
        "update")
            update_template
            ;;
        "status")
            show_status
            ;;
        "backup")
            backup_survey
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"