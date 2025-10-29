# Dynamic Survey Dropdowns for AWX

## Overview

This directory contains scripts to dynamically populate AWX survey dropdowns with current Cloudflare data (domains and DNS records). Since AWX surveys don't natively support dynamic data loading from external APIs, these scripts update the survey definition with fresh data from Cloudflare.

## Scripts

### 1. update-survey-dropdowns.sh

Updates the domain dropdown in the AWX survey with all zones from your Cloudflare account.

**Usage:**
```bash
export AWX_HOST="http://127.0.0.1:8052"
export AWX_TOKEN="your_awx_token"
export CLOUDFLARE_API_TOKEN="your_cloudflare_token"

./automation/update-survey-dropdowns.sh
```

**What it does:**
- Fetches all zones (domains) from Cloudflare API
- Updates the `domain` question in the AWX survey to be a multiplechoice dropdown
- Populates choices with all your Cloudflare domains

**Output Example:**
```
Found 5 domains:
  - domain1.com
  - domain2.com
  - example.com
  - test.com
  - mysite.org

✓ Survey updated successfully!
```

### 2. list-all-dns-records.sh

Displays all DNS records from all domains in your Cloudflare account. This is a reference tool to help you see what records exist before launching AWX jobs.

**Usage:**
```bash
export CLOUDFLARE_API_TOKEN="your_cloudflare_token"

./automation/list-all-dns-records.sh
```

**What it does:**
- Fetches all zones (domains) from your Cloudflare account
- Retrieves and displays all DNS records from every domain
- Shows records with full details: type, name, content, TTL, proxied status, ID
- Lists all unique record names at the end for easy reference
- Provides a summary of total domains and records

**Output Example:**
```
╔════════════════════════════════════════════════════════════════╗
║          Cloudflare DNS Records - All Domains                 ║
╚════════════════════════════════════════════════════════════════╝

Found 2 domains in your Cloudflare account

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain: efutechnologies.co.za
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [CNAME] www.efutechnologies.co.za
    → efutechnologies.co.za
    TTL: 3600 | Proxied: true | ID: abc123

All unique record names (use these when creating/updating/deleting):
  • drtdtydy.efutechnologies.co.za
  • efustryton.co.za
  • www.efutechnologies.co.za
  ...
```

### 3. update-dns-records-dropdown.sh (Deprecated)

⚠️ **Note:** This script is now deprecated since the record_name field is a text input, not a dropdown. Use `list-all-dns-records.sh` instead to see all available records.

The record_name field in the AWX survey is now a **text field** that allows free-form input. Simply type the record name you want to create/update/delete.

## Workflow

### For Creating/Updating/Deleting Records

1. **Update domain dropdown (optional - if domains changed):**
   ```bash
   ./automation/update-survey-dropdowns.sh
   ```

2. **List all DNS records to see what exists:**
   ```bash
   ./automation/list-all-dns-records.sh
   ```
   This will show you all existing record names across all domains. Copy the record name you want to work with.

3. **Launch the AWX template:**
   - Select domain from dropdown OR type domain name
   - Type the record name in the text field (no dropdown, free-form entry)
   - Fill in other fields as needed
   - Launch the job

### Record Name Field - Text Input

The `record_name` field is configured as:
- **Type:** text (free-form input)
- **Required:** false (optional field)
- **No dropdown** - You type the record name manually

**How to use it:**
1. **For new records** - Type the new record name you want to create (e.g., `www`, `api`, `mail`)
2. **For existing records** - Run `list-all-dns-records.sh` first to see all records, then copy/paste the exact record name
3. **For root domain** - Use `@` or leave empty depending on the operation

## Playbook Enhancements

The unified Cloudflare playbook has been updated to:

### Display Current Records

Before performing any operation, the playbook now displays all current DNS records for the domain:

```
================================================================================
CURRENT DNS RECORDS FOR: efutechnologies.co.za
================================================================================
Total Records: 15

1. efutechnologies.co.za (A)
   Content: 192.0.2.1
   TTL: 3600 | Proxied: True
   Record ID: abc123

2. www.efutechnologies.co.za (CNAME)
   Content: efutechnologies.co.za
   TTL: 3600 | Proxied: True
   Record ID: def456
...
================================================================================
```

### Smart Page Rules Handling

Page rules are now only processed when:
- `selected_page_rule` is set to something other than "none"
- The operation is create/update (not delete)
- API token has proper permissions

