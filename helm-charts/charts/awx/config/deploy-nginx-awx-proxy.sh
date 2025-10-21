#!/usr/bin/env bash
# Helper to deploy an nginx TLS reverse-proxy in the awx namespace using the generated certs
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")"/.. && pwd)
CERT_DIR="$ROOT_DIR/config/certs"

if [[ ! -f "$CERT_DIR/server.cert.pem" || ! -f "$CERT_DIR/server.key.pem" ]]; then
  echo "Missing certs. Run generate-awx-cert.sh first and target the correct host (e.g. 127.0.0.1)"
  exit 1
fi

kubectl -n awx delete secret nginx-awx-tls --ignore-not-found
kubectl -n awx create secret tls nginx-awx-tls \
  --cert="$CERT_DIR/server.cert.pem" \
  --key="$CERT_DIR/server.key.pem"

kubectl -n awx apply -f "$ROOT_DIR/config/nginx-awx-proxy.yaml"

echo "nginx-awx-proxy deployed. Port-forward with:"
echo "  kubectl -n awx port-forward svc/nginx-awx-proxy 8043:443"
