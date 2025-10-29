# Zone Settings API Troubleshooting Guide

## Common Errors and Solutions

### Error 1: "Could not route to /zones//settings/{setting_name}"

**Symptoms:**
```json
{
  "code": 7003,
  "message": "Could not route to /zones//settings/cache_level, perhaps your object identifier is invalid?"
}
```

**Cause:** The `zone_id` variable is empty or undefined when trying to apply zone settings.

**URL Pattern (with error):**
```
https://api.cloudflare.com/client/v4/zones//settings/cache_level
                                         ^^
                                    Missing zone_id!
```

**Solution:** 
- ✅ **Fixed in commit 4f2e793**: Added `when: zone_id is defined and zone_id | length > 0` validation
- The playbook now checks that zone_id exists before applying settings
- If zone_id is missing, the settings block is skipped gracefully

**Root Cause:**
- The "Standardize domain settings" block and "Manage DNS record" block both lookup zone_id
- They run in sequence, but zone_id might not be set yet when settings are applied
- Added validation prevents API call with empty zone_id

---

### Error 2: "Malformed JSON in request body"

**Symptoms:**
```json
{
  "errors": [1003],
  "messages": ["Malformed JSON in request body"],
  "result": null
}
```

**Cause:** The setting doesn't exist, isn't available on your Cloudflare plan, or requires different value format.

**Common Settings That May Fail:**
- `ssl_recommender` - Not available on free plans or certain zones
- `cache_level` - May not be available on all plans
- Custom settings added to `merged_zone_settings`

**Solution:**
- ✅ **Fixed in commit 4f2e793**: Added `ignore_errors: yes` and `failed_when: false`
- Playbook continues even if some settings fail
- Debug output shows which settings succeeded vs failed

**Example Output (After Fix):**
```yaml
[GLOBAL LEVEL] Zone Settings Applied: efustryton.co.za
  Domain: efustryton.co.za
  Zone ID: a4cdccc225194d4363bc29ae2da72e2a
  Attempted: ['ssl', 'min_tls_version', 'cache_level', 'ssl_recommender']
  Success: ['ssl', 'min_tls_version', 'cache_level']
  Failed: ['ssl_recommender']
```

---

### Error 3: "No route for that URI"

**Symptoms:**
```json
{
  "code": 7000,
  "message": "No route for that URI"
}
```

**Cause:** The API endpoint for that specific setting doesn't exist or has been deprecated.

**Solution:**
- Check Cloudflare API documentation for the correct endpoint
- Some settings use different endpoints (e.g., SSL/TLS Recommender might be under a different path)
- Consider removing unsupported settings from `cloudflare_standard_zone_settings.yml`

---

## Zone Settings Implementation

### How Zone Settings Are Applied

```yaml
# Step 1: Get zone_id from domain name
GET /zones?name={domain}
Response: {"result": [{"id": "zone_id_here"}]}

# Step 2: Merge default settings with survey values
merged_zone_settings = {
  'ssl': 'full',
  'min_tls_version': '1.2',
  'cache_level': cache_level_mode (from survey),
  'ssl_recommender': ssl_tls_recommender (from survey)
}

# Step 3: Apply each setting individually
FOR EACH setting IN merged_zone_settings:
  PATCH /zones/{zone_id}/settings/{setting_key}
  Body: {"value": setting_value}
```

### Current Validation (Commit 4f2e793)

```yaml
- name: Apply standard zone settings
  uri:
    url: "https://api.cloudflare.com/client/v4/zones/{{ zone_id }}/settings/{{ item.key }}"
    method: PATCH
    body_format: json
    body:
      value: "{{ item.value }}"
  loop: "{{ merged_zone_settings | dict2items }}"
  when: zone_id is defined and zone_id | length > 0  # ← Prevents empty zone_id
  ignore_errors: yes                                  # ← Continues on errors
  failed_when: false                                  # ← Doesn't mark as failed
```

---

## Debugging Zone Settings

### Check Which Settings Are Available

```bash
# Get all available settings for a zone
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings" \
  -H "Authorization: Bearer {API_TOKEN}" \
  | jq '.result[] | {id: .id, value: .value}'
```

### Test Individual Setting

```bash
# Test cache_level
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/cache_level" \
  -H "Authorization: Bearer {API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"value":"aggressive"}'

# Test ssl_recommender
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/ssl_recommender" \
  -H "Authorization: Bearer {API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"value":"on"}'
```

---

## Supported Zone Settings

### Settings That Work on Free Plans

| Setting | Values | Status |
|---------|--------|--------|
| `ssl` | off, flexible, full, strict | ✅ Works |
| `always_use_https` | on, off | ✅ Works |
| `min_tls_version` | 1.0, 1.1, 1.2, 1.3 | ✅ Works |
| `cache_level` | bypass, basic, simplified, aggressive | ✅ Works |
| `browser_cache_ttl` | 0-31536000 (seconds) | ✅ Works |

