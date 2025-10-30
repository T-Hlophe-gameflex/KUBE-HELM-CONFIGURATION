#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Restore Comprehensive AWX Survey                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# Check if we're in the right directory
if [ ! -f "automation/playbooks/cloudflare/cloudflare_awx_playbook.yml" ]; then
    echo "❌ Error: Must be run from the project root directory"
    exit 1
fi

# Find AWX service and get admin password
echo "✓ Finding AWX service..."
if ! kubectl get service ansible-awx-service -n awx >/dev/null 2>&1; then
    echo "❌ Error: AWX service not found in 'awx' namespace"
    exit 1
fi

echo "✓ Getting AWX admin password..."
AWX_ADMIN_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 -d)
if [ -z "$AWX_ADMIN_PASSWORD" ]; then
    echo "❌ Error: Could not retrieve AWX admin password"
    exit 1
fi

echo "📡 Connecting to AWX API..."

# Get the Cloudflare template
echo "📋 Finding Cloudflare template..."
TEMPLATE_ID=$(curl -s http://localhost:8052/api/v2/job_templates/ -u "admin:$AWX_ADMIN_PASSWORD" | jq -r '.results[] | select(.name | contains("Cloudflare")) | .id')

if [ -z "$TEMPLATE_ID" ]; then
    echo "❌ Error: Could not find Cloudflare job template"
    exit 1
fi

echo "✓ Found template ID: $TEMPLATE_ID"

# Get current Cloudflare domains for dynamic dropdown
echo "🔍 Getting Cloudflare domains for dynamic dropdown..."
CLOUDFLARE_API_TOKEN=$(kubectl get secret cloudflare-credentials -n awx -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  No Cloudflare token found, using static domains"
    DOMAIN_CHOICES='["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
else
    echo "✓ Found Cloudflare token, fetching live domains..."
    DOMAINS=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        "https://api.cloudflare.com/client/v4/zones" | \
        jq -r '.result[]?.name // empty' 2>/dev/null || echo "")
    
    if [ -n "$DOMAINS" ]; then
        DOMAIN_CHOICES=$(echo "$DOMAINS" | jq -R -s 'split("\n") | map(select(length > 0)) + ["[MANUAL_ENTRY]"]')
    else
        DOMAIN_CHOICES='["efustryton.co.za", "efutechnologies.co.za", "[MANUAL_ENTRY]"]'
    fi
fi

echo "✓ Domain choices: $DOMAIN_CHOICES"

# Create the comprehensive survey JSON matching your screenshot
echo "🔧 Creating comprehensive survey configuration..."

COMPREHENSIVE_SURVEY=$(cat << EOF
{
  "name": "Cloudflare Automation Survey",
  "description": "Comprehensive DNS and Cloudflare management survey",
  "spec": [
    {
      "question_name": "Cloudflare Action",
      "question_description": "Select the action to perform",
      "required": true,
      "type": "multiplechoice",
      "variable": "cf_action",
      "choices": [
        "create_record",
        "update_record", 
        "delete_record",
        "clone_record"
      ],
      "default": "create_record"
    },
    {
      "question_name": "Select Existing Domain",
      "question_description": "Choose domain from your Cloudflare account",
      "required": false,
      "type": "multiplechoice",
      "variable": "existing_domain",
      "choices": $DOMAIN_CHOICES,
      "default": ""
    },
    {
      "question_name": "Domain Name (Manual Entry)",
      "question_description": "Enter domain name manually if not in dropdown",
      "required": false,
      "type": "text",
      "variable": "domain",
      "default": ""
    },
    {
      "question_name": "New Record Name",
      "question_description": "Name of the DNS record to create/update",
      "required": false,
      "type": "text", 
      "variable": "record_name",
      "default": ""
    },
    {
      "question_name": "Select Existing Record",
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
      "question_name": "Record Content/Value",
      "question_description": "Record content (IP, hostname, text value, etc.)",
      "required": false,
      "type": "text",
      "variable": "record_value",
      "default": ""
    },
    {
      "question_name": "Record TTL",
      "question_description": "Time to live in seconds",
      "required": false,
      "type": "integer",
      "variable": "global_ttl",
      "default": 3600,
      "min": 60,
      "max": 86400
    },
    {
      "question_name": "Record Priority",
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
      "default": "false"
    },
    {
      "question_name": "Rule to Apply",
      "question_description": "Page rule action to apply",
      "required": false,
      "type": "multiplechoice",
      "variable": "rule_action",
      "choices": ["force_https", "browser_cache_ttl", "edge_cache_ttl", "cache_level", "bypass_cache_on_cookie"],
      "default": "force_https"
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
      "variable": "cache_level_mode",
      "choices": ["aggressive", "basic", "simplified"],
      "default": "basic"
    },
    {
      "question_name": "SSL/TLS Recommender",
      "question_description": "SSL/TLS security setting",
      "required": false,
      "type": "multiplechoice",
      "variable": "ssl_tls_recommender",
      "choices": ["on", "off"],
      "default": "on"
    }
  ]
}
EOF
)

echo "🔄 Updating survey configuration..."
UPDATE_RESPONSE=$(curl -s -X POST http://localhost:8052/api/v2/job_templates/$TEMPLATE_ID/survey_spec/ \
  -H "Content-Type: application/json" \
  -u "admin:$AWX_ADMIN_PASSWORD" \
  -d "$COMPREHENSIVE_SURVEY")

if echo "$UPDATE_RESPONSE" | jq -e '.spec' >/dev/null 2>&1; then
    echo "✅ Comprehensive survey restored successfully!"
    echo "📊 Survey now has $(echo "$UPDATE_RESPONSE" | jq -r '.spec | length') fields configured"
    echo ""
    echo "🎯 Survey includes:"
    echo "   • Dynamic domain dropdown (populated from Cloudflare)"
    echo "   • Manual domain entry fallback"
    echo "   • Dynamic record selection"
    echo "   • Comprehensive DNS record options"
    echo "   • Cloudflare proxy and caching settings"
    echo "   • SSL/TLS configuration"
    echo ""
    echo "🔄 Next step: Run the dropdown update script to populate dynamic values:"
    echo "   bash automation/scripts/update_awx_survey_dropdowns.sh"
else
    echo "❌ Error updating survey:"
    echo "$UPDATE_RESPONSE" | jq -r '.detail // .error // .'
    exit 1
fi

echo "✅ Comprehensive survey restoration complete!"