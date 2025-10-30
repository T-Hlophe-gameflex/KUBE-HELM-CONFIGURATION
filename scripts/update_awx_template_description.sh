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
NEW_DESCRIPTION="Comprehensive Cloudflare DNS and configuration management automation with modular task structure. Supports DNS record operations (create, update, delete, clone), domain management, zone settings configuration, and platform-wide synchronization. Features dynamic survey dropdowns, intelligent label management, and clean execution summaries for optimal user experience."

echo "Updating AWX Job Template #${AWX_TEMPLATE_ID} description..."

# Update the job template description
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/template_update_response.json \
  -X PATCH "http://${AWX_HOST}/api/v2/job_templates/${AWX_TEMPLATE_ID}/" \
  -H "Authorization: Basic $(echo -n "${AWX_USERNAME}:${AWX_PASSWORD}" | base64)" \
  -H "Content-Type: application/json" \
  -d "{\"description\": \"${NEW_DESCRIPTION}\"}")

if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
    echo "✓ Successfully updated job template description"
    echo "  Template ID: ${AWX_TEMPLATE_ID}"
    echo "  New Description: ${NEW_DESCRIPTION}"
else
    echo "✗ Failed to update job template description (HTTP ${HTTP_CODE})"
    if [[ -f /tmp/template_update_response.json ]]; then
        echo "Error response:"
        cat /tmp/template_update_response.json
    fi
    exit 1
fi

# Clean up
rm -f /tmp/template_update_response.json

echo "Job template description update completed successfully."