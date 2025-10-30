#!/bin/bash

echo "🧪 Testing Survey Update Process"

# Get AWX password
AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 --decode)

# Get current survey
echo "1. Getting current survey..."
curl -s http://localhost:8052/api/v2/job_templates/21/survey_spec/ -u "admin:$AWX_PASSWORD" > /tmp/test_current.json

# Check if we got the survey
if jq -e '.spec' /tmp/test_current.json >/dev/null 2>&1; then
    echo "✅ Survey retrieved successfully"
    echo "   Survey name: $(jq -r '.name' /tmp/test_current.json)"
    echo "   Total fields: $(jq '.spec | length' /tmp/test_current.json)"
else
    echo "❌ Failed to retrieve survey"
    exit 1
fi

# Update domain choices
echo ""
echo "2. Updating domain choices..."
jq '.spec |= map(if .variable == "existing_domain" then .choices = ["test1.example.com", "test2.example.com", "[MANUAL_ENTRY]"] else . end)' /tmp/test_current.json > /tmp/test_updated.json

# Verify the update
echo "✅ Domain choices updated to:"
jq -r '.spec[] | select(.variable == "existing_domain") | .choices[]' /tmp/test_updated.json

# Update record choices
echo ""
echo "3. Updating record choices..."
jq '.spec |= map(if .variable == "existing_record" then .choices = ["www", "mail", "api", "[NONE]", "[REFRESH_NEEDED]"] else . end)' /tmp/test_updated.json > /tmp/test_final.json

# Verify the record update
echo "✅ Record choices updated to:"
jq -r '.spec[] | select(.variable == "existing_record") | .choices[]' /tmp/test_final.json

# Apply the update to AWX
echo ""
echo "4. Applying update to AWX..."
UPDATE_RESPONSE=$(curl -s -X POST http://localhost:8052/api/v2/job_templates/21/survey_spec/ \
    -H "Content-Type: application/json" \
    -u "admin:$AWX_PASSWORD" \
    -d @/tmp/test_final.json)

# Check if update was successful
if echo "$UPDATE_RESPONSE" | jq -e '.spec' >/dev/null 2>&1; then
    echo "✅ Survey update successful!"
    echo ""
    echo "📊 Current survey status:"
    echo "   • Domain choices: $(echo "$UPDATE_RESPONSE" | jq '.spec[] | select(.variable == "existing_domain") | .choices | length')"
    echo "   • Record choices: $(echo "$UPDATE_RESPONSE" | jq '.spec[] | select(.variable == "existing_record") | .choices | length')"
else
    echo "❌ Survey update failed"
    echo "Response: $UPDATE_RESPONSE"
    exit 1
fi

echo ""
echo "🎉 Test completed successfully!"