#!/bin/bash
set -euo pipefail

# Apply Updated Survey Configuration to AWX
# This script applies our improved survey configuration to the AWX template

echo "🔄 Applying updated survey configuration to AWX..."

# Change to the automation scripts directory
cd "$(dirname "$0")/../automation/scripts"

# Check if the restore script exists
if [[ ! -f "restore-comprehensive-survey.sh" ]]; then
    echo "❌ Error: restore-comprehensive-survey.sh not found"
    exit 1
fi

# Make sure the script is executable
chmod +x restore-comprehensive-survey.sh

echo "📋 Survey configuration changes being applied:"
echo "   ✅ 'New Record Name' → 'Record Name'"
echo "   ✅ 'Record Content/Value' → 'Record Value'"
echo "   ✅ Default proxy status set to proxied=true"
echo "   ✅ Apply rules field removed (integrated into automatic settings)"
echo ""

# Run the restore script to apply our changes
echo "🚀 Executing survey update..."
if ./restore-comprehensive-survey.sh; then
    echo ""
    echo "✅ Survey configuration successfully updated!"
    echo "📝 Changes applied:"
    echo "   • Cleaner field names"
    echo "   • Proxied by default"
    echo "   • Simplified user interface"
    echo ""
    echo "🎯 The AWX template now reflects all our improvements!"
else
    echo ""
    echo "❌ Failed to update survey configuration"
    echo "💡 Check AWX connectivity and credentials"
    exit 1
fi