#!/usr/bin/env bash
set -euo pipefail

# Config (allow override via env)
AWX_HOST="${AWX_HOST:-http://localhost:8043}"
AWX_USER="${AWX_USER:-admin}"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --sync) DRY_RUN=false ;;
  esac
done

AWX_PASS=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || true)
if [ -z "$AWX_PASS" ]; then
  echo "Could not get AWX admin password from Kubernetes. Is kubectl configured and the secret present?"
  exit 1
fi

TOKEN_JSON=$(curl -s -u "$AWX_USER:$AWX_PASS" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/tokens/" -d '{"description":"cloudflare-automation"}')
AWX_TOKEN=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("token",""))' <<< "$TOKEN_JSON")
if [ -z "$AWX_TOKEN" ]; then echo "Failed to get AWX token"; exit 1; fi

awx_get() { curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST$1"; }

INVENTORY_ID=$(awx_get "/api/v2/inventories/?name=localhost" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')
PROJECT_ID=$(awx_get "/api/v2/projects/?name=Cloudflare%20DNS%20Project" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')
CRED_ID=$(awx_get "/api/v2/credentials/?name=Cloudflare%20API%20Credentials" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j["results"] else "")')

if [ -z "$INVENTORY_ID" ] || [ -z "$PROJECT_ID" ] || [ -z "$CRED_ID" ]; then
  echo "Missing required AWX resource (inventory, project, or credential)."
  exit 1
fi

PLAYBOOK_PATH_PREFIX="automation/playbooks/cloudflare/"
TEMPLATE_NAME="unified-cloudflare-awx-template"
PLAYBOOK_FILE="wrapper-unified-cloudflare.yml"

EXIST=$(awx_get "/api/v2/job_templates/?name=$TEMPLATE_NAME" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("count",0))')
if [ "$EXIST" -gt 0 ]; then
  echo "Job template '$TEMPLATE_NAME' already exists. Will PATCH to ensure settings are up-to-date."
  ID=$(awx_get "/api/v2/job_templates/?name=$TEMPLATE_NAME" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"])')
  if [ "$DRY_RUN" = false ]; then
    PATCH_PAYLOAD=$(printf '{"project":%d, "playbook":"%s", "credential":%d}' "$PROJECT_ID" "${PLAYBOOK_PATH_PREFIX}$PLAYBOOK_FILE" "$CRED_ID")
    curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X PATCH "$AWX_HOST/api/v2/job_templates/$ID/" -d "$PATCH_PAYLOAD" >/dev/null || true
    echo "Patched existing job_template $ID"
  else
    echo "DRY-RUN: would PATCH job_template $ID with playbook ${PLAYBOOK_PATH_PREFIX}$PLAYBOOK_FILE"
  fi
else
  echo "Creating job template '$TEMPLATE_NAME'..."
  if [ "$DRY_RUN" = false ]; then
    CREATE=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/job_templates/" \
      -d "{\"name\":\"$TEMPLATE_NAME\",\"job_type\":\"run\",\"inventory\":$INVENTORY_ID,\"project\":$PROJECT_ID,\"playbook\":\"${PLAYBOOK_PATH_PREFIX}$PLAYBOOK_FILE\",\"credential\":$CRED_ID}")
    ID=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("id",""))' <<< "$CREATE")
    echo "Create response: $CREATE"
  else
    echo "DRY-RUN: would create job_template '$TEMPLATE_NAME' with playbook ${PLAYBOOK_PATH_PREFIX}$PLAYBOOK_FILE"
    ID="(dry-run)"
  fi
fi
if [ -z "$ID" ]; then echo "Failed to get job template id for $TEMPLATE_NAME"; exit 1; fi
echo "Launching $TEMPLATE_NAME (job_template id=$ID)"
LAUNCH=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -X POST "$AWX_HOST/api/v2/job_templates/$ID/launch/")
JOB_ID=$(python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("job",""))' <<< "$LAUNCH")
if [ -z "$JOB_ID" ]; then echo "Failed to launch job for $TEMPLATE_NAME: $LAUNCH"; else
  echo "Launched job $JOB_ID for template $TEMPLATE_NAME"
fi

echo "Done."
