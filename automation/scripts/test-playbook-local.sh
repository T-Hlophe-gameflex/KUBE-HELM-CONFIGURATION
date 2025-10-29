#!/bin/bash
#===============================================================================
# Local Playbook Testing Script
#===============================================================================
# Tests the Cloudflare automation playbook locally before deploying to AWX
# Usage: ./test-playbook-local.sh [action] [domain] [record_name] [record_value]
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAYBOOK_PATH="$PROJECT_ROOT/automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml"

# Load environment variables
if [ -f "$PROJECT_ROOT/environments/development.env" ]; then
    echo -e "${BLUE}Loading development environment...${NC}"
    export $(grep -v '^#' "$PROJECT_ROOT/environments/development.env" | xargs)
else
    echo -e "${RED}Error: development.env not found${NC}"
    exit 1
fi

# Verify Cloudflare API token
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN not set${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Cloudflare API token loaded${NC}"

#===============================================================================
# Test Functions
#===============================================================================

test_create_domain() {
    local domain="${1:-test-$(date +%s).example.com}"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 1: Create Domain with All Modern Rules${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Action: ${YELLOW}create_domain${NC}"
    echo -e "Rules: ${YELLOW}all (7 rules)${NC}"
    echo -e "Edge TTL: ${YELLOW}7200 seconds${NC}"
    echo -e "Cache Level: ${YELLOW}bypass${NC}"
    echo -e "SSL/TLS Recommender: ${YELLOW}enabled${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=create_domain" \
        -e "domain=${domain}" \
        -e "rule_action=all" \
        -e "edge_ttl_value=7200" \
        -e "cache_level_mode=bypass" \
        -e "ssl_tls_recommender=enabled" \
        -e "cf_validate_certs=false" \
        -v
    
    echo -e "\n${GREEN}✓ Test 1 completed${NC}"
}

test_create_record() {
    local domain="${1:-existing-domain.example.com}"
    local record_name="${2:-test-record}"
    local record_value="${3:-192.168.1.100}"
    
    # Validate IP address format for A records
    if [[ ! "$record_value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "\n${RED}✗ Error: A record value must be a valid IPv4 address${NC}"
        echo -e "${RED}  You provided: ${record_value}${NC}"
        echo -e "${RED}  Expected format: 192.168.1.100${NC}\n"
        return 1
    fi
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 2: Create DNS Record with Specific Rules${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Record: ${YELLOW}${record_name}${NC}"
    echo -e "Type: ${YELLOW}A${NC}"
    echo -e "Value: ${YELLOW}${record_value}${NC}"
    echo -e "Rules: ${YELLOW}cache_level, edge_cache_ttl${NC}"
    echo -e "Edge TTL: ${YELLOW}3600 seconds${NC}"
    echo -e "Cache Level: ${YELLOW}standard${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=create_record" \
        -e "domain=${domain}" \
        -e "record_name=${record_name}" \
        -e "record_type=A" \
        -e "record_value=${record_value}" \
        -e "rule_action=cache_level" \
        -e "edge_ttl_value=3600" \
        -e "cache_level_mode=standard" \
        -e "cf_validate_certs=false" \
        -v
    
    echo -e "\n${GREEN}✓ Test 2 completed${NC}"
}

test_create_cname() {
    local domain="${1:-existing-domain.example.com}"
    local record_name="${2:-test-cname}"
    local record_value="${3:-target.example.com}"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 3: Create CNAME Record with Rules${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Record: ${YELLOW}${record_name}${NC}"
    echo -e "Type: ${YELLOW}CNAME${NC}"
    echo -e "Target: ${YELLOW}${record_value}${NC}"
    echo -e "Rules: ${YELLOW}cache_level, edge_cache_ttl${NC}"
    echo -e "Edge TTL: ${YELLOW}3600 seconds${NC}"
    echo -e "Cache Level: ${YELLOW}standard${NC}"
    echo -e "Proxied: ${YELLOW}true${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=create_record" \
        -e "domain=${domain}" \
        -e "record_name=${record_name}" \
        -e "record_type=CNAME" \
        -e "record_value=${record_value}" \
        -e "proxied=true" \
        -e "rule_action=cache_level" \
        -e "edge_ttl_value=3600" \
        -e "cache_level_mode=standard" \
        -e "cf_validate_certs=false" \
        -v
    
    echo -e "\n${GREEN}✓ Test 3 completed${NC}"
}

test_update_record() {
    local domain="${1:-existing-domain.example.com}"
    local record_name="${2:-test-record}"
    local record_value="${3:-192.168.1.200}"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 4: Update DNS Record${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Record: ${YELLOW}${record_name}${NC}"
    echo -e "New Value: ${YELLOW}${record_value}${NC}"
    echo -e "Rules: ${YELLOW}none (no rule updates)${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=update_record" \
        -e "domain=${domain}" \
        -e "record_name=${record_name}" \
        -e "record_type=A" \
        -e "record_value=${record_value}" \
        -e "rule_action=none" \
        -e "cf_validate_certs=false" \
        -v
    
    echo -e "\n${GREEN}✓ Test 4 completed${NC}"
}

test_standardize_zone() {
    local domain="${1:-existing-domain.example.com}"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 5: Standardize Zone Settings${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Action: ${YELLOW}standardize${NC}"
    echo -e "SSL/TLS Recommender: ${YELLOW}enabled${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=standardize" \
        -e "domain=${domain}" \
        -e "ssl_tls_recommender=enabled" \
        -e "cf_validate_certs=false" \
        -v
    
    echo -e "\n${GREEN}✓ Test 4 completed${NC}"
}

test_dry_run() {
    local domain="${1:-test-dryrun.example.com}"
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}TEST 5: Dry Run (Syntax Check)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "Domain: ${YELLOW}${domain}${NC}"
    echo -e "Mode: ${YELLOW}Check only (no changes)${NC}\n"
    
    ansible-playbook "$PLAYBOOK_PATH" \
        -e "cf_action=create_domain" \
        -e "domain=${domain}" \
        -e "rule_action=all" \
        -e "edge_ttl_value=7200" \
        -e "cache_level_mode=bypass" \
        -e "ssl_tls_recommender=enabled" \
        --syntax-check
    
    echo -e "\n${GREEN}✓ Syntax check passed${NC}"
}

#===============================================================================
# Interactive Menu
#===============================================================================

show_menu() {
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Cloudflare Playbook - Local Testing Menu             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    echo -e "${YELLOW}1.${NC} Test Create Domain (with all rules)"
    echo -e "${YELLOW}2.${NC} Test Create A Record (IPv4 address)"
    echo -e "${YELLOW}3.${NC} Test Create CNAME Record (with cache rules) ${GREEN}← Recommended${NC}"
    echo -e "${YELLOW}4.${NC} Test Update DNS Record"
    echo -e "${YELLOW}5.${NC} Test Standardize Zone Settings"
    echo -e "${YELLOW}6.${NC} Dry Run (Syntax Check)"
    echo -e "${YELLOW}7.${NC} Custom Test (provide your own parameters)"
    echo -e "${YELLOW}8.${NC} Exit\n"
}

run_interactive() {
    while true; do
        show_menu
        read -p "$(echo -e ${BLUE}Select test [1-8]:${NC} )" choice
        
        case $choice in
            1)
                read -p "Enter domain (or press Enter for auto-generated): " domain
                if [ -z "$domain" ]; then
                    domain="test-$(date +%s).yourdomain.com"
                fi
                test_create_domain "$domain"
                ;;
            2)
                read -p "Enter domain: " domain
                read -p "Enter record name: " record_name
                read -p "Enter record value (IP): " record_value
                test_create_record "$domain" "$record_name" "$record_value"
                ;;
            3)
                read -p "Enter domain: " domain
                read -p "Enter record name: " record_name
                read -p "Enter target hostname (e.g., example.com): " record_value
                test_create_cname "$domain" "$record_name" "$record_value"
                ;;
            4)
                read -p "Enter domain: " domain
                read -p "Enter record name: " record_name
                read -p "Enter new record value (IP): " record_value
                test_update_record "$domain" "$record_name" "$record_value"
                ;;
            5)
                read -p "Enter domain: " domain
                test_standardize_zone "$domain"
                ;;
            6)
                test_dry_run
                ;;
            7)
                echo -e "\n${YELLOW}Custom Test Mode${NC}"
                read -p "cf_action: " action
                read -p "domain: " domain
                read -p "Additional args (optional): " extra_args
                
                ansible-playbook "$PLAYBOOK_PATH" \
                    -e "cf_action=${action}" \
                    -e "domain=${domain}" \
                    ${extra_args} \
                    -e "cf_validate_certs=false" \
                    -v
                ;;
            8)
                echo -e "\n${GREEN}Goodbye!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 1-8.${NC}"
                ;;
        esac
        
        echo -e "\n${BLUE}Press Enter to continue...${NC}"
        read
    done
}

#===============================================================================
# Main
#===============================================================================

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook not found${NC}"
    echo -e "${YELLOW}Install with: pip install ansible${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Ansible found: $(ansible-playbook --version | head -1)${NC}"

# Parse command line arguments
if [ $# -eq 0 ]; then
    # No arguments - run interactive menu
    run_interactive
else
    # Arguments provided - run specific test
    case "$1" in
        create_domain)
            test_create_domain "${2:-}"
            ;;
        create_record)
            test_create_record "${2:-}" "${3:-}" "${4:-}"
            ;;
        update_record)
            test_update_record "${2:-}" "${3:-}" "${4:-}"
            ;;
        standardize)
            test_standardize_zone "${2:-}"
            ;;
        dry_run)
            test_dry_run "${2:-}"
            ;;
        *)
            echo -e "${RED}Unknown test: $1${NC}"
            echo -e "${YELLOW}Usage: $0 [create_domain|create_record|update_record|standardize|dry_run] [args...]${NC}"
            exit 1
            ;;
    esac
fi