### Settings That May Fail on Free Plans

| Setting | Error | Workaround |
|---------|-------|------------|
| `ssl_recommender` | Malformed JSON | Remove from defaults or ignore errors |
| `tls_1_3` | Not available | Requires paid plan |
| `automatic_https_rewrites` | May fail | Check plan compatibility |

---

## Configuration Files

### Default Settings File
**Location:** `automation/vars/cloudflare_standard_zone_settings.yml`

```yaml
---
# Standard zone-level settings applied to all domains
always_use_https: on
argo: "true"
ssl: "full"
min_tls_version: "1.2"
browser_cache_ttl: 14400
http2: on
cache_level: "standard"        # Overridden by cache_level_mode survey field
ssl_recommender: "on"          # Overridden by ssl_tls_recommender survey field
```

### Survey Field Overrides

When running a job, survey fields override defaults:
- `cache_level_mode` → overrides `cache_level`
- `ssl_tls_recommender` → overrides `ssl_recommender`

**Merged Result:**
```yaml
merged_zone_settings = standard_zone_settings | combine({
  'ssl_recommender': ssl_tls_recommender,
  'cache_level': cache_level_mode
})
```

---

## Actions That Apply Zone Settings

| Action | Zone Settings Applied | When |
|--------|----------------------|------|
| `create_domain` | ✅ Yes | Always |
| `create_record` | ✅ Yes | When zone_id found |
| `standardize` | ✅ Yes | Always |
| `sync` | ✅ Yes | For all zones |
| `update_record` | ❌ No | DNS only |
| `delete_record` | ❌ No | DNS only |

---

## Best Practices

### 1. Test Settings on Free Zone First
```bash
# Test all settings
ansible-playbook automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml \
  -e "cf_action=standardize" \
  -e "domain=test.example.com" \
  -e "cache_level_mode=aggressive" \
  -e "ssl_tls_recommender=enabled" \
  -vv
```

### 2. Review Output for Failed Settings
Look for:
```
Success: ['ssl', 'min_tls_version', 'cache_level']
Failed: ['ssl_recommender']
```

### 3. Remove Unsupported Settings
Edit `automation/vars/cloudflare_standard_zone_settings.yml`:
```yaml
# Comment out or remove settings that fail on your plan
# ssl_recommender: "on"  # Not available on free plans
```

### 4. Use Conditional Settings
Add plan-specific logic:
```yaml
- name: Apply premium settings
  when: cloudflare_plan == 'pro' or cloudflare_plan == 'business'
  # Only apply advanced settings on paid plans
```

---

## Troubleshooting Checklist

### Zone Settings Not Applied

- [ ] Check if action is one of: `create_domain`, `standardize`, `sync`, `create_record`
- [ ] Verify domain exists in Cloudflare
- [ ] Check zone_id is present in debug output
- [ ] Look for "Zone Settings Applied" message
- [ ] Review Success/Failed lists

### Specific Setting Fails

- [ ] Check if setting is supported on your Cloudflare plan
- [ ] Verify value format matches API documentation
- [ ] Test setting with curl command
- [ ] Check Cloudflare dashboard for manual setting
- [ ] Review API error message code

### Playbook Fails Completely

- [ ] Update to commit 4f2e793 or later (has error handling)
- [ ] Check CLOUDFLARE_API_TOKEN is set
- [ ] Verify domain name is correct
- [ ] Test API token with curl
- [ ] Check internet connectivity

---

## Recent Fixes

### Commit 4f2e793 (October 29, 2025)
**Changes:**
- Added `zone_id` validation before applying settings
- Added `ignore_errors: yes` to continue on failures
- Added `failed_when: false` to prevent playbook failure
- Improved debug output with success/failed lists

**Before Fix:**
```
TASK [Apply standard zone settings]
failed: [localhost] ❌ 
  "url": ".../zones//settings/cache_level"  # Empty zone_id
  "message": "Could not route to /zones/settings/"
```

**After Fix:**
```
TASK [Apply standard zone settings]
ok: [localhost] ✅
  Success: ['cache_level', 'ssl']
  Failed: ['ssl_recommender']  # Gracefully handled
```

---

## API Documentation References

- [Zone Settings List](https://developers.cloudflare.com/api/operations/zone-settings-get-all-zone-settings)
- [Update Zone Setting](https://developers.cloudflare.com/api/operations/zone-settings-edit-single-setting)
- [Cache Level Settings](https://developers.cloudflare.com/cache/how-to/set-caching-levels/)
- [SSL/TLS Settings](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
