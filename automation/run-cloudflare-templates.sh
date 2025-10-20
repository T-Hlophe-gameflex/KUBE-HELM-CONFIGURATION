#!/usr/bin/env bash
set -euo pipefail
set -o allexport; source ../.env || true; set +o allexport

AWX_HOST=${AWX_HOST:-http://localhost:30080}

if ! kubectl get secret awx-admin-password -n awx >/dev/null 2>&1; then
  echo "Cannot find AWX admin password secret or kubectl not configured. Aborting."
  exit 1
fi

AWX_ADMIN_PASSWORD=$(kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode)
TOKEN_JSON=$(curl -s -u admin:$AWX_ADMIN_PASSWORD -H "Content-Type: application/json" -X POST $AWX_HOST/api/v2/tokens/ -d '{"description":"run-cloudflare-templates"}')
AWX_TOKEN=$(python3 - <<'PY'
import sys,json
try:
  j=json.load(sys.stdin)
  print(j.get('token',''))
except Exception:
  print('')
PY
<<<"$TOKEN_JSON")
if [ -z "$AWX_TOKEN" ]; then
  echo "Failed to create AWX token: $TOKEN_JSON"
  exit 1
fi
export AWX_TOKEN

PROJECT_NAME="Cloudflare DNS Project"
ENC_PROJECT_NAME=$(python3 - <<'PY'
import sys,urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
"$PROJECT_NAME")
PROJECT_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/projects/?name=$ENC_PROJECT_NAME" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'] if j.get('results') else '')
PY
)
if [ -z "$PROJECT_ID" ]; then echo "Project not found"; exit 1; fi

INVENTORY_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/inventories/?name=localhost&organization=1" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'] if j.get('results') else '')
PY
)
if [ -z "$INVENTORY_ID" ]; then echo "Inventory 'localhost' not found"; exit 1; fi

CFTYPE_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/credential_types/?name=Cloudflare%20API" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'] if j.get('results') else '')
PY
)
if [ -z "$CFTYPE_ID" ]; then echo "Cloudflare credential type not found"; exit 1; fi
CRED_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/credentials/?credential_type=$CFTYPE_ID&name=Cloudflare%20API%20Credentials" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'] if j.get('results') else '')
PY
)
if [ -z "$CRED_ID" ]; then echo "Cloudflare credential not found"; exit 1; fi

declare -A MAP
MAP["platform-dns-template.yml"]="platform-sync.yml"
MAP["global-dns-template.yml"]="global-standardize.yml"
MAP["domain-dns-template.yml"]="domain-standardize.yml"

for name in "${!MAP[@]}"; do
  pb_basename=${MAP[$name]}
  EXIST=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/job_templates/?name=$(python3 - <<'PY'
import sys,urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
"$name")" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j.get('count',0))
PY
)
  if [ "$EXIST" -gt 0 ]; then
    echo "Job template '$name' already exists; retrieving id."
    ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/job_templates/?name=$(python3 - <<'PY'
import sys,urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
"$name")" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'])
PY
)
  else
    echo "Creating job template '$name' -> playbook automation/tasks/cloudflare/$pb_basename"
    CREATE=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -H "Content-Type: application/json" -X POST "$AWX_HOST/api/v2/job_templates/" -d "{\"name\":\"$name\",\"job_type\":\"run\",\"inventory\":$INVENTORY_ID,\"project\":$PROJECT_ID,\"playbook\":\"automation/tasks/cloudflare/$pb_basename\",\"credential\":$CRED_ID}")
    ID=$(python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j.get('id',''))
PY
<<<"$CREATE")
    echo "Create response: $CREATE"
  fi
  if [ -z "$ID" ]; then echo "Failed to determine job template id for $name"; exit 1; fi
  echo "Launching $name (job_template id=$ID)"
  LAUNCH=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" -X POST "$AWX_HOST/api/v2/job_templates/$ID/launch/")
  JOB_ID=$(python3 - <<'PY'
import sys,json
try:
  j=json.load(sys.stdin)
  print(j.get('job',''))
except Exception:
  print('')
PY
<<<"$LAUNCH")
  if [ -z "$JOB_ID" ]; then echo "Failed to launch job for $name: $LAUNCH"; else
    echo "Launched job $JOB_ID for template $name"
  fi
done

echo "Done."
