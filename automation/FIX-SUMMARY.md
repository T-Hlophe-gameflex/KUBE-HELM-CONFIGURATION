# Fix Summary - Page Rules & Dynamic Dropdowns

**Date:** October 29, 2025  
**Job Reference:** Job #894 failure analysis

## Issues Fixed

### 1. Page Rules API Error (Error 1011)
**Problem:** 
- Page Rules endpoint returned "Page Rules endpoint does not support account owned tokens"
- Playbook failed when trying to access page rules with account-scoped token

**Solution:**
- Added `ignore_errors: yes` to page rules lookup task
- Created warning message display when error 1011 is detected
- Page rules operations now skip gracefully when API doesn't support them
- All page rules blocks now have proper conditional checks

### 2. Undefined Variable `existing_count`
**Problem:**
- Task "Compute excess count to delete" referenced undefined variable `existing_count`
- Error occurred at line 132 in unified-cloudflare-awx-playbook.yml

**Solution:**
- Moved `existing_count` initialization into the "Set page rules limit" task
- Set with default value: `{{ (page_rules_lookup.json.result | length) if ... else 0 }}`
- Proper fallback to 0 when page_rules_lookup fails

### 3. Page Rules Executing on Delete Operations
**Problem:**
- Page rules were being processed even during delete_record operations
- This was unnecessary and caused errors

**Solution:**
- Added `cf_action in ['create_domain', 'create_record', 'update_record', 'clone_record']` condition
- Page rules now only process for create/update/clone operations
- Delete operations skip all page rules logic

### 4. Missing DNS Records Display
**Problem:**
- Users couldn't see current DNS records before performing operations
- Made troubleshooting difficult

**Solution:**
- Added "Display current DNS records for this domain" task
- Shows formatted list with: name, type, content, TTL, proxied status, record ID
- Displays total record count
- Always runs when DNS records are fetched

### 5. Static Survey Dropdowns
**Problem:**
- Domain and DNS record fields were text input only
- Users had to manually type domain names and record names
- Risk of typos and errors

**Solution:**
- Created `update-survey-dropdowns.sh` script to populate domain dropdown
- Created `update-dns-records-dropdown.sh` script to populate DNS records dropdown
- Scripts fetch live data from Cloudflare API
- Update AWX survey via API with current choices
- See [README-DYNAMIC-DROPDOWNS.md](README-DYNAMIC-DROPDOWNS.md) for usage

## Changes Made

### Playbook Changes (unified-cloudflare-awx-playbook.yml)

#### Added Conditions to Page Rules Section:
```yaml
when: 
  - cf_action in ['create_domain', 'create_record', 'update_record', 'clone_record']
  - zone_id is defined and zone_id | length > 0
  - selected_page_rule is defined and selected_page_rule != 'none'
  - page_rules_lookup is defined
```

#### Enhanced DNS Records Display:
```yaml
- name: Display current DNS records for this domain
  debug:
    msg: |
      ================================================================================
      CURRENT DNS RECORDS FOR: {{ domain }}
      ================================================================================
      ...shows all records with details...
```

#### Fixed Variable Initialization:
```yaml
existing_count: >-
  {{ (page_rules_lookup.json.result | length) if (page_rules_lookup is defined and page_rules_lookup.json is defined and page_rules_lookup.json.success) else 0 }}
```

### New Scripts

#### 1. automation/update-survey-dropdowns.sh
- Fetches all Cloudflare zones (domains)
- Updates domain question in AWX survey to multiplechoice
- Populates with current domain list

**Usage:**
```bash
export AWX_HOST="http://127.0.0.1:8052"
export AWX_TOKEN="your_awx_token"
export CLOUDFLARE_API_TOKEN="your_cf_token"
./automation/update-survey-dropdowns.sh
```

#### 2. automation/update-dns-records-dropdown.sh
- Fetches DNS records for a specific domain
- Displays current records
- Updates record_name question to multiplechoice
- Populates with existing record names

**Usage:**
```bash
./automation/update-dns-records-dropdown.sh efutechnologies.co.za
```

### New Documentation

