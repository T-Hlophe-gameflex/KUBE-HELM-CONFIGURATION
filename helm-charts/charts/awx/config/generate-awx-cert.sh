#!/usr/bin/env bash
# generate-awx-cert.sh
# Lightweight helper to create a self-signed CA and a server cert signed by that CA.
# Outputs base64-encoded CA cert so you can set AWX_CA_CERT or create a k8s secret.
# Usage: ./generate-awx-cert.sh --host awx.local --out-dir ./certs
set -euo pipefail
HOST="${1:-127.0.0.1}"
OUT_DIR="${2:-./certs}"
mkdir -p "$OUT_DIR"
CA_KEY="$OUT_DIR/ca.key.pem"
CA_CERT="$OUT_DIR/ca.cert.pem"
SERVER_KEY="$OUT_DIR/server.key.pem"
SERVER_CSR="$OUT_DIR/server.csr.pem"
SERVER_CERT="$OUT_DIR/server.cert.pem"

echo "Generating CA and server cert for host: $HOST"

# Create CA
openssl genrsa -out "$CA_KEY" 4096
openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 -subj "/CN=local-awx-ca" -out "$CA_CERT"

# Create server key and CSR with SAN
openssl genrsa -out "$SERVER_KEY" 2048
cat > "$OUT_DIR/openssl.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = dn
[ dn ]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = ${HOST}
IP.1 = ${HOST}
EOF

openssl req -new -key "$SERVER_KEY" -subj "/CN=${HOST}" -out "$SERVER_CSR" -config "$OUT_DIR/openssl.cnf"

# Sign server CSR with CA
cat > "$OUT_DIR/v3ext.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = ${HOST}
IP.1 = ${HOST}
EOF

openssl x509 -req -in "$SERVER_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$SERVER_CERT" -days 3650 -sha256 -extfile "$OUT_DIR/v3ext.cnf"

echo "Wrote certs to $OUT_DIR"

echo "--- BEGIN BASE64 CA CERT ---"
base64 -w 0 "$CA_CERT"
echo ""
echo "--- END BASE64 CA CERT ---"

echo "To create a Kubernetes secret for AWX token and CA, run (example):"
echo "kubectl create secret generic awx-ca --from-file=ca.crt=$CA_CERT -n awx"
echo "or to store base64 into AWX_CA_CERT env: export AWX_CA_CERT=\$(base64 -w0 $CA_CERT)"
chmod +x "$OUT_DIR" || true

exit 0
