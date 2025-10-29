#!/bin/bash
#
# Script to update DNS records dropdown for a specific domain
# Usage: ./update-dns-records-dropdown.sh <domain>
# Example: ./update-dns-records-dropdown.sh efutechnologies.co.za
#

set -e

# Configuration
AWX_HOST="${AWX_HOST:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-}"
TEMPLATE_ID="${TEMPLATE_ID:-21}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if domain argument provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain name required${NC}"
    echo "Usage: $0 <domain>"
    echo "Example: $0 efutechnologies.co.za"
    exit 1
fi

DOMAIN="$1"

# Check prerequisites
if [ -z "$AWX_TOKEN" ]; then
    echo -e "${RED}Error: AWX_TOKEN not set${NC}"
    echo "Export AWX_TOKEN before running this script"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN not set${NC}"
    echo "Export CLOUDFLARE_API_TOKEN before running this script"
    exit 1
fi

echo -e "${GREEN}Fetching zone ID for domain: $DOMAIN${NC}"

# Get zone ID for the domain
ZONE_LOOKUP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if request was successful
if ! echo "$ZONE_LOOKUP" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${RED}Error fetching zone from Cloudflare API${NC}"
    echo "$ZONE_LOOKUP" | jq '.errors' 2>/dev/null || echo "$ZONE_LOOKUP"
    exit 1
fi

ZONE_ID=$(echo "$ZONE_LOOKUP" | jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ]; then
    echo -e "${RED}Error: Zone not found for domain $DOMAIN${NC}"
    exit 1
fi

echo -e "${GREEN}Zone ID: $ZONE_ID${NC}"
echo ""
echo -e "${GREEN}Fetching DNS records for $DOMAIN...${NC}"

# Fetch all DNS records for this zone
RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if request was successful
if ! echo "$RECORDS_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${RED}Error fetching DNS records from Cloudflare API${NC}"
    echo "$RECORDS_RESPONSE" | jq '.errors' 2>/dev/null || echo "$RECORDS_RESPONSE"
    exit 1
fi

# Display records in a nice format
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}DNS RECORDS FOR: $DOMAIN${NC}"
echo -e "${GREEN}======================================${NC}"

echo "$RECORDS_RESPONSE" | jq -r '.result[] | 
    "[\(.type)] \(.name)\n  → \(.content)\n  TTL: \(.ttl) | Proxied: \(.proxied // false) | ID: \(.id)\n"'

RECORD_COUNT=$(echo "$RECORDS_RESPONSE" | jq '.result | length')
echo -e "${GREEN}Total Records: $RECORD_COUNT${NC}"
echo ""

# Build record name choices for survey (format: "record_name (type)")
RECORD_CHOICES=$(echo "$RECORDS_RESPONSE" | jq -r '.result[] | "\(.name) (\(.type))"' | sort | jq -R . | jq -s .)

echo -e "${GREEN}Fetching current survey specification...${NC}"

# Get current survey
CURRENT_SURVEY=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" \
    "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/")

# Check if survey exists
if ! echo "$CURRENT_SURVEY" | jq -e '.spec' > /dev/null 2>&1; then
    echo -e "${RED}Error: No survey found for template $TEMPLATE_ID${NC}"
    exit 1
fi

echo -e "${GREEN}Updating survey with DNS records for $DOMAIN...${NC}"

# Update the record_name question with dynamic choices
UPDATED_SURVEY=$(echo "$CURRENT_SURVEY" | jq --argjson records "$RECORD_CHOICES" '
    .spec = (.spec | map(
        if .variable == "record_name" then
            .type = "multiplechoice" |
            .choices = $records |
            .question_description = "Select existing record or enter new name (showing records from last domain queried)"
        else
            .
        end
    ))
')

# Save updated survey back to AWX
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/awx_survey_response.txt -X POST \
    -H "Authorization: Bearer $AWX_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$UPDATED_SURVEY" \
    "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/")

# Check if update was successful (200 or 204 with empty response is success for AWX)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✓ Survey updated successfully!${NC}"
    echo ""
    echo -e "${YELLOW}DNS records dropdown now includes $RECORD_COUNT records from $DOMAIN${NC}"
else
    echo -e "${RED}Error updating survey (HTTP $HTTP_CODE)${NC}"
    cat /tmp/awx_survey_response.txt | jq '.' 2>/dev/null || cat /tmp/awx_survey_response.txt
    exit 1
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Survey updated successfully!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
