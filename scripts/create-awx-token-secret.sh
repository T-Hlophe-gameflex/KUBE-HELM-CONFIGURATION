#!/usr/bin/env bash
set -euo pipefail

# Create a persistent AWX API token and store it as k8s secret `awx-api-token` in the awx namespace.
# Usage: ./scripts/create-awx-token-secret.sh <admin-username> <admin-password> [k8s-namespace]

ADMIN_USER=${1:-admin}
ADMIN_PASS=${2:-}
NAMESPACE=${3:-awx}

if [ -z "$ADMIN_PASS" ]; then
  echo "Provide admin password as second argument or set ADMIN_PASS environment variable"
  exit 1
fi

# Create token via AWX API (assumes awx service available at ansible-awx-service in-cluster)
TOKEN_JSON=$(kubectl -n "$NAMESPACE" run -i --rm --restart=Never curltmp --image=curlimages/curl:8.1.2 --command -- sh -c "echo '{}' > /tmp/payload.json; curl -s -S -u $ADMIN_USER:$ADMIN_PASS -H 'Content-Type: application/json' -X POST http://ansible-awx-service/api/v2/tokens/ -d @/tmp/payload.json")
TOKEN=$(echo "$TOKEN_JSON" | python -c "import sys,json;print(json.load(sys.stdin).get('token'))")

if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
  echo "Failed to create token; response: $TOKEN_JSON"
  exit 2
fi

# Store as secret
kubectl -n "$NAMESPACE" delete secret awx-api-token --ignore-not-found
kubectl -n "$NAMESPACE" create secret generic awx-api-token --from-literal=token="$TOKEN"

echo "Created secret $NAMESPACE/awx-api-token"

echo "Token: $TOKEN"