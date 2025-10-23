#!/usr/bin/env bash
set -euo pipefail

# awx_cleanup_and_create_templates.sh
# - Cleans up old AWX jobs and temp job templates created during testing (dry-run by default)
# - Creates three job templates with surveys: manage-domain, manage-record, sync-domain-config
# - Attaches a Cloudflare credential to the created templates (if CREDENTIAL_ID is provided)
# - Optionally patches survey choices by calling awx_patch_survey.sh

usage(){
  cat <<EOF
Usage: $0 [--awx-url URL] [--awx-token TOKEN] [--cf-credential-id ID] [--dry-run] [--confirm]

Environment variables supported:
  AWX_URL (or --awx-url)
  AWX_TOKEN (or --awx-token)
  CF_CREDENTIAL_ID (or --cf-credential-id)  # AWX credential id that injects CLOUDFLARE_API_TOKEN into runner

Options:
  --dry-run    : print actions but don't perform destructive ops (default)
  --confirm    : actually perform deletions/creation

This script is conservative. It will only delete jobs/templates when --confirm is provided.
EOF
}

AWX_URL="${AWX_URL:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-""}"
CF_CREDENTIAL_ID="${CF_CREDENTIAL_ID:-""}"
DRY_RUN=true
CONFIRM=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --awx-url) AWX_URL="$2"; shift 2;;
    --awx-token) AWX_TOKEN="$2"; shift 2;;
    --cf-credential-id) CF_CREDENTIAL_ID="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift;;
    --confirm) DRY_RUN=false; CONFIRM=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "$AWX_TOKEN" ]]; then
  echo "AWX_TOKEN not provided. Export AWX_TOKEN or pass --awx-token." >&2
  exit 2
fi

echo "AWX_URL=$AWX_URL"
echo "DRY_RUN=$DRY_RUN"

# Helper: AWX API call
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

# 1) List recent jobs that look like tests (by name or project or created recently)
# We'll list jobs from the last 7 days that reference our project name in job_template__name

echo "Listing AWX jobs referencing 'Cloudflare-manage-record' or created in last 7 days..."
JOBS=$(awx_api GET "/jobs/?search=Cloudflare-manage-record" )
if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN - would examine jobs: $JOBS" | head -c 10000; echo
else
  echo "Jobs raw JSON:"; echo "$JOBS" | jq '.'
fi

# 2) Optionally delete known temporary job templates (we will search for names starting with 'tmp-' or 'test-')
TMP_TEMPLATES=$(awx_api GET "/job_templates/?name__startswith=tmp-" )
TMP_TEMPLATES_COUNT=$(echo "$TMP_TEMPLATES" | jq '.count')
if [[ "$TMP_TEMPLATES_COUNT" -gt 0 ]]; then
  echo "Found $TMP_TEMPLATES_COUNT templates starting with tmp-"
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN - templates: "
    echo "$TMP_TEMPLATES" | jq '.results[] | {id:.id, name:.name}'
  else
    for id in $(echo "$TMP_TEMPLATES" | jq -r '.results[] | .id'); do
      echo "Deleting template id=$id"
      awx_api DELETE "/job_templates/$id/"
    done
  fi
else
  echo "No tmp- templates found"
fi

# 3) Create job templates: manage-domain, manage-record, sync-domain-config
# We will create minimal templates that reference the existing project and playbook paths in repo
# NOTE: User must have a Project with id=1 and an Inventory with id=1 in AWX; this script will try to auto-discover sensible defaults
PROJECT_ID="1"
INVENTORY_ID="1"
CREDENTIALS_ARRAY="[]"
if [[ -n "$CF_CREDENTIAL_ID" ]]; then
  CREDENTIALS_ARRAY="[$CF_CREDENTIAL_ID]"
fi

create_template(){
  local name="$1"; local playbook="$2"; local description="$3"; local survey_spec="$4"
  local payload
  payload=$(jq -nc --arg name "$name" --arg playbook "$playbook" --arg desc "$description" --argjson creds "${CREDENTIALS_ARRAY}" '{name:$name,description:$desc,job_type:"run",inventory:1,project:1,playbook:$playbook,ask_variables_on_launch:false,credential:($creds|.[0])}')
  echo "Prepared payload for template $name: $payload"
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN - would create job template: $name"
  else
    res=$(awx_api POST "/job_templates/" "$payload")
    echo "Create response: $res" | jq '.'
    tid=$(echo "$res" | jq -r '.id')
    if [[ "$survey_spec" != "" && "$survey_spec" != "null" ]]; then
      echo "Patching survey for template id=$tid"
      awx_api PATCH "/job_templates/$tid/" "$(jq -nc --argjson survey "$survey_spec" '{survey_enabled:true,survey_spec:$survey}')"
    fi
  fi
}

# Minimal survey specs (these will be patched later by the survey population helper)
SURVEY_MANAGE_DOMAIN='null'
SURVEY_MANAGE_RECORD='null'
SURVEY_SYNC_DOMAIN='null'

create_template "Manage Domain (Cloudflare)" "automation/playbooks/cloudflare/wrapper-manage-record.yml" "Manage domain-level settings and records" "$SURVEY_MANAGE_DOMAIN"
create_template "Manage Record (Cloudflare)" "automation/playbooks/cloudflare/wrapper-manage-record.yml" "Create/Update/Delete DNS records" "$SURVEY_MANAGE_RECORD"
create_template "Sync Domain Config" "automation/playbooks/cloudflare/wrapper-manage-record.yml" "Sync domain configuration between zones" "$SURVEY_SYNC_DOMAIN"

echo "Templates creation step complete (dry_run=$DRY_RUN)."

cat <<EOF
Next steps:
- Use scripts/awx_patch_survey.sh or scripts/update_awx_survey_records.sh to populate survey choices for domain and record dropdowns.
- Ensure AWX project and inventory IDs are correct in the script (currently defaulting to 1).
- To actually create templates and delete tmp- templates, run this script with --confirm and valid AWX_TOKEN and (optionally) CF_CREDENTIAL_ID.
EOF
