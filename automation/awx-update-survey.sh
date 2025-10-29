#!/usr/bin/env bash
set -euo pipefail

AWX_HOST="${AWX_HOST:-http://localhost:8043}"
AWX_USER="${AWX_USER:-admin}"
TEMPLATE_NAME="Cloudflare Main Templete"
SURVEY_JSON="automation/unified-cloudflare-awx-survey.json"

AWX_PASS=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || true)
if [ -z "$AWX_PASS" ]; then
  echo "Could not get AWX admin password from Kubernetes. Is kubectl configured and the secret present?"
  exit 1
fi

TOKEN_JSON=$(curl -s -u "$AWX_USER:$AWX_PASS" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/tokens/" -d '{"description":"cloudflare-automation"}')
AWX_TOKEN=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("token",""))' <<< "$TOKEN_JSON")
if [ -z "$AWX_TOKEN" ]; then echo "Failed to get AWX token"; exit 1; fi

awx_get() { curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST$1"; }

ID=$(awx_get "/api/v2/job_templates/?name=$TEMPLATE_NAME" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')
if [ -z "$ID" ]; then echo "Job template '$TEMPLATE_NAME' not found"; exit 1; fi

if [ -f "$SURVEY_JSON" ]; then
  NEW_SPEC=$(python3 -c 'import sys,json; print(json.dumps({"name": "Survey", "spec": json.load(sys.stdin)}))' < "$SURVEY_JSON")
else
  # Inline fallback survey spec
  NEW_SPEC='{"name": "Survey", "spec": [
    {"question_name": "Domain Name", "variable": "domain", "type": "text", "required": true, "default": ""},
    {"question_name": "Action", "variable": "cf_action", "type": "multiplechoice", "choices": ["create_record", "update_record", "delete_record", "create_domain", "clone_record"], "required": true, "default": "create_record"},
    {"question_name": "Page Rule Selection", "variable": "page_rule_selection", "type": "multiplechoice", "choices": ["Browser TTL", "Always Use HTTPS", "all"], "required": false, "default": "all"}
  ]}'
fi

curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X PATCH "$AWX_HOST/api/v2/job_templates/$ID/" -d "{\"survey_enabled\": true, \"survey_spec\": $NEW_SPEC}" >/dev/null || true

echo "Patched job template $ID with survey fields."
