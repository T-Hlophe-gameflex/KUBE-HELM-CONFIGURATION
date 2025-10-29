#!/usr/bin/env bash
set -euo pipefail

AWX_HOST="http://127.0.0.1:8052"
AWX_TOKEN="e5VRSZHAwWshxPYbKjc5p3I0zmc1T9"
TEMPLATE_ID="21"

echo "Applying survey to template ID: $TEMPLATE_ID"

# Create the complete payload with survey spec
cat > /tmp/awx_survey_payload.json << 'EOF'
{
  "survey_enabled": true,
  "survey_spec": {
    "name": "Cloudflare DNS Management Survey",
    "description": "Configure Cloudflare DNS operations",
    "spec": [
      {
        "question_name": "Cloudflare Action",
        "question_description": "Select the action to perform in Cloudflare",
        "required": true,
        "type": "multiplechoice",
        "variable": "cf_action",
        "choices": ["create_domain", "create_record", "update_record", "delete_record", "clone_record", "standardize", "sync"],
        "default": "create_record"
      },
      {
        "question_name": "Domain Name",
        "question_description": "Enter the domain name to manage (e.g., example.com)",
        "required": true,
        "type": "text",
        "variable": "domain",
        "default": ""
      },
      {
        "question_name": "Record Name",
        "question_description": "DNS record name (e.g., www, api, or @ for root)",
        "required": false,
        "type": "text",
        "variable": "record_name",
        "default": ""
      },
      {
        "question_name": "Record Type",
        "question_description": "Select the DNS record type",
        "required": false,
        "type": "multiplechoice",
        "variable": "record_type",
        "choices": ["A", "AAAA", "CNAME", "TXT", "MX", "SRV", "NS", "CAA"],
        "default": "A"
      },
      {
        "question_name": "Record Content/Value",
        "question_description": "DNS record content (IP address, target hostname, or text value)",
        "required": false,
        "type": "text",
        "variable": "record_value",
        "default": ""
      },
      {
        "question_name": "Record TTL",
        "question_description": "Time to Live in seconds (1 = automatic, 3600 = 1 hour)",
        "required": false,
        "type": "integer",
        "variable": "global_ttl",
        "default": "3600",
        "min": 1,
        "max": 2147483647
      },
      {
        "question_name": "Proxy Status",
        "question_description": "Enable Cloudflare proxy (orange cloud) - only for A, AAAA, CNAME records",
        "required": false,
        "type": "multiplechoice",
        "variable": "global_proxied",
        "choices": ["true", "false"],
        "default": "false"
      }
    ]
  }
}
EOF

echo "Payload created at /tmp/awx_survey_payload.json"

# Apply the survey
echo "Sending PATCH request to AWX..."
curl -s -X PATCH \
  -H "Authorization: Bearer $AWX_TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/awx_survey_payload.json \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/" \
  > /tmp/awx_response.json

# Check result
echo ""
echo "Response saved to /tmp/awx_response.json"
echo ""
echo "Verification:"
python3 -c "
import json
with open('/tmp/awx_response.json') as f:
    data = json.load(f)
    if data.get('id'):
        print('✓ Survey successfully applied!')
        print(f'  Template ID: {data.get(\"id\")}')
        print(f'  Survey Enabled: {data.get(\"survey_enabled\")}')
        if data.get('survey_spec'):
            spec_count = len(data.get('survey_spec', {}).get('spec', []))
            print(f'  Survey Questions: {spec_count}')
        else:
            print('  ⚠ Warning: survey_spec appears empty')
    else:
        print('❌ Error applying survey')
        print(json.dumps(data, indent=2))
"

echo ""
echo "Done!"
