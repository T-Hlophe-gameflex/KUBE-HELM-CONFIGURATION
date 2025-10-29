#!/bin/bash
#
# Script to dynamically update AWX survey with current Cloudflare domains and DNS records
# Usage: ./update-survey-dropdowns.sh
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

echo -e "${GREEN}Fetching current Cloudflare zones (domains)...${NC}"

# Fetch all zones from Cloudflare
ZONES_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

# Check if request was successful
if ! echo "$ZONES_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${RED}Error fetching zones from Cloudflare API${NC}"
    echo "$ZONES_RESPONSE" | jq '.errors' 2>/dev/null || echo "$ZONES_RESPONSE"
    exit 1
fi

# Extract domain names
DOMAINS=$(echo "$ZONES_RESPONSE" | jq -r '.result[].name' | sort)
DOMAIN_COUNT=$(echo "$DOMAINS" | wc -l | tr -d ' ')

echo -e "${GREEN}Found $DOMAIN_COUNT domains:${NC}"
echo "$DOMAINS" | sed 's/^/  - /'

# Build domain choices array for survey
DOMAIN_CHOICES=$(echo "$DOMAINS" | jq -R . | jq -s .)

echo ""
echo -e "${GREEN}Fetching current survey specification...${NC}"

# Get current survey
CURRENT_SURVEY=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" \
    "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/")

# Check if survey exists
if ! echo "$CURRENT_SURVEY" | jq -e '.spec' > /dev/null 2>&1; then
    echo -e "${RED}Error: No survey found for template $TEMPLATE_ID${NC}"
    exit 1
fi

echo -e "${GREEN}Updating survey with dynamic domain list...${NC}"

# Update the domain question with dynamic choices
UPDATED_SURVEY=$(echo "$CURRENT_SURVEY" | jq --argjson domains "$DOMAIN_CHOICES" '
    .spec = (.spec | map(
        if .variable == "domain" then
            .type = "multiplechoice" |
            .choices = $domains
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
    echo -e "${YELLOW}Domain dropdown now includes:${NC}"
    echo "$DOMAINS" | sed 's/^/  - /'
else
    echo -e "${RED}Error updating survey (HTTP $HTTP_CODE)${NC}"
    cat /tmp/awx_survey_response.txt | jq '.' 2>/dev/null || cat /tmp/awx_survey_response.txt
    exit 1
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Survey dropdowns updated successfully!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Note: DNS records dropdown would be updated dynamically based on the selected domain."
echo "To implement this, you can:"
echo "  1. Add a webhook that triggers when domain is selected"
echo "  2. Use AWX's API to fetch records for that domain"
echo "  3. Or manually run this script with a specific domain to update record choices"
echo ""
