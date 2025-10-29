#!/usr/bin/env bash
set -euo pipefail

# Configuration
AWX_HOST="${AWX_HOST:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-e5VRSZHAwWshxPYbKjc5p3I0zmc1T9}"
TEMPLATE_NAME="Cloudflare AWX Survey"
SURVEY_JSON="automation/unified-cloudflare-awx-survey.json"

echo "================================================"
echo "Applying Survey to AWX Template"
echo "================================================"
echo ""

# Function to make API calls
awx_api() {
  curl -s -H "Authorization: Bearer $AWX_TOKEN" \
       -H "Content-Type: application/json" \
       "$AWX_HOST$1" "${@:2}"
}

# Step 1: Find the template ID
echo "Step 1: Finding template '$TEMPLATE_NAME'..."
TEMPLATE_RESPONSE=$(awx_api "/api/v2/job_templates/?name=$(echo "$TEMPLATE_NAME" | sed 's/ /%20/g')")
TEMPLATE_ID=$(echo "$TEMPLATE_RESPONSE" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j.get("results") and len(j["results"]) > 0 else "")')

if [ -z "$TEMPLATE_ID" ]; then
  echo "❌ Error: Template '$TEMPLATE_NAME' not found!"
  exit 1
fi

echo "✓ Found template with ID: $TEMPLATE_ID"
echo ""

# Step 2: Check if survey file exists
echo "Step 2: Checking survey file..."
if [ ! -f "$SURVEY_JSON" ]; then
  echo "❌ Error: Survey file not found: $SURVEY_JSON"
  exit 1
fi
echo "✓ Survey file found: $SURVEY_JSON"
echo ""

# Step 3: Load and validate survey JSON
echo "Step 3: Loading survey specification..."
SURVEY_SPEC=$(python3 << 'PYTHON_SCRIPT'
import json
import sys

try:
    with open('automation/unified-cloudflare-awx-survey.json', 'r') as f:
        spec = json.load(f)
    
    # Create the survey spec payload
    survey_payload = {
        "name": "Cloudflare Survey",
        "description": "Survey for Cloudflare DNS management",
        "spec": spec
    }
    
    print(json.dumps(survey_payload))
    sys.exit(0)
except Exception as e:
    print(f"Error loading survey: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
)

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to load survey JSON"
  exit 1
fi

echo "✓ Survey specification loaded successfully"
echo "  Questions count: $(echo "$SURVEY_SPEC" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(len(j.get("spec", [])))')"
echo ""

# Step 4: Apply survey to template
echo "Step 4: Applying survey to template..."
PATCH_PAYLOAD=$(python3 << PYTHON_SCRIPT
import json
import sys

survey_spec = json.loads('''$SURVEY_SPEC''')
payload = {
    "survey_enabled": True,
    "survey_spec": survey_spec
}
print(json.dumps(payload))
PYTHON_SCRIPT
)

RESPONSE=$(awx_api "/api/v2/job_templates/$TEMPLATE_ID/" \
  -X PATCH \
  -d "$PATCH_PAYLOAD")

# Check if successful
SUCCESS=$(echo "$RESPONSE" | python3 -c 'import sys,json;j=json.load(sys.stdin);print("yes" if j.get("id") else "no")')

if [ "$SUCCESS" = "yes" ]; then
  echo "✓ Survey successfully applied to template!"
  echo ""
  echo "================================================"
  echo "Summary"
  echo "================================================"
  echo "Template ID: $TEMPLATE_ID"
  echo "Template Name: $TEMPLATE_NAME"
  echo "Survey Enabled: $(echo "$RESPONSE" | python3 -c 'import sys,json;j=json.load(sys.stdin);print(j.get("survey_enabled", False))')"
  echo ""
  echo "✓ Done! You can now launch the template from AWX UI."
  echo "  The survey form will appear when you click 'Launch'."
  echo ""
else
  echo "❌ Error: Failed to apply survey"
  echo "Response:"
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  exit 1
fi
