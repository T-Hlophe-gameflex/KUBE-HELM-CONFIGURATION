#!/usr/bin/env bash
set -euo pipefail

# update_awx_survey_records.sh
# - Fetches Cloudflare zones and dns records using CLOUDFLARE_API_TOKEN
# - Builds AWX survey specs for Manage Domain and Manage Record job templates
# - Optionally PATCHes AWX job templates to update survey_spec

usage(){
  cat <<EOF
Usage: $0 [--awx-url URL] [--awx-token TOKEN] [--cf-token TOKEN] [--patch-awx] [--dry-run]

Environment variables supported:
  AWX_URL (default http://127.0.0.1:8052)
  AWX_TOKEN
  CLOUDFLARE_API_TOKEN

Options:
  --patch-awx   : actually PATCH the AWX job templates (default: print preview)
  --dry-run     : alias for no --patch-awx
  -h|--help     : show this help

This script will locate AWX job templates named "Manage Domain (Cloudflare)" and "Manage Record (Cloudflare)" and update their surveys.
EOF
}

AWX_URL="${AWX_URL:-http://127.0.0.1:8052}"
#!/usr/bin/env bash
set -euo pipefail

# update_awx_survey_records.sh
# - Fetches Cloudflare zones and dns records using CLOUDFLARE_API_TOKEN
# - Builds AWX survey specs for Manage Domain and Manage Record job templates
# - Optionally PATCHes AWX job templates to update survey_spec

usage(){
  cat <<EOF
Usage: $0 [--awx-url URL] [--awx-token TOKEN] [--cf-token TOKEN] [--patch-awx] [--dry-run]

Environment variables supported:
  AWX_URL (default http://127.0.0.1:8052)
  AWX_TOKEN
  CLOUDFLARE_API_TOKEN

Options:
  --patch-awx   : actually PATCH the AWX job templates (default: print preview)
  --dry-run     : alias for no --patch-awx
  -h|--help     : show this help

This script will locate AWX job templates named "Manage Domain (Cloudflare)" and "Manage Record (Cloudflare)" and update their surveys.
EOF
}

AWX_URL="${AWX_URL:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-""}"
CF_TOKEN="${CLOUDFLARE_API_TOKEN:-""}"
PATCH_AWX=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --awx-url) AWX_URL="$2"; shift 2;;
    --awx-token) AWX_TOKEN="$2"; shift 2;;
    --cf-token) CF_TOKEN="$2"; shift 2;;
    --patch-awx) PATCH_AWX=true; shift;;
    --dry-run) PATCH_AWX=false; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "$CF_TOKEN" ]]; then
  echo "CLOUDFLARE_API_TOKEN not provided. Export CLOUDFLARE_API_TOKEN or pass --cf-token." >&2
  exit 2
fi

# AWX_TOKEN is only required if we're going to patch AWX
if [[ "$PATCH_AWX" == true && -z "$AWX_TOKEN" ]]; then
  echo "AWX_TOKEN not provided. Export AWX_TOKEN or pass --awx-token when using --patch-awx." >&2
  exit 2
fi

# Helper: call AWX API
awx_api(){
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"; shift || true
  local url="$AWX_URL/api/v2${path}"
  if [[ -n "$data" ]]; then
    curl -sS -X "$method" "$url" -H "Content-Type: application/json" -H "Authorization: Bearer $AWX_TOKEN" -d "$data"
  else
    curl -sS -X "$method" "$url" -H "Content-Type: application/json" -H "Authorization: Bearer $AWX_TOKEN"
  fi
}

# Helper: call Cloudflare API
cf_api(){
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"; shift || true
  local url="https://api.cloudflare.com/client/v4${path}"
  if [[ -n "$data" ]]; then
    curl -sS -X "$method" "$url" -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" -d "$data"
  else
    curl -sS -X "$method" "$url" -H "Authorization: Bearer $CF_TOKEN" -H "Accept: application/json"
  fi
}

echo "Fetching Cloudflare zones..."
ZONES_JSON=$(cf_api GET "/zones?per_page=50")

zone_count=$(echo "$ZONES_JSON" | jq '.result_info.total_count // (.result | length)')
if [[ -z "$zone_count" || "$zone_count" == "0" ]]; then
  echo "No zones found in Cloudflare account (or error). Dumping API response:" >&2
  echo "$ZONES_JSON" | jq '.' >&2
  exit 1
fi

# Build domain choices (newline separated for AWX multiplechoice 'choices' field)
DOMAINS=$(echo "$ZONES_JSON" | jq -r '.result[] | .name' | sort -u)
# Create a JSON array for domains
DOMAINS_JSON=$(printf "%s\n" "$DOMAINS" | jq -R -s -c 'split("\n") | map(select(length>0))')

