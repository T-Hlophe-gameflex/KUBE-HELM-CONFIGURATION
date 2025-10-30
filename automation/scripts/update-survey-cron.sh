#!/usr/bin/env bash

#===============================================================================
# AWX Survey Updater - Cron/Scheduler Wrapper
#===============================================================================
# 
# Simple wrapper for running the survey updater as a scheduled job.
# This can be used in:
#   - Cron jobs
#   - AWX scheduled templates
#   - Kubernetes CronJobs
#   - Manual execution
#
# Usage:
#   ./update-survey-cron.sh
#
# Cron example (update every hour):
#   0 * * * * /path/to/update-survey-cron.sh
#
# Cron example (update after business hours - 6 PM):
#   0 18 * * * /path/to/update-survey-cron.sh
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set environment variables if not already set
export AWX_HOST="${AWX_HOST:-localhost:8052}"
export AWX_TEMPLATE_ID="${AWX_TEMPLATE_ID:-21}"

# Set log file in tmp with timestamp
LOG_FILE="/tmp/survey-update-$(date +%Y%m%d-%H%M%S).log"

echo "════════════════════════════════════════════════════════════════"
echo "AWX Survey Auto-Updater - Scheduled Execution"
echo "Started: $(date)"
echo "Log: $LOG_FILE"
echo "════════════════════════════════════════════════════════════════"

# Run the main updater script and capture output
if "$SCRIPT_DIR/cloudflare-survey-scheduler.sh" 2>&1 | tee "$LOG_FILE"; then
    echo ""
    echo "✅ Survey update completed successfully at $(date)"
    echo "📋 Log saved to: $LOG_FILE"
    
    # Optional: Clean up old logs (keep last 10)
    find /tmp -name "survey-update-*.log" -type f | sort | head -n -10 | xargs rm -f 2>/dev/null || true
    
    exit 0
else
    echo ""
    echo "❌ Survey update failed at $(date)"
    echo "📋 Check log for details: $LOG_FILE"
    exit 1
fi