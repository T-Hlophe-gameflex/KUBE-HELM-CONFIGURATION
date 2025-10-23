#!/usr/bin/env bash
set -euo pipefail

# Safe helper to inspect Cloudflare DNS records for a zone, optionally delete one record
# and create a test record, then re-list to verify changes.
# Usage examples:
# 1) List records for zone example.com:
#    CLOUDFLARE_API_TOKEN=... ./scripts/cf_inspect_and_test.sh --zone example.com
# 2) Delete a record by id (prompts for confirmation):
#    CLOUDFLARE_API_TOKEN=... ./scripts/cf_inspect_and_test.sh --zone example.com --delete-id <record_id>
# 3) Create a test TXT record and re-list (prompts for confirmation):
#    CLOUDFLARE_API_TOKEN=... ./scripts/cf_inspect_and_test.sh --zone example.com --create-test
# 4) Do delete and create in one run and skip confirmations:
#    CLOUDFLARE_API_TOKEN=... ./scripts/cf_inspect_and_test.sh --zone example.com --delete-id <id> --create-test --yes

CF_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
ZONE_NAME=""
DELETE_ID=""
CREATE_TEST=false
SKIP_CONFIRM=false
RECORD_TYPE="TXT"
TEST_CONTENT="cf-inspect-$(date -u +%Y%m%dT%H%M%SZ)"
TEST_TTL=3600
TEST_PROXIED=false
API_BASE="https://api.cloudflare.com/client/v4"

print_usage(){
  sed -n '1,120p' "$0" | sed -n '1,40p'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zone)
      ZONE_NAME="$2"; shift 2;;
    --delete-id)
      DELETE_ID="$2"; shift 2;;
    --create-test)
      CREATE_TEST=true; shift 1;;
    --yes)
      SKIP_CONFIRM=true; shift 1;;
    --type)
      RECORD_TYPE="$2"; shift 2;;
    --content)
      TEST_CONTENT="$2"; shift 2;;
    --ttl)
      TEST_TTL="$2"; shift 2;;
    --proxied)
      TEST_PROXIED="$2"; shift 2;;
    -h|--help)
      print_usage; exit 0;;
    *)
      echo "Unknown argument: $1"; print_usage; exit 1;;
  esac
done

if [[ -z "$ZONE_NAME" ]]; then
  echo "ERROR: --zone is required"
  print_usage
  exit 2
fi

if [[ -z "$CF_TOKEN" ]]; then
  read -s -p "Enter Cloudflare API token (will not be echoed): " CF_TOKEN
  echo
  if [[ -z "$CF_TOKEN" ]]; then
    echo "No token provided; aborting."; exit 3
  fi
fi

cf_api(){
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}" || true
  local url="${API_BASE}${path}"
  if [[ -n "$data" ]]; then
    curl -sS -X "$method" "$url" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H 'Content-Type: application/json' \
      -d "$data"
  else
    curl -sS -X "$method" "$url" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H 'Content-Type: application/json'
  fi
}

echo "Finding zone id for: $ZONE_NAME"
zone_resp=$(cf_api GET "/zones?name=${ZONE_NAME}&per_page=1")
zone_id=$(echo "$zone_resp" | jq -r '.result[0].id // empty')
if [[ -z "$zone_id" ]]; then
  echo "Failed to find zone '${ZONE_NAME}'. Full API response:" >&2
  echo "$zone_resp" | jq
  exit 4
fi

echo "Zone ID: $zone_id"

echo
echo "== Current records (first 1000) =="
recs=$(cf_api GET "/zones/$zone_id/dns_records?per_page=1000")
echo "$recs" | jq '.result[] | {id: .id, name: .name, type: .type, content: .content, proxied: .proxied, ttl: .ttl}' || true

if [[ -n "$DELETE_ID" ]]; then
  echo
  echo "Requested delete of record id: $DELETE_ID"
  if [[ "$SKIP_CONFIRM" != true ]]; then
    read -p "Are you sure you want to DELETE record $DELETE_ID from zone $ZONE_NAME? (y/N) " resp
    case "$resp" in
      [yY][eE][sS]|[yY]) :;;
      *) echo "Skipping delete."; DELETE_ID="";;
    esac
  fi
  if [[ -n "$DELETE_ID" ]]; then
    echo "Deleting record $DELETE_ID..."
    del_resp=$(cf_api DELETE "/zones/$zone_id/dns_records/$DELETE_ID")
    echo "Delete response:"; echo "$del_resp" | jq
  fi
fi

if [[ "$CREATE_TEST" == true ]]; then
  echo
  echo "Requested to create a test record"
  if [[ "$SKIP_CONFIRM" != true ]]; then
    read -p "Create test ${RECORD_TYPE} record name 'cf-inspect-${ZONE_NAME}'? (y/N) " resp
    case "$resp" in
      [yY][eE][sS]|[yY]) :;;
      *) echo "Skipping create."; CREATE_TEST=false;;
    esac
  fi
  if [[ "$CREATE_TEST" == true ]]; then
    # Build record name as a subdomain to avoid colliding with root
    test_name="cf-inspect-${TEST_CONTENT}.${ZONE_NAME}"
    payload=$(jq -n --arg t "$RECORD_TYPE" --arg n "$test_name" --arg c "$TEST_CONTENT" --argjson ttl $TEST_TTL --argjson proxied "$TEST_PROXIED" \
      '{type:$t, name:$n, content:$c, ttl:$ttl, proxied:($proxied|test("^(true|false)$")|not) | if $proxied=="true" then true elif $proxied=="false" then false else false end }' 2>/dev/null) || true

    # If building with jq above failed (jq oddness), fallback to simple payload
    if [[ -z "$payload" || "$payload" == "null" ]]; then
      payload='{"type":"'$RECORD_TYPE'","name":"'$test_name'","content":"'$TEST_CONTENT'","ttl":'$TEST_TTL',"proxied":'$TEST_PROXIED'}'
    fi

    echo "Creating test record: $test_name -> $TEST_CONTENT"
    create_resp=$(cf_api POST "/zones/$zone_id/dns_records" "$payload")
    echo "Create response:"; echo "$create_resp" | jq
  fi
fi

# Re-list

echo
echo "== Records after operations (first 1000) =="
recs_after=$(cf_api GET "/zones/$zone_id/dns_records?per_page=1000")
echo "$recs_after" | jq '.result[] | {id: .id, name: .name, type: .type, content: .content, proxied: .proxied, ttl: .ttl}' || true

echo
echo "Done. If you expected changes but see none, ensure the token has sufficient permissions (Zone.DNS:Edit) and you're targeting the correct zone name."
