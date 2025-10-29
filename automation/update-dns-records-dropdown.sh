#!/bin/bash
#
# Script to update DNS records dropdown with ALL records from ALL domains
# Usage: ./update-dns-records-dropdown.sh
# This will fetch all zones and all DNS records across your entire Cloudflare account
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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${GREEN}Fetching all zones from Cloudflare account...${NC}"

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

echo -e "${GREEN}Found $ZONE_COUNT zones${NC}"
echo ""

# Initialize array to collect all record names
ALL_RECORDS=()
TOTAL_RECORDS=0

# Loop through each zone and fetch DNS records
while IFS='|' read -r ZONE_ID ZONE_NAME; do
    echo -e "${BLUE}Fetching DNS records for: $ZONE_NAME${NC}"
    
    # Fetch DNS records for this zone
    RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if request was successful
    if echo "$RECORDS_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        # Extract just the record names (without type suffix)
        RECORD_NAMES=$(echo "$RECORDS_RESPONSE" | jq -r '.result[].name' | sort)
        RECORD_COUNT=$(echo "$RECORD_NAMES" | wc -l | tr -d ' ')
        
        echo -e "  ${GREEN}✓${NC} Found $RECORD_COUNT records"
        
        # Add to our collection
        while IFS= read -r record_name; do
            ALL_RECORDS+=("$record_name")
        done <<< "$RECORD_NAMES"
        
        TOTAL_RECORDS=$((TOTAL_RECORDS + RECORD_COUNT))
    else
        echo -e "  ${RED}✗${NC} Failed to fetch records"
    fi
done <<< "$ZONE_DATA"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Total DNS Records: $TOTAL_RECORDS${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Remove duplicates and sort
UNIQUE_RECORDS=($(printf '%s\n' "${ALL_RECORDS[@]}" | sort -u))
UNIQUE_COUNT=${#UNIQUE_RECORDS[@]}

echo -e "${YELLOW}Unique record names: $UNIQUE_COUNT${NC}"
echo ""

# Convert to JSON array for survey
RECORD_CHOICES=$(printf '%s\n' "${UNIQUE_RECORDS[@]}" | jq -R . | jq -s .)

echo -e "${GREEN}Fetching current survey specification...${NC}"

# Get current survey
CURRENT_SURVEY=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" \
    "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/")

# Check if survey exists
if ! echo "$CURRENT_SURVEY" | jq -e '.spec' > /dev/null 2>&1; then
    echo -e "${RED}Error: No survey found for template $TEMPLATE_ID${NC}"
    exit 1
fi

echo -e "${GREEN}Updating survey with ALL DNS records from account...${NC}"

# Build choices array with "none" as first option
RECORD_CHOICES_WITH_NONE=$(echo '["none"]' | jq --argjson records "$RECORD_CHOICES" '. + $records')

# Update the existing_record_name question with dynamic choices
UPDATED_SURVEY=$(echo "$CURRENT_SURVEY" | jq --argjson records "$RECORD_CHOICES_WITH_NONE" '
    .spec = (.spec | map(
        if .variable == "existing_record_name" then
            .type = "multiplechoice" |
            .choices = $records |
            .required = false |
            .question_description = "Select existing record from any domain (for update/delete), or leave as '\''none'\'' for new records"
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
    echo -e "${YELLOW}DNS records dropdown now includes:${NC}"
    echo -e "  - ${GREEN}$UNIQUE_COUNT unique record names${NC} from $ZONE_COUNT domains"
    echo -e "  - ${BLUE}Total $TOTAL_RECORDS records processed${NC}"
    echo ""
    echo -e "${YELLOW}Sample records in dropdown:${NC}"
    printf '%s\n' "${UNIQUE_RECORDS[@]}" | head -10 | sed 's/^/  - /'
    if [ $UNIQUE_COUNT -gt 10 ]; then
        echo -e "  ... and $((UNIQUE_COUNT - 10)) more"
    fi
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
echo -e "${BLUE}Note:${NC} AWX multiplechoice fields allow both:"
echo "  1. Selecting from dropdown (all $UNIQUE_COUNT existing records)"
echo "  2. Typing a new record name manually"
echo ""
