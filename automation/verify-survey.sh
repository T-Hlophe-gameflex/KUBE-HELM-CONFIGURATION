#!/usr/bin/env bash
# Quick verification script to check if AWX survey is properly configured

set -euo pipefail

AWX_HOST="${AWX_HOST:-http://127.0.0.1:8052}"
AWX_TOKEN="${AWX_TOKEN:-e5VRSZHAwWshxPYbKjc5p3I0zmc1T9}"
TEMPLATE_NAME="Cloudflare AWX Survey"

echo "========================================"
echo "AWX Survey Verification"
echo "========================================"
echo ""

# Find template
TEMPLATE_ID=$(curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/?name=$(echo "$TEMPLATE_NAME" | sed 's/ /%20/g')" | \
  python3 -c 'import sys,json;j=json.load(sys.stdin);print(j["results"][0]["id"] if j.get("results") else "")')

if [ -z "$TEMPLATE_ID" ]; then
  echo "❌ Template '$TEMPLATE_NAME' not found"
  exit 1
fi

echo "✓ Template found: ID $TEMPLATE_ID"
echo ""

# Check survey status
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/" > /tmp/awx_template_check.json

ENABLED=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("survey_enabled", False))')
NAME=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("name", "N/A"))')
PLAYBOOK=$(python3 -c 'import json; j=json.load(open("/tmp/awx_template_check.json")); print(j.get("playbook", "N/A"))')

echo "Template Details:"
echo "  Name: $NAME"
echo "  Playbook: $PLAYBOOK"
echo "  Survey Enabled: $ENABLED"
echo ""

if [ "$ENABLED" = "True" ]; then
  echo "✓ Survey is ENABLED"
else
  echo "❌ Survey is NOT enabled"
  echo ""
  echo "Run this to enable: ./automation/apply-survey-post-method.sh"
  exit 1
fi

# Check actual survey spec
echo ""
echo "Checking survey questions..."
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "$AWX_HOST/api/v2/job_templates/$TEMPLATE_ID/survey_spec/" > /tmp/awx_survey_spec.json

python3 << 'EOF'
import json

try:
    with open('/tmp/awx_survey_spec.json') as f:
        survey = json.load(f)
    
    if survey and survey.get('spec'):
        questions = survey.get('spec', [])
        print(f"\n✓ Survey has {len(questions)} questions configured")
        print("\nSurvey Questions:")
        print("-" * 60)
        
        for i, q in enumerate(questions, 1):
            req = "REQUIRED" if q.get('required') else "Optional"
            qname = q.get('question_name')
            var = q.get('variable')
            qtype = q.get('type')
            print(f"{i}. {qname} ({var})")
            print(f"   Type: {qtype} | Status: {req}")
            
            if qtype == 'multiplechoice':
                choices = q.get('choices', [])
                if len(choices) <= 5:
                    print(f"   Choices: {', '.join(choices)}")
                else:
                    print(f"   Choices: {', '.join(choices[:3])}... (+{len(choices)-3} more)")
            
            if q.get('default'):
                print(f"   Default: {q.get('default')}")
            print()
        
        print("=" * 60)
        print("✅ SURVEY IS FULLY CONFIGURED AND READY!")
        print("=" * 60)
    else:
        print("\n❌ No survey questions found!")
        print("Run: ./automation/apply-survey-post-method.sh")
        exit(1)
        
except Exception as e:
    print(f"\n❌ Error checking survey: {e}")
    print("Run: ./automation/apply-survey-post-method.sh")
    exit(1)
EOF

if [ $? -ne 0 ]; then
  exit 1
fi

echo ""
echo "Next Steps to Test:"
echo "-" * 60
echo "1. Open AWX: http://127.0.0.1:8052"
echo "2. Go to: Templates → $TEMPLATE_NAME"
echo "3. Click 'Launch' button (rocket icon)"
echo "4. Fill in the survey form"
echo "5. Click 'Next' then 'Launch'"
echo ""