#### automation/README-DYNAMIC-DROPDOWNS.md
Comprehensive guide covering:
- How dynamic dropdowns work
- Script usage and examples
- Workflow recommendations
- Limitations and workarounds
- Troubleshooting guide
- Automation ideas (cron jobs, webhooks)

## Testing Results

### Job Template Configuration
- Template ID: 21 ("Cloudflare AWX Survey")
- Job Type: Changed from "check" to "run" ✅
- Survey Enabled: true ✅
- Survey Questions: 8 questions configured ✅

### Survey Dropdown Updates
- Domain dropdown: Successfully populated with 2 domains ✅
- DNS records dropdown: Successfully populated with 6 records ✅
- Both scripts working correctly ✅

### Playbook Validation
- Syntax check: PASSED ✅
- Page rules conditions: Added for all tasks ✅
- Variable initialization: Fixed ✅
- DNS display: Enhanced ✅

## Next Steps

### Immediate Actions
1. **Run a test job** to verify page rules skip gracefully:
   ```bash
   # Select action: delete_record
   # Should skip all page rules tasks
   ```

2. **Run create/update job** with page_rule != 'none':
   ```bash
   # Select action: create_record
   # Select page_rule: Cache Everything
   # Should attempt page rules (may show warning if token doesn't support)
   ```

3. **Update dropdowns before using:**
   ```bash
   # Update domains list
   ./automation/update-survey-dropdowns.sh
   
   # Update records for specific domain
   ./automation/update-dns-records-dropdown.sh your-domain.com
   ```

### Optional Enhancements

#### 1. Zone-Scoped API Token
If you want page rules to work:
- Go to Cloudflare Dashboard → My Profile → API Tokens
- Create token with "Zone" scope instead of "Account" scope
- Include "Page Rules:Edit" permission
- Update AWX credential with new token

#### 2. Automate Dropdown Updates
Set up cron job to update dropdowns daily:
```bash
# Edit crontab
crontab -e

# Add line (runs at 2 AM daily)
0 2 * * * source ~/.awx_cloudflare_env && /path/to/automation/update-survey-dropdowns.sh >> /var/log/awx-updates.log 2>&1
```

#### 3. Pre-Launch Workflow
Create AWX workflow template:
1. First job: Run update-survey-dropdowns.sh
2. Second job: Launch Cloudflare AWX Survey template

## Verification Checklist

- [x] Template job_type set to "run" (not "check")
- [x] Page rules have cf_action conditions
- [x] Page rules have selected_page_rule != 'none' checks
- [x] existing_count variable initialized properly
- [x] DNS records display shows all records
- [x] Domain dropdown update script working
- [x] DNS records dropdown update script working
- [x] Documentation created
- [x] All changes committed to git
- [ ] Test job with delete_record action
- [ ] Test job with create_record + page rule
- [ ] Verify actual Cloudflare records created/deleted

## Known Limitations

1. **Page Rules with Account Token:**
   - Account-scoped tokens don't support Page Rules API
   - Playbook will show warning and skip page rules
   - DNS operations will continue normally
   - Solution: Use zone-scoped token if page rules needed

2. **Dynamic Dropdowns:**
   - AWX surveys are static - don't update in real-time
   - Must run update scripts before launching template
   - DNS records dropdown shows last queried domain
   - Can still manually type values if needed

3. **Survey Limitations:**
   - Cannot have cascading dropdowns (domain → records)
   - Both dropdowns update independently
   - Record names include domain FQDN + type for clarity

## Support

For questions or issues:
1. Check [README-DYNAMIC-DROPDOWNS.md](README-DYNAMIC-DROPDOWNS.md)
2. Check [SURVEY-QUESTIONS-GUIDE.md](SURVEY-QUESTIONS-GUIDE.md)
3. Review playbook debug output in job logs
4. Verify API tokens have correct permissions

## Files Modified/Created

### Modified:
- `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`

### Created:
- `automation/update-survey-dropdowns.sh`
- `automation/update-dns-records-dropdown.sh`
- `automation/README-DYNAMIC-DROPDOWNS.md`
- `automation/FIX-SUMMARY.md` (this file)
- `automation/unified-cloudflare-awx-survey-complete.json` (backup)

### Git Commit:
```
commit 5247a69
Fix: Page rules conditional logic and add dynamic survey dropdowns
```
