#!/usr/bin/env bash
# Fetch DNS records for a zone and output a JSON payload suitable for AWX survey choices
# Usage: ./update_awx_survey_records.sh <awx_url> <awx_token> <project_id> <job_template_id> <zone_name>

set -euo pipefail
AWX_URL="$1"
AWX_TOKEN="$2"
PROJECT_ID="$3"
JOB_TEMPLATE_ID="$4"
ZONE_NAME="$5"

# Fetch zone id from Cloudflare
CF_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
if [[ -z "$CF_TOKEN" ]]; then
  echo "CLOUDFLARE_API_TOKEN must be set in the environment"
  exit 1
fi
ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&per_page=1" | jq -r '.result[0].id')
if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
  echo "Zone not found: $ZONE_NAME"
  exit 1
fi

# Fetch DNS records (first 1000)
RECS=$(curl -s -H "Authorization: Bearer $CF_TOKEN" "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=1000" | jq -c '.result[]')

CHOICES=()
for r in $RECS; do
  name=$(echo "$r" | jq -r '.name')
  id=$(echo "$r" | jq -r '.id')
  CHOICES+=("{\"value\":\"$name\",\"label\":\"$name\"}")
done

CHOICES_JSON="[${CHOICES[*]}]"
# Print the JSON that can be posted to AWX API to update survey spec (manual step required to apply to template)
echo "$CHOICES_JSON"

# Optional: call AWX API to update template survey spec (commented out for safety)
# curl -s -X PATCH "$AWX_URL/api/v2/job_templates/$JOB_TEMPLATE_ID/" -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -d '{"survey_enabled": true, "survey_spec": [{"question_name": "record_name","question_description":"Select existing record","required":false,"type":"multiplechoice","variable":"survey_record_name","choices":'$CHOICES_JSON'}]}'