If the API token doesn't support page rules (error 1011: "Page Rules endpoint does not support account owned tokens"), the playbook will:
- Display a warning message
- Skip page rules operations
- Continue with DNS record operations normally

**Error handling:**
```
WARNING: Page Rules API returned error code 1011: Page Rules endpoint does not support account owned tokens. 
Skipping page rules management. Consider using a zone-scoped token instead of account token.
```

### Fixed Variables

All undefined variable errors have been fixed:
- `existing_count` is now properly initialized
- `existing_page_rules` defaults to empty array
- All page rules operations have proper conditional checks

## Environment Variables

### Required
- `AWX_TOKEN` - Your AWX API token (from AWX → Users → Tokens)
- `CLOUDFLARE_API_TOKEN` - Your Cloudflare API token

### Optional
- `AWX_HOST` - AWX URL (default: http://127.0.0.1:8052)
- `TEMPLATE_ID` - AWX template ID (default: 21)

## Configuration

To set up your environment, create a file `~/.awx_cloudflare_env`:

```bash
# AWX Configuration
export AWX_HOST="http://127.0.0.1:8052"
export AWX_TOKEN="your_awx_api_token_here"
export TEMPLATE_ID="21"

# Cloudflare Configuration
export CLOUDFLARE_API_TOKEN="your_cloudflare_api_token_here"
```

Then source it before running scripts:
```bash
source ~/.awx_cloudflare_env
./automation/update-survey-dropdowns.sh
```

## Limitations

### AWX Survey Dynamic Data

AWX surveys are **static** - they don't fetch data in real-time when a user opens the form. To work around this:

1. **Run update scripts periodically:** Set up a cron job to update dropdowns daily
2. **Run before using:** Manually run the update scripts before launching templates
3. **Webhook integration:** Create a webhook that triggers the update scripts when domains/records change

### DNS Records Dropdown

The DNS records dropdown shows records from the **last domain queried** with the update script. This means:
- You need to run `update-dns-records-dropdown.sh` for each domain you want to work with
- The dropdown won't automatically update when you select a different domain in the survey
- You can always manually type a record name instead of selecting from the dropdown

### Future Enhancement Ideas

1. **AWX Workflow Template:** Create a workflow that:
   - First job: Update survey with current data
   - Second job: Run the actual Cloudflare operation

2. **Custom AWX UI Plugin:** Develop a plugin that fetches Cloudflare data client-side

3. **API Gateway:** Create a middleware service that:
   - AWX survey queries this service
   - Service fetches fresh data from Cloudflare
   - Returns formatted choices for dropdowns

## Troubleshooting

### "No zones found"
- Check your `CLOUDFLARE_API_TOKEN` has proper permissions
- Verify the token using: `curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"`

### "Survey update failed"
- Verify `AWX_TOKEN` is valid and has permissions
- Check template ID is correct: `curl -H "Authorization: Bearer $AWX_TOKEN" "$AWX_HOST/api/v2/job_templates/21/"`

### "Page Rules error 1011"
- This is expected with account-scoped tokens
- Page rules operations will be skipped
- DNS operations will continue normally
- To use page rules: create a zone-scoped API token in Cloudflare dashboard

## Examples

### Complete Workflow Example

```bash
# 1. Set up environment
export AWX_HOST="http://127.0.0.1:8052"
export AWX_TOKEN="e5VRSZHAwWshxPYbKjc5p3I0zmc1T9"
export CLOUDFLARE_API_TOKEN="your_token_here"

# 2. Update domain dropdown with all zones
./automation/update-survey-dropdowns.sh

# 3. Update DNS records for specific domain
./automation/update-dns-records-dropdown.sh efutechnologies.co.za

# 4. Launch AWX template
# - Go to http://127.0.0.1:8052
# - Click "Templates" → "Cloudflare AWX Survey" → "Launch"
# - Select domain from dropdown
# - Select record from dropdown (or type new name)
# - Choose action, record type, etc.
# - Click "Launch"

# 5. View job output to see current records and operation results
```

### Automation with Cron

Update dropdowns daily at 2 AM:

```bash
# Edit crontab
crontab -e

# Add these lines
0 2 * * * source ~/.awx_cloudflare_env && /path/to/automation/update-survey-dropdowns.sh >> /var/log/awx-dropdown-update.log 2>&1
```

## See Also

- [AWX Survey Setup Guide](README-SURVEY-SETUP.md)
- [Survey Questions Guide](SURVEY-QUESTIONS-GUIDE.md)
- [AWX API Documentation](https://docs.ansible.com/automation-controller/latest/html/controllerapi/index.html)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
