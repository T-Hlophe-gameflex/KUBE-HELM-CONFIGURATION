#!/usr/bin/env bash
set -euo pipefail
set -o allexport; source ../.env || true; set +o allexport

AWX_HOST=${AWX_HOST:-http://localhost:30080}

echo "=== kubectl: get pods -n awx ==="
kubectl get pods -n awx -o wide || true
echo
echo "=== kubectl: get svc -n awx ==="
kubectl get svc -n awx -o wide || true
echo
echo "=== port-forward processes ==="
ps aux | grep -E 'kubectl .*port-forward' | grep -v grep || true
echo
echo "=== AWX API root ==="
curl -s -I ${AWX_HOST}/api/ || true
echo

AWX_ADMIN_PASSWORD=$(kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 --decode 2>/dev/null || true)
if [ -z "$AWX_ADMIN_PASSWORD" ]; then
  echo "AWX admin password not found (kubectl may not be configured). Skipping AWX API queries."
  exit 0
fi

TOKEN_JSON=$(curl -s -u admin:$AWX_ADMIN_PASSWORD -H "Content-Type: application/json" -X POST $AWX_HOST/api/v2/tokens/ -d '{"description":"diag-token"}')
TOKEN=$(python3 - <<'PY'
import sys,json
try:
  j=json.load(sys.stdin)
  print(j.get('token',''))
except Exception:
  print('')
PY
<<<"$TOKEN_JSON")

if [ -z "$TOKEN" ]; then
  echo "Failed to create AWX token: $TOKEN_JSON"
  exit 0
fi

echo "AWX token created (masked): ${TOKEN:0:8}..."

echo "=== AWX Projects ==="
curl -s -H "Authorization: Bearer $TOKEN" $AWX_HOST/api/v2/projects/?page_size=50 | python3 -m json.tool || true
echo
echo "=== AWX Job Templates ==="
curl -s -H "Authorization: Bearer $TOKEN" $AWX_HOST/api/v2/job_templates/?page_size=200 | python3 -m json.tool || true
echo
echo "=== AWX Recent Jobs (last 50) ==="
curl -s -H "Authorization: Bearer $TOKEN" "$AWX_HOST/api/v2/jobs/?page_size=50&order_by=-finished" | python3 -m json.tool || true
echo

CF_PROJ_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$AWX_HOST/api/v2/projects/?name=Cloudflare%20DNS%20Project" | python3 - <<'PY'
import sys,json
j=json.load(sys.stdin)
print(j['results'][0]['id'] if j.get('results') else '')
PY
)

if [ -n "$CF_PROJ_ID" ]; then
  echo "=== Playbooks for Cloudflare DNS Project (id=$CF_PROJ_ID) ==="
  curl -s -H "Authorization: Bearer $TOKEN" $AWX_HOST/api/v2/projects/$CF_PROJ_ID/playbooks/ | python3 -m json.tool || true
else
  echo "Cloudflare DNS Project not found in AWX projects list."
fi

echo "Diagnostics complete."
