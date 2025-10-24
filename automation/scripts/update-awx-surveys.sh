#!/usr/bin/env bash
set -euo pipefail

# update-awx-surveys.sh
# Fetch Cloudflare zones for the account associated with the CF API token
# and update AWX job template surveys (IDs 9..13) to populate the domain dropdown.
#
# Requirements:
# - jq
# - curl
# - An AWX token available in /tmp/awx_env.sh as AWX_TOKEN=...
# - Cloudflare API token available in CF_API_TOKEN environment variable, or the
#   script will prompt for it interactively (it will not echo the token).

AWX_API="http://localhost:8080/api/v2"
TEMPLATE_IDS=(9 10 11 12 13)

if [[ -f /tmp/awx_env.sh ]]; then
  # shellcheck disable=SC1090
  source /tmp/awx_env.sh
fi

if [[ -z "${AWX_TOKEN:-}" ]]; then
  echo "ERROR: AWX_TOKEN not found. Please export AWX_TOKEN or source /tmp/awx_env.sh"
  exit 1
fi

# Read token if not provided, then sanitize (remove surrounding quotes/newlines)
if [[ -z "${CF_API_TOKEN:-}" ]]; then
  read -r -s -p "Enter Cloudflare API token (will not be echoed): " CF_API_TOKEN
  echo
fi
# remove CRLF/newlines
# remove CRLF/newlines
CF_API_TOKEN="${CF_API_TOKEN//$'\r'/}"
CF_API_TOKEN="${CF_API_TOKEN//$'\n'/}"
# strip surrounding single or double quotes if present
CF_API_TOKEN="${CF_API_TOKEN#\"}"
CF_API_TOKEN="${CF_API_TOKEN%\"}"
CF_API_TOKEN="${CF_API_TOKEN#\'}"
CF_API_TOKEN="${CF_API_TOKEN%\'}"

echo "Using provided Cloudflare token to list zones..."

echo "Fetching zones from Cloudflare..."
# Use the verify endpoint to discover account ID if needed? We assume the token has access to list zones.
CF_ZONES_JSON=$(curl -sS -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json")

if ! printf '%s' "$CF_ZONES_JSON" | jq -e '.success == true' >/dev/null 2>&1; then
  echo "Failed to fetch zones from Cloudflare:" >&2
  printf '%s' "$CF_ZONES_JSON" | jq -r '.errors[]?.message // "(no message)"' || true
  exit 2
fi

# Extract zone names and build newline-separated choices string (AWX expects choices separated by newlines)
# Use paste with $'\n' so the shell builds a literal newline between entries
ZONE_CHOICES=$(jq -r '.result[].name' <<< "$CF_ZONES_JSON" | paste -sd $'\n' -)

if [[ -z "$ZONE_CHOICES" ]]; then
  echo "No zones found for this account. Exiting."
  exit 0
fi

echo "Found zones:"
jq -r '.result[].name' <<< "$CF_ZONES_JSON"

# For embedding into JSON string values we must escape newlines as '\\n'
ZONE_CHOICES_ESCAPED=${ZONE_CHOICES//$'\n'/\\n}
ACTION_CHOICES_ESCAPED="manage\\nstandardize\\nsync\\ncreate\\nupdate\\ndelete"
RECORD_TYPE_CHOICES_ESCAPED="A\\nAAAA\\nCNAME\\nTXT\\nMX\\nSRV\\nPTR\\nNS"
PROXIED_CHOICES_ESCAPED="true\\nfalse"

# Build a minimal survey_spec JSON where survey_domain choices are populated.
read -r -d '' SURVEY_SPEC <<EOF || true
{
  "name": "Cloudflare Params",
  "description": "Parameters for Cloudflare DNS playbooks",
  "spec": [
    {
      "variable": "survey_domain",
      "question_name": "Domain",
      "question_description": "Select target domain",
      "type": "multiplechoice",
      "choices": "$ZONE_CHOICES_ESCAPED",
      "default": "",
      "required": true,
      "min": 0,
      "max": 1
    },
    {
      "variable": "cf_action",
      "question_name": "Action",
      "question_description": "Select action",
      "type": "multiplechoice",
  "choices": "$ACTION_CHOICES_ESCAPED",
      "default": "manage",
      "required": true,
      "min": 0,
      "max": 1
    },
    {
      "variable": "record_name",
      "question_name": "Record name",
      "question_description": "Record name (e.g. www)",
      "type": "text",
      "default": "",
      "required": false,
      "min": 0,
      "max": 128
    },
    {
      "variable": "record_type",
      "question_name": "Record type",
      "question_description": "A/CNAME/TXT",
      "type": "multiplechoice",
  "choices": "$RECORD_TYPE_CHOICES_ESCAPED",
      "default": "A",
      "required": false,
      "min": 0,
      "max": 1
    },
    {
      "variable": "record_value",
      "question_name": "Record value",
      "question_description": "Record content/IP",
      "type": "text",
      "default": "",
      "required": false,
      "min": 0,
      "max": 256
    },
    {
      "variable": "record_ttl",
      "question_name": "TTL",
      "question_description": "TTL seconds or \"auto\"",
      "type": "text",
      "default": "auto",
      "required": false,
      "min": 0,
      "max": 64
    },
    {
      "variable": "record_proxied",
      "question_name": "Proxied",
      "question_description": "Proxy via Cloudflare",
      "type": "multiplechoice",
  "choices": "$PROXIED_CHOICES_ESCAPED",
      "default": "false",
      "required": false,
      "min": 0,
      "max": 1
    }
    ,
    {
      "variable": "dry_run",
      "question_name": "Dry run",
      "question_description": "Set to true to perform a dry-run; false to apply",
      "type": "multiplechoice",
      "choices": "true\\nfalse",
      "default": "false",
      "required": false,
      "min": 0,
      "max": 1
    }
  ]
}
EOF

echo "Updating AWX job templates: ${TEMPLATE_IDS[*]}"

for id in "${TEMPLATE_IDS[@]}"; do
  echo "- Updating template $id survey_spec..."
  HTTP_STATUS=$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "$AWX_API/job_templates/$id/survey_spec/" \
    -H "Authorization: Bearer $AWX_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$SURVEY_SPEC") || true
  # curl in -s mode prints errors to stderr; check via GET to confirm
  if [[ $HTTP_STATUS =~ ^2 ]]; then
    echo "  survey_spec POST returned $HTTP_STATUS"
  else
    echo "  survey_spec POST returned $HTTP_STATUS (will attempt to PATCH in case it exists)"
  fi

  # Ensure surveys are enabled and ask variables on launch
  curl -sS -X PATCH "$AWX_API/job_templates/$id/" \
    -H "Authorization: Bearer $AWX_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"survey_enabled": true, "ask_variables_on_launch": true}' \
    | jq -r '.id, .survey_enabled, .ask_variables_on_launch' || true
done

echo "Done. Please trigger an AWX Project Update (or wait) so job templates pick up any repository changes."

exit 0
