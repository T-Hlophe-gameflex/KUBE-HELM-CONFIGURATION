# AWX Survey Setup for Cloudflare DNS Management

## Summary

This document explains how the AWX survey was configured for the "Cloudflare AWX Survey" template.

## Problem

The AWX job template "Cloudflare AWX Survey" had `survey_enabled: true` but no actual survey specification, so when launching the template, no survey form would appear to collect user input.

## Solution

### 1. Created Comprehensive Survey Specification

**File:** `automation/unified-cloudflare-awx-survey.json`

This JSON file defines 7 survey questions that map to the variables used in the playbook:

| Question | Variable | Type | Required | Description |
|----------|----------|------|----------|-------------|
| Cloudflare Action | `cf_action` | multiplechoice | Yes | Action to perform (create_domain, create_record, update_record, delete_record, clone_record, standardize, sync) |
| Domain Name | `domain` | text | Yes | Domain to manage (e.g., example.com) |
| Record Name | `record_name` | text | No | DNS record name (e.g., www, api, @) |
| Record Type | `record_type` | multiplechoice | No | DNS record type (A, AAAA, CNAME, TXT, MX, SRV, NS, CAA) |
| Record Content/Value | `record_value` | text | No | DNS record content (IP, hostname, text value) |
| Record TTL | `global_ttl` | integer | No | Time to Live in seconds (1-2147483647, default: 3600) |
| Proxy Status | `global_proxied` | multiplechoice | No | Enable Cloudflare proxy (true/false) |

### 2. Created Survey Application Script

**File:** `automation/apply-survey-to-template.sh`

This bash script:
- Connects to AWX API using the token
- Finds the job template by name
- Loads the survey specification from JSON
- Applies the survey to the template via PATCH request
- Verifies the survey was applied successfully

### 3. Git Integration

All changes were committed and pushed to git:

```bash
git add automation/unified-cloudflare-awx-survey.json \
        automation/apply-survey-to-template.sh \
        automation/apply-survey-simple.sh
git commit -m "feat: Add comprehensive AWX survey specification"
git push origin main
```

The AWX project was then synced to pull the latest changes from git.

## How to Use

### Apply Survey to Template

```bash
cd /path/to/KUBE-HELM-CONFIGURATION
./automation/apply-survey-to-template.sh
```

### Update Survey (if you modify the JSON)

1. Edit `automation/unified-cloudflare-awx-survey.json`
2. Commit and push changes to git
3. Trigger AWX project sync (or wait for auto-sync)
4. Run the apply script again

### Launch Template with Survey

1. Go to AWX UI: http://127.0.0.1:8052
2. Navigate to Templates → "Cloudflare AWX Survey"
3. Click the **Launch** button
4. Fill out the survey form with your desired values
5. Click **Next** → **Launch**

## Survey Variables Mapping to Playbook

The playbook `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml` expects these variables:

- `cf_action`: Determines which tasks run (create_domain, create_record, etc.)
- `domain`: The Cloudflare zone/domain to operate on
- `record_name`: The DNS record name (used with create/update/delete record actions)
- `record_type`: The type of DNS record (A, CNAME, etc.)
- `record_value` or `record_content`: The value for the DNS record
- `global_ttl`: TTL for DNS records
- `global_proxied`: Whether to enable Cloudflare proxy

## Troubleshooting

### Survey Not Appearing

If the survey doesn't appear when launching:

1. Check if survey is enabled:
   ```bash
   export AWX_TOKEN="your-token"
   curl -s -H "Authorization: Bearer $AWX_TOKEN" \
     "http://127.0.0.1:8052/api/v2/job_templates/21/" | \
     python3 -c 'import sys,json;j=json.load(sys.stdin);print("Survey Enabled:", j.get("survey_enabled"))'
   ```

2. Re-apply the survey:
   ```bash
   ./automation/apply-survey-to-template.sh
   ```

3. Clear browser cache and refresh AWX UI

### Survey JSON Syntax Errors

Validate your JSON:
```bash
python3 -c 'import json; json.load(open("automation/unified-cloudflare-awx-survey.json")); print("Valid JSON")'
```

### AWX API Connection Issues

Check AWX token:
```bash
export AWX_TOKEN="your-token-here"
curl -s -H "Authorization: Bearer $AWX_TOKEN" \
  "http://127.0.0.1:8052/api/v2/me/" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("username", "Invalid token"))'
```

## Files Created/Modified

- ✅ `automation/unified-cloudflare-awx-survey.json` - Survey specification
- ✅ `automation/apply-survey-to-template.sh` - Script to apply survey
- ✅ `automation/apply-survey-simple.sh` - Helper script
- ✅ `automation/README-SURVEY-SETUP.md` - This documentation

## Next Steps

1. Test the survey by launching the template from AWX UI
2. Verify all survey fields work correctly
3. Add more survey questions if needed
4. Consider adding validation rules or conditional logic

## References

- AWX API Documentation: https://docs.ansible.com/automation-controller/latest/html/controllerapi/api_ref.html
- Survey Specification Format: https://docs.ansible.com/automation-controller/latest/html/userguide/job_templates.html#surveys
- Playbook: `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`
