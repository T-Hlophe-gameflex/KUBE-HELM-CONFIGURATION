#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                 Restore Original AWX Survey                   ║"
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

# Create the restored survey JSON with only your original actions
echo "🔧 Restoring original survey configuration..."

RESTORED_SURVEY=$(cat << 'EOF'
{
  "name": "Cloudflare DNS Operations",
  "description": "DNS record management operations",
  "spec": [
    {
      "question_name": "Action",
      "question_description": "Select the DNS operation to perform",
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
      "question_name": "Domain",
      "question_description": "Domain where the operation will be performed",
      "required": true,
      "type": "text",
      "variable": "existing_domain",
      "default": ""
    },
    {
      "question_name": "Record Name",
      "question_description": "Name of the DNS record (without domain suffix)",
      "required": true,
      "type": "text", 
      "variable": "existing_record",
      "default": ""
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
      "question_description": "Record content (IP address, hostname, text value, etc.)",
      "required": false,
      "type": "text",
      "variable": "record_value",
      "default": ""
    },
    {
      "question_name": "TTL",
      "question_description": "Time to live in seconds",
      "required": false,
      "type": "integer",
      "variable": "global_ttl",
      "default": 3600,
      "min": 60,
      "max": 86400
    },
    {
      "question_name": "Proxied",
      "question_description": "Enable Cloudflare proxy (orange cloud)",
      "required": false,
      "type": "multiplechoice",
      "variable": "global_proxied",
      "choices": ["true", "false"],
      "default": "false"
    }
  ]
}
EOF
)

echo "🔄 Updating survey configuration..."
UPDATE_RESPONSE=$(curl -s -X POST http://localhost:8052/api/v2/job_templates/$TEMPLATE_ID/survey_spec/ \
  -H "Content-Type: application/json" \
  -u "admin:$AWX_ADMIN_PASSWORD" \
  -d "$RESTORED_SURVEY")

if echo "$UPDATE_RESPONSE" | jq -e '.spec' >/dev/null 2>&1; then
    echo "✅ Survey restored successfully!"
    echo "📊 Survey now has $(echo "$UPDATE_RESPONSE" | jq -r '.spec | length') fields configured"
    echo ""
    echo "🎯 Survey fields:"
    echo "   • Action: create_record, update_record, delete_record, clone_record"
    echo "   • Domain: existing_domain variable"
    echo "   • Record Name: existing_record variable"
    echo "   • Record Type: A, AAAA, CNAME, MX, TXT, SRV"
    echo "   • Record Value: Optional content"
    echo "   • TTL: Optional (default 3600)"
    echo "   • Proxied: Optional (default false)"
else
    echo "❌ Error updating survey:"
    echo "$UPDATE_RESPONSE" | jq -r '.detail // .error // .'
    exit 1
fi

echo ""
echo "📝 Next steps:"
echo "   1. Update the playbook to work with these consistent field names"
echo "   2. Test all operations (create, update, delete, clone)"
echo "   3. Clone operation will use existing_domain and existing_record properly"

echo "✅ Survey restoration complete!"