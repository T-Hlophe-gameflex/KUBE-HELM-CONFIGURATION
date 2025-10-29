#!/usr/bin/env bash
set -euo pipefail

# Configuration
AWX_HOST="${AWX_HOST:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-e5VRSZHAwWshxPYbKjc5p3I0zmc1T9}"
TEMPLATE_ID=21
SURVEY_JSON="automation/unified-cloudflare-awx-survey.json"

echo "=========================================="
echo "Applying Survey to AWX Template (Method 2)"
echo "=========================================="
echo ""

# Step 1: Create survey payload
echo "Step 1: Creating survey payload..."
python3 << 'EOF' > /tmp/survey_payload.json
import json

with open("automation/unified-cloudflare-awx-survey.json") as f:
    spec = json.load(f)

survey_payload = {
    "name": "Cloudflare Survey",
    "description": "Survey for Cloudflare DNS management",
    "spec": spec
}

with open("/tmp/survey_payload.json", "w") as out:
    json.dump(survey_payload, out, indent=2)

print(f"✓ Survey payload created with {len(spec)} questions")
EOF

# Step 2: Validate JSON
echo ""
echo "Step 2: Validating survey JSON..."
python3 -m json.tool /tmp/survey_payload.json > /dev/null && echo "✓ JSON is valid"

# Step 3: POST to survey_spec endpoint
echo ""
echo "Step 3: POSTing survey to AWX..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -H "Authorization: Bearer $AWX_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/" \
  -d @/tmp/survey_payload.json)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')

echo "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "✓ Survey successfully applied!"
  echo ""
  echo "$BODY" | python3 -c '
import sys, json
try:
    j = json.load(sys.stdin)
    print("Survey Details:")
    print(f"  Name: {j.get(\"name\", \"N/A\")}")
    print(f"  Description: {j.get(\"description\", \"N/A\")}")
    print(f"  Questions: {len(j.get(\"spec\", []))}")
    print("")
    print("Questions configured:")
    for i, q in enumerate(j.get("spec", []), 1):
        print(f"  {i}. {q.get(\"question_name\")} ({q.get(\"variable\")})")
except:
    print("Response:", sys.stdin.read())
'
else
  echo "❌ Failed to apply survey"
  echo ""
  echo "Response:"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
  exit 1
fi

# Step 4: Verify survey was saved
echo ""
echo "Step 4: Verifying survey was saved..."
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/" | \
  python3 -c '
import sys, json
j = json.load(sys.stdin)
enabled = j.get("survey_enabled", False)
has_spec = j.get("survey_spec") is not None

print(f"Survey Enabled: {enabled}")
print(f"Survey Spec Present: {has_spec}")

if enabled and has_spec:
    spec = j.get("survey_spec", {})
    if isinstance(spec, dict):
        print(f"✓ Survey is active with {len(spec.get(\"spec\", []))} questions")
    else:
        print("✓ Survey is enabled")
else:
    print("⚠️  Warning: Survey may not be properly configured")
'

echo ""
echo "=========================================="
echo "Done! Check AWX UI to test the survey"
echo "URL: $AWX_HOST/#/templates/job_template/$TEMPLATE_ID"
echo "=========================================="
