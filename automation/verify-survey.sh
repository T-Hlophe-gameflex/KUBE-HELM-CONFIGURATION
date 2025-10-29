#!/usr/bin/env bash
# Quick verification script to check if AWX survey is properly configured

set -euo pipefail

AWX_HOST="${AWX_HOST:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-e5VRSZHAwWshxPYbKjc5p3I0zmc1T9}"
TEMPLATE_NAME="Cloudflare AWX Survey"

echo "========================================"
echo "AWX Survey Verification"
echo "========================================"
echo ""

# Find template
TEMPLATE_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/?name=$(echo "$TEMPLATE_NAME" | sed 's/ /%20/g')" | \
  python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j.get("results") else "")')

if [ -z "$TEMPLATE_ID" ]; then
  echo "❌ Template '$TEMPLATE_NAME' not found"
  exit 1
fi

echo "✓ Template found: ID $TEMPLATE_ID"
echo ""

# Check survey status
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/" > /tmp/awx_template_check.json

ENABLED=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("survey_enabled", False))')
NAME=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("name", "N/A"))')
PLAYBOOK=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("playbook", "N/A"))')

echo "Template Details:"
echo "  Name: $NAME"
echo "  Playbook: $PLAYBOOK"
echo "  Survey Enabled: $ENABLED"
echo ""

if [ "$ENABLED" = "True" ]; then
  echo "✓ Survey is ENABLED"
else
  echo "❌ Survey is NOT enabled"
  echo ""
  echo "Run this to enable: ./automation/apply-survey-to-template.sh"
  exit 1
fi

echo ""
echo "========================================"
echo "Next Steps:"
echo "========================================"
echo ""
echo "1. Open AWX in your browser:"
echo "   http://127.0.0.1:8052"
echo ""
echo "2. Navigate to Templates → $TEMPLATE_NAME"
echo ""
echo "3. Click the 'Launch' button"
echo ""
echo "4. You should see a survey form with these fields:"
echo "   - Cloudflare Action (dropdown)"
echo "   - Domain Name (text)"
echo "   - Record Name (text)"
echo "   - Record Type (dropdown)"
echo "   - Record Content/Value (text)"
echo "   - Record TTL (number)"
echo "   - Proxy Status (dropdown)"
echo ""
echo "5. Fill in the survey and click 'Next' then 'Launch'"
echo ""
echo "========================================"
