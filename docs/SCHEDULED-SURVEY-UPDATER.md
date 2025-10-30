# AWX Survey Auto-Updater - Scheduled Job Setup

This documentation explains how to set up automatic survey dropdown updates that run after Cloudflare template jobs.

## Overview

The survey auto-updater keeps AWX job template dropdowns current with live Cloudflare data by:
- Fetching all domains from your Cloudflare account
- Collecting DNS records from all domains
- Updating the survey dropdowns automatically
- Running as a scheduled job independent of main templates

## Files Created

### Core Scripts
- `automation/scripts/cloudflare-survey-scheduler.sh` - Main updater script
- `automation/scripts/update-survey-cron.sh` - Cron-friendly wrapper
- `automation/playbooks/cloudflare/scheduled-survey-updater.yml` - AWX playbook

## Setup Options

### Option 1: AWX Scheduled Job Template (Recommended)

1. **Create New Job Template in AWX:**
   ```
   Name: Cloudflare Survey Auto-Updater
   Job Type: Run
   Inventory: localhost
   Project: (Your project)
   Playbook: automation/playbooks/cloudflare/scheduled-survey-updater.yml
   Credentials: (Machine credential with kubectl access)
   ```

2. **Create Schedule:**
   ```
   Name: Survey Update Schedule
   Start Date/Time: Today
   Repeat Frequency: Every 1 hours
   OR
   Repeat Frequency: Custom (run after main jobs)
   ```

3. **Set Environment Variables:**
   - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token
   - `AWX_HOST`: localhost:8052 (or your AWX host)
   - `AWX_TEMPLATE_ID`: 21 (or your template ID)

### Option 2: Cron Job

1. **Add to system crontab:**
   ```bash
   # Update survey every hour during business hours (9 AM - 5 PM)
   0 9-17 * * 1-5 /path/to/update-survey-cron.sh
   
   # Update survey every 2 hours
   0 */2 * * * /path/to/update-survey-cron.sh
   
   # Update survey at 6 PM daily
   0 18 * * * /path/to/update-survey-cron.sh
   ```

2. **Set environment variables in cron:**
   ```bash
   CLOUDFLARE_API_TOKEN=your_token_here
   AWX_HOST=localhost:8052
   AWX_TEMPLATE_ID=21
   ```

### Option 3: Kubernetes CronJob

1. **Create ConfigMap for scripts:**
   ```bash
   kubectl create configmap survey-updater-scripts \
     --from-file=automation/scripts/ \
     -n awx
   ```

2. **Create CronJob:**
   ```yaml
   apiVersion: batch/v1
   kind: CronJob
   metadata:
     name: cloudflare-survey-updater
     namespace: awx
   spec:
     schedule: "0 */2 * * *"  # Every 2 hours
     jobTemplate:
       spec:
         template:
           spec:
             containers:
             - name: survey-updater
               image: alpine/k8s:1.24.0
               command: ["/scripts/update-survey-cron.sh"]
               env:
               - name: CLOUDFLARE_API_TOKEN
                 valueFrom:
                   secretKeyRef:
                     name: cloudflare-secrets
                     key: api-token
               volumeMounts:
               - name: scripts
                 mountPath: /scripts
             volumes:
             - name: scripts
               configMap:
                 name: survey-updater-scripts
                 defaultMode: 0755
             restartPolicy: OnFailure
   ```

## Manual Testing

Run the updater manually to test:

```bash
# Test the main script
cd /path/to/KUBE-HELM-CONFIGURATION
export CLOUDFLARE_API_TOKEN="your_token_here"
./automation/scripts/cloudflare-survey-scheduler.sh

# Test the cron wrapper
./automation/scripts/update-survey-cron.sh
```

## Monitoring and Logs

### Log Files
- Main script: `/tmp/cloudflare-survey-update.log`
- Cron wrapper: `/tmp/survey-update-YYYYMMDD-HHMMSS.log`

### What to Monitor
- Survey dropdown update success/failure
- Cloudflare API token validity
- AWX connectivity and authentication
- Number of domains/records fetched

### Troubleshooting

1. **No Cloudflare Token:**
   - Script will use fallback domain list
   - Check environment variables or secrets

2. **AWX Connection Issues:**
   - Verify kubectl access to AWX namespace
   - Check AWX admin password retrieval

3. **API Limits:**
   - Cloudflare API has rate limits
   - Consider reducing frequency if needed

4. **Survey Update Failures:**
   - Check AWX job template ID
   - Verify survey structure hasn't changed

## Benefits

✅ **Always Current:** Dropdowns reflect live Cloudflare data
✅ **Independent:** Doesn't slow down main Cloudflare operations  
✅ **Flexible:** Multiple scheduling options available
✅ **Robust:** Handles API failures gracefully with fallbacks
✅ **Logged:** Full audit trail of update activities

## Integration with Main Template

The main Cloudflare template (`cloudflare_awx_playbook.yml`) has been cleaned up to remove automatic survey updates. It now focuses purely on DNS operations while this scheduled job handles survey maintenance.

This separation provides:
- Faster main job execution
- Independent survey update scheduling  
- Better error isolation
- Cleaner job responsibilities