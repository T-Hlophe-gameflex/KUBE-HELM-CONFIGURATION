# Cloudflare Survey Auto-Updater - Complete Solution

## Overview

This solution provides automatic survey dropdown updates for the AWX Cloudflare template, ensuring users always have access to current domains and DNS records from their Cloudflare account.

## Components Created

### 🔧 Core Scripts
- **`cloudflare-survey-scheduler.sh`** - Main updater script with comprehensive error handling
- **`update-survey-cron.sh`** - Lightweight wrapper for cron jobs
- **`create-survey-schedules.sh`** - API-based schedule creation script

### 📋 Playbooks
- **`scheduled-survey-updater.yml`** - AWX playbook for survey updates
- **`setup-survey-schedules.yml`** - Ansible-based schedule configuration

### 📅 Schedule Options
- **Hourly Business**: Updates every hour during business hours (8 AM - 5 PM, Mon-Fri)
- **Daily Evening**: Updates daily at 6 PM
- **Weekly Refresh**: Comprehensive refresh every Monday at 6 AM

## Quick Setup

### Option 1: Automated Setup (Recommended)
```bash
cd /path/to/KUBE-HELM-CONFIGURATION
./automation/scripts/create-survey-schedules.sh
```

### Option 2: Manual Testing
```bash
# Test the survey updater directly
./automation/scripts/cloudflare-survey-scheduler.sh

# Test with cron wrapper
./automation/scripts/update-survey-cron.sh
```

## What Changed

### ✅ Removed from Main Playbook
- Automatic survey update sections removed from `cloudflare_awx_playbook.yml`
- `update_survey_dropdowns` action removed from survey choices
- Cleaner separation of concerns

### ✅ Added New Capabilities
- Standalone survey updater that doesn't interfere with DNS operations
- Multiple scheduling options for different use cases
- Comprehensive error handling and logging
- Fallback values when Cloudflare API is unavailable

## Features

### 🔄 Smart Updates
- **Live Data**: Fetches current domains and DNS records from Cloudflare
- **Fallback Values**: Uses static defaults when API is unavailable
- **Error Resilience**: Continues operation even with partial failures

### 📊 Monitoring
- **Detailed Logging**: Full audit trail in `/tmp/cloudflare-survey-update.log`
- **Status Reporting**: Clear success/failure indicators
- **API Rate Limiting**: Respects Cloudflare API limits

### ⚙️ Flexible Configuration
- **Environment Variables**: Easy configuration via env vars
- **Multiple Schedules**: Different frequencies for different needs
- **Enable/Disable**: Turn schedules on/off as needed

## Usage Scenarios

### Scenario 1: Regular Business Hours Updates
- **Schedule**: Hourly Business (8 AM - 5 PM, Mon-Fri)
- **Use Case**: Keep dropdowns fresh during active work hours
- **Benefit**: Users always see current data when creating DNS records

### Scenario 2: Daily Maintenance
- **Schedule**: Daily Evening (6 PM daily)
- **Use Case**: End-of-day refresh for next day preparation
- **Benefit**: Ensures overnight changes are captured

### Scenario 3: Weekly Comprehensive Refresh
- **Schedule**: Weekly Refresh (Monday 6 AM)
- **Use Case**: Full account scan and cleanup
- **Benefit**: Catches any missed changes from weekend activities

## Architecture Benefits

### 🎯 Separation of Concerns
- **Main Template**: Focus purely on DNS operations
- **Survey Updater**: Handles dropdown maintenance independently
- **No Interference**: DNS operations run at full speed

### 🔧 Maintenance Friendly
- **Independent Updates**: Survey refresh doesn't require DNS template changes
- **Isolated Failures**: Survey update issues don't affect DNS operations
- **Easy Monitoring**: Separate logs and status tracking

### 📈 Scalable Design
- **Multiple Frequencies**: Choose update frequency based on usage
- **API Efficient**: Batched operations reduce API calls
- **Resource Conscious**: Minimal impact on AWX performance

## Troubleshooting

### Common Issues

1. **No Cloudflare Token**
   - Script uses fallback domain list
   - Set `CLOUDFLARE_API_TOKEN` environment variable
   - Or create `cloudflare-api-token` secret in AWX namespace

2. **AWX Connection Errors**
   - Check kubectl access to AWX namespace
   - Verify AWX admin password retrieval
   - Confirm AWX host and port settings

3. **Schedule Not Running**
   - Check schedule is enabled in AWX UI
   - Verify rrule format is correct
   - Review AWX job execution logs

### Log Locations
- **Main Script**: `/tmp/cloudflare-survey-update.log`
- **Cron Wrapper**: `/tmp/survey-update-YYYYMMDD-HHMMSS.log`
- **AWX Jobs**: AWX UI → Jobs → Job Details

## Integration with Existing Workflow

### Before Changes
```
User → AWX Template → DNS Operations + Survey Update
                   ↳ Slower execution, mixed concerns
```

### After Changes
```
User → AWX Template → DNS Operations (fast)
       ↓
Schedule → Survey Update Template → Dropdown Refresh
         ↳ Independent, reliable, scheduled
```

## Monitoring and Maintenance

### Daily Checks
- [ ] Verify schedules are running successfully
- [ ] Check survey dropdowns have current data
- [ ] Review error logs for any issues

### Weekly Reviews
- [ ] Analyze survey update frequency effectiveness
- [ ] Review Cloudflare API usage and limits
- [ ] Adjust schedules based on team usage patterns

### Monthly Maintenance
- [ ] Update fallback domain lists if needed
- [ ] Review and clean up old log files
- [ ] Performance optimization based on usage data

## Success Metrics

### ✅ Technical Success
- Survey dropdowns update automatically
- No DNS operation performance impact
- Zero survey-related failures in main template

### ✅ User Experience Success
- Users see current domain/record options
- Faster DNS operations (no embedded survey updates)
- Reliable dropdown data availability

### ✅ Operational Success
- Reduced manual survey maintenance
- Clear audit trail of updates
- Predictable and scheduled refresh cycles

This solution provides a robust, maintainable approach to keeping AWX survey dropdowns current while maintaining optimal performance for DNS operations.