#!/bin/bash
set -euo pipefail

# Update AWX Job Template Description
# This script updates the description of the Cloudflare AWX job template with current functionality

# Configuration
AWX_HOST="${AWX_HOST:-localhost:8052}"
AWX_USERNAME="${AWX_USERNAME:-admin}"
AWX_PASSWORD="${AWX_PASSWORD:-password}"
AWX_TEMPLATE_ID="${AWX_TEMPLATE_ID:-21}"  # Cloudflare Template ID

# New description reflecting current capabilities
NEW_DESCRIPTION="Cloudflare configuration management. Streamlined DNS operations, zone settings, and domain administration with intelligent automation."

# New template name
NEW_NAME="Cloudflare - Automation"

echo "Updating AWX Job Template #${AWX_TEMPLATE_ID} name and description..."

# Get AWX admin password from Kubernetes
AWX_PASSWORD=$(kubectl get secret ansible-awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 -d)

# Update the job template description and name
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/template_update_response.json \
  -X PATCH "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/" \
  -u "admin:${AWX_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "{\"description\": \"${NEW_DESCRIPTION}\", \"name\": \"${NEW_NAME}\"}")

if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
    echo "✓ Successfully updated job template name and description"
    echo "  Template ID: ${AWX_TEMPLATE_ID}"
    echo "  New Name: ${NEW_NAME}"
    echo "  New Description: ${NEW_DESCRIPTION}"
else
    echo "✗ Failed to update job template (HTTP ${HTTP_CODE})"
    if [[ -f /tmp/template_update_response.json ]]; then
        echo "Error response:"
        cat /tmp/template_update_response.json
    fi
    exit 1
fi

# Clean up
rm -f /tmp/template_update_response.json

echo "Job template name and description update completed successfully."