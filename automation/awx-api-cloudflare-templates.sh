#!/usr/bin/env bash
set -euo pipefail


 # Config (allow override via env)
 AWX_HOST="${AWX_HOST:-http://localhost:8043}"
 AWX_USER="${AWX_USER:-admin}"
 DRY_RUN=false

 # Simple CLI arg parsing for --dry-run
 for arg in "$@"; do
   case "$arg" in
     --dry-run) DRY_RUN=true ;;
   esac
 done



AWX_PASS=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || true)
if [ -z "$AWX_PASS" ]; then
  echo "Could not get AWX admin password from Kubernetes. Is kubectl configured and the secret present?"
  exit 1
fi

# Get API token
TOKEN_JSON=$(curl -s -u "$AWX_USER:$AWX_PASS" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/tokens/" -d '{"description":"cloudflare-automation"}')
AWX_TOKEN=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("token",""))' <<< "$TOKEN_JSON")
if [ -z "$AWX_TOKEN" ]; then echo "Failed to get AWX token"; exit 1; fi

# Helper for GET with token
awx_get() { curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST$1"; }

# Find IDs
echo "Finding inventory, project, credential IDs..."
INVENTORY_ID=$(awx_get "/api/v2/inventories/?name=localhost" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')
PROJECT_ID=$(awx_get "/api/v2/projects/?name=Cloudflare%20DNS%20Project" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')
CRED_ID=$(awx_get "/api/v2/credentials/?name=Cloudflare%20API%20Credentials" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')

if [ -z "$INVENTORY_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$CRED_ID" ]; then
  echo "Missing required AWX resource (inventory, project, or credential)."
  exit 1
fi

# Set this to the playbook path prefix relative to your AWX project root
PLAYBOOK_PATH_PREFIX="automation/tasks/cloudflare/"
# If your AWX project root is the repo root, use: PLAYBOOK_PATH_PREFIX="automation/tasks/cloudflare/"
# If your AWX project root is automation/tasks/cloudflare, use: PLAYBOOK_PATH_PREFIX=""

declare -A MAP
MAP["platform-dns-template.yml"]="platform-sync.yml"
MAP["global-dns-template.yml"]="global-standardize.yml"

for name in "${!MAP[@]}"; do
  pb_basename=${MAP[$name]}
  # Check if template exists
  EXIST=$(awx_get "/api/v2/job_templates/?name=$name" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("count",0))')
  if [ "$EXIST" -gt 0 ]; then
    echo "Job template '$name' already exists. Will PATCH to ensure settings are up-to-date."
    ID=$(awx_get "/api/v2/job_templates/?name=$name" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"])')
    # Patch the existing template to ensure playbook/project/credential are set (idempotent)
    if [ "$DRY_RUN" = false ]; then
      PATCH_PAYLOAD=$(printf '{"project":%d, "playbook":"%s", "credential":%d}' "$PROJECT_ID" "${PLAYBOOK_PATH_PREFIX}$pb_basename" "$CRED_ID")
      curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X PATCH "$AWX_HOST/api/v2/job_templates/$ID/" -d "$PATCH_PAYLOAD" >/dev/null || true
      echo "Patched existing job_template $ID"
    else
      echo "DRY-RUN: would PATCH job_template $ID with playbook ${PLAYBOOK_PATH_PREFIX}$pb_basename"
    fi
  else
    echo "Creating job template '$name'..."
    if [ "$DRY_RUN" = false ]; then
      CREATE=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/job_templates/" \
        -d "{\"name\":\"$name\",\"job_type\":\"run\",\"inventory\":$INVENTORY_ID,\"project\":$PROJECT_ID,\"playbook\":\"${PLAYBOOK_PATH_PREFIX}$pb_basename\",\"credential\":$CRED_ID}")
      ID=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("id",""))' <<< "$CREATE")
      echo "Create response: $CREATE"
    else
      echo "DRY-RUN: would create job_template '$name' with playbook ${PLAYBOOK_PATH_PREFIX}$pb_basename"
      ID="(dry-run)"
    fi
  fi
  if [ -z "$ID" ]; then echo "Failed to get job template id for $name"; exit 1; fi
  echo "Launching $name (job_template id=$ID)"
  LAUNCH=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -X POST "$AWX_HOST/api/v2/job_templates/$ID/launch/")
  JOB_ID=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("job",""))' <<< "$LAUNCH")
  if [ -z "$JOB_ID" ]; then echo "Failed to launch job for $name: $LAUNCH"; else
    echo "Launched job $JOB_ID for template $name"
  fi
done

echo "Done."