# Build record choices across zones: "record_name (TYPE) -- zone"
RECORD_LINES=()
for z in $DOMAINS; do
  zid=$(echo "$ZONES_JSON" | jq -r --arg z "$z" '.result[] | select(.name == $z) | .id')
  # fetch dns records (limit to 1000)
  RECS=$(cf_api GET "/zones/$zid/dns_records?per_page=1000")
  # extract name and type
  mapfile -t lines < <(echo "$RECS" | jq -r '.result[] | "\(.name) (\(.type)) -- zone:\(.zone_name // "") -- id:\(.id)"') || true
  for l in "${lines[@]}"; do
    RECORD_LINES+=("$l")
  done
done

if [[ ${#RECORD_LINES[@]} -eq 0 ]]; then
  echo "No DNS records found; continuing with domain-only survey." >&2
fi

# Build records JSON array
RECORDS_JSON=$(printf "%s\n" "${RECORD_LINES[@]}" | sort -u | jq -R -s -c 'split("\n") | map(select(length>0))')

# Build AWX survey_spec JSON objects using jq and the prebuilt arrays
MANAGE_DOMAIN_SURVEY=$(jq -n --argjson choices "$DOMAINS_JSON" '[{question_name: "domain", question_description: "Select Cloudflare zone", required: true, answer_variable_name: "domain", type: "multiplechoice", choices: $choices}]')

MANAGE_RECORD_SURVEY=$(jq -n --argjson domains "$DOMAINS_JSON" --argjson records "$RECORDS_JSON" '[
  {question_name: "domain", question_description: "Select Cloudflare zone", required: true, answer_variable_name: "domain", type: "multiplechoice", choices: $domains},
  {question_name: "record_choice", question_description: "Select existing record (if editing/deleting)", required: false, answer_variable_name: "record_choice", type: "multiplechoice", choices: $records},
  {question_name: "action", question_description: "Action to perform", required: true, answer_variable_name: "cf_action", type: "multiplechoice", choices: ["create","update","delete" ], default: "create"},
  {question_name: "record_name", question_description: "Record name (for create/update)", required: false, answer_variable_name: "record_name", type: "text"},
  {question_name: "record_value", question_description: "Record value/content", required: false, answer_variable_name: "record_value", type: "text"},
  {question_name: "TTL", question_description: "Time to live (use 'auto' for managed TTL)", required: false, answer_variable_name: "record_ttl", type: "multiplechoice", choices: ["auto","60","300","3600","86400"], default: "auto"},
  {question_name: "Proxied", question_description: "Cloudflare proxy (CDN) enabled?", required: false, answer_variable_name: "record_proxied", type: "multiplechoice", choices: ["true","false"], default: "false"},
  {question_name: "argo", question_description: "Enable Argo?", required: false, answer_variable_name: "argo", type: "multiplechoice", choices: ["true","false"], default: "false"},
  {question_name: "Dry run", question_description: "Set to true to perform a dry-run; false to apply", required: false, answer_variable_name: "dry_run", type: "multiplechoice", choices: ["true","false"], default: "false"}
]')

# Print preview
echo "Manage Domain survey preview:" 
echo "$MANAGE_DOMAIN_SURVEY" | jq '.'

echo "Manage Record survey preview:"
echo "$MANAGE_RECORD_SURVEY" | jq '.'

if [[ "$PATCH_AWX" != true ]]; then
  echo "-- dry-run mode (not patching AWX). To apply, re-run with --patch-awx."
  exit 0
fi

# Find job template ids
JT_MANAGE_DOMAIN_ID=$(awx_api GET "/job_templates/?name=Manage%20Domain%20(Cloudflare)" | jq -r '.results[0].id // empty')
JT_MANAGE_RECORD_ID=$(awx_api GET "/job_templates/?name=Manage%20Record%20(Cloudflare)" | jq -r '.results[0].id // empty')

if [[ -z "$JT_MANAGE_DOMAIN_ID" || -z "$JT_MANAGE_RECORD_ID" ]]; then
  echo "Could not find one or both Job Templates in AWX. Ensure templates exist or run the bootstrap playbook first." >&2
  exit 2
fi

# Patch AWX template surveys
PATCH_PAYLOAD_DOMAIN=$(jq -nc --argjson survey "$MANAGE_DOMAIN_SURVEY" '{survey_enabled:true,survey_spec:$survey}')
PATCH_PAYLOAD_RECORD=$(jq -nc --argjson survey "$MANAGE_RECORD_SURVEY" '{survey_enabled:true,survey_spec:$survey}')

echo "Patching Manage Domain template id=$JT_MANAGE_DOMAIN_ID"
awx_api PATCH "/job_templates/$JT_MANAGE_DOMAIN_ID/" "$PATCH_PAYLOAD_DOMAIN" | jq '.'

echo "Patching Manage Record template id=$JT_MANAGE_RECORD_ID"
awx_api PATCH "/job_templates/$JT_MANAGE_RECORD_ID/" "$PATCH_PAYLOAD_RECORD" | jq '.'

echo "Survey population complete."
awx_api PATCH "/job_templates/$JT_MANAGE_DOMAIN_ID/" "$PATCH_PAYLOAD_DOMAIN" | jq '.'
