#!/bin/bash
#
# Script to display all DNS records from all domains in your Cloudflare account
# This helps you see what records exist when creating/updating/deleting records
# Usage: ./list-all-dns-records.sh
#

set -e

# Configuration
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check prerequisites
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN not set${NC}"
    echo "Export CLOUDFLARE_API_TOKEN before running this script"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Cloudflare DNS Records - All Domains                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get all zones
ZONES_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if request was successful
if ! echo "$ZONES_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${RED}Error fetching zones from Cloudflare API${NC}"
    echo "$ZONES_RESPONSE" | jq '.errors' 2>/dev/null || echo "$ZONES_RESPONSE"
    exit 1
fi

# Get zone IDs and names
ZONE_DATA=$(echo "$ZONES_RESPONSE" | jq -r '.result[] | "\(.id)|\(.name)"')
ZONE_COUNT=$(echo "$ZONE_DATA" | wc -l | tr -d ' ')

echo -e "${CYAN}Found $ZONE_COUNT domains in your Cloudflare account${NC}"
echo ""

TOTAL_RECORDS=0
ALL_RECORD_NAMES=()

# Loop through each zone and fetch DNS records
while IFS='|' read -r ZONE_ID ZONE_NAME; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Domain: $ZONE_NAME${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Fetch DNS records for this zone
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if request was successful
    if echo "$RECORDS_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        RECORD_COUNT=$(echo "$RECORDS_RESPONSE" | jq '.result | length')
        
        if [ "$RECORD_COUNT" -eq 0 ]; then
            echo -e "${YELLOW}  No DNS records found${NC}"
        else
            echo "$RECORDS_RESPONSE" | jq -r '.result[] | 
                "  \u001b[32m[\(.type)]\u001b[0m \(.name)\n    → \(.content)\n    TTL: \(.ttl) | Proxied: \(.proxied // false) | ID: \(.id)\n"'
            
            # Collect record names
            RECORD_NAMES=$(echo "$RECORDS_RESPONSE" | jq -r '.result[].name')
            while IFS= read -r record_name; do
                ALL_RECORD_NAMES+=("$record_name")
            done <<< "$RECORD_NAMES"
        fi
        
        echo -e "${CYAN}  Total: $RECORD_COUNT records${NC}"
        TOTAL_RECORDS=$((TOTAL_RECORDS + RECORD_COUNT))
    else
        echo -e "${RED}  Failed to fetch records${NC}"
    fi
    echo ""
done <<< "$ZONE_DATA"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                         SUMMARY                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e "${CYAN}Total Domains: $ZONE_COUNT${NC}"
echo -e "${CYAN}Total DNS Records: $TOTAL_RECORDS${NC}"

# Show unique record names
UNIQUE_RECORDS=($(printf '%s\n' "${ALL_RECORD_NAMES[@]}" | sort -u))
UNIQUE_COUNT=${#UNIQUE_RECORDS[@]}
echo -e "${CYAN}Unique Record Names: $UNIQUE_COUNT${NC}"
echo ""
echo -e "${YELLOW}All unique record names (use these when creating/updating/deleting):${NC}"
printf '%s\n' "${UNIQUE_RECORDS[@]}" | sed 's/^/  • /'
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Use these record names in AWX survey when launching jobs     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
