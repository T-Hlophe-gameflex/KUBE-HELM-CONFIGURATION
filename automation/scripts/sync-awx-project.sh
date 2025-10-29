#!/bin/bash
#
# Sync AWX Project to Pull Latest Playbook Changes
#
# This script syncs the AWX project to pull the latest playbooks from Git
#

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          AWX Project Sync - Pull Latest Playbooks             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get AWX service URL
AWX_SERVICE=$(kubectl get svc -n awx | grep ansible-awx-service | awk '{print $1}')
if [ -z "$AWX_SERVICE" ]; then
    echo "❌ Error: AWX service not found in namespace 'awx'"
    echo "   Make sure AWX is deployed and running"
    exit 1
fi

echo "✓ Found AWX service: $AWX_SERVICE"
echo ""

# Get AWX admin password
AWX_ADMIN_PASSWORD=$(kubectl get secret -n awx ansible-awx-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode)
if [ -z "$AWX_ADMIN_PASSWORD" ]; then
    echo "⚠️  Warning: Could not retrieve AWX admin password from secret"
    echo "   You'll need to sync manually via the AWX Web UI"
    echo ""
    echo "📝 Manual Steps:"
    echo "   1. Access AWX UI (port-forward or via ingress)"
    echo "   2. Go to: Resources → Projects"
    echo "   3. Find: 'Cloudflare Automation' project"
    echo "   4. Click: SYNC button (circular arrows icon)"
    exit 0
fi

echo "✓ Retrieved AWX admin password"
echo ""

# Port forward to AWX service
echo "🔄 Setting up port-forward to AWX..."
kubectl port-forward -n awx svc/$AWX_SERVICE 8052:80 &
PF_PID=$!
sleep 3

# Function to cleanup port-forward on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Get AWX API token or use basic auth
AWX_URL="http://localhost:8052"

echo "📡 Connecting to AWX API..."
echo "   URL: $AWX_URL"
echo ""

# List projects
echo "📋 Finding Cloudflare project..."
PROJECT_ID=$(curl -s -u admin:$AWX_ADMIN_PASSWORD \
    "$AWX_URL/api/v2/projects/" \
    | jq -r '.results[] | select(.name | contains("Cloudflare") or contains("cloudflare")) | .id' \
    | head -1)

if [ -z "$PROJECT_ID" ]; then
    echo "⚠️  Could not find Cloudflare project automatically"
    echo ""
    echo "📝 Available projects:"
    curl -s -u admin:$AWX_ADMIN_PASSWORD \
        "$AWX_URL/api/v2/projects/" \
        | jq -r '.results[] | "   - ID: \(.id) | Name: \(.name)"'
    echo ""
    echo "💡 Manual sync steps:"
    echo "   1. Note your project ID from the list above"
    echo "   2. Run: curl -X POST -u admin:PASSWORD \"$AWX_URL/api/v2/projects/<ID>/update/\""
    exit 1
fi

echo "✓ Found project ID: $PROJECT_ID"
echo ""

# Trigger project update (sync)
echo "🔄 Triggering project sync..."
SYNC_RESPONSE=$(curl -s -X POST -u admin:$AWX_ADMIN_PASSWORD \
    "$AWX_URL/api/v2/projects/$PROJECT_ID/update/")

UPDATE_ID=$(echo "$SYNC_RESPONSE" | jq -r '.id')

if [ "$UPDATE_ID" = "null" ] || [ -z "$UPDATE_ID" ]; then
    echo "❌ Error: Failed to trigger project sync"
    echo "   Response: $SYNC_RESPONSE"
    exit 1
fi

echo "✓ Sync job started (ID: $UPDATE_ID)"
echo ""

# Wait for sync to complete
echo "⏳ Waiting for sync to complete..."
for i in {1..30}; do
    STATUS=$(curl -s -u admin:$AWX_ADMIN_PASSWORD \
        "$AWX_URL/api/v2/project_updates/$UPDATE_ID/" \
        | jq -r '.status')
    
    if [ "$STATUS" = "successful" ]; then
        echo "✅ Project sync completed successfully!"
        echo ""
        echo "🎉 Your playbooks are now up to date in AWX!"
        echo ""
        echo "📝 Next steps:"
        echo "   1. Go to AWX UI → Templates"
        echo "   2. Run your 'Cloudflare Automation' job template"
        echo "   3. You should see the cleaned output with no errors"
        exit 0
    elif [ "$STATUS" = "failed" ]; then
        echo "❌ Project sync failed!"
        echo "   Check AWX logs for details"
        exit 1
    fi
    
    echo "   Status: $STATUS (attempt $i/30)"
    sleep 2
done

echo "⏱️  Sync is taking longer than expected"
echo "   Check AWX UI for status: Resources → Projects"

exit 0
