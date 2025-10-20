#!/usr/bin/env bash
# Fetch and list all Cloudflare domains (zones) using Bearer token from .env

set -e

# Load .env variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "CLOUDFLARE_API_TOKEN not set."
  exit 1
fi

ACCOUNT_ID="4c38e2ac00166dc5aa6d0647285ff90a"

curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" | \
  jq '.result[] | {id: .id, name: .name, status: .status}'
