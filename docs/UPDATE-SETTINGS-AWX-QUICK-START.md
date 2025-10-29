# AWX Quick Start: Update Settings Action

## Overview
The `update_settings` action allows you to update Cloudflare configuration at three different levels through the AWX interface.

---

## AWX Survey Configuration

### Required Fields

#### 1. Action Selection
- **Field Name**: `cf_action`
- **Type**: Multiple Choice (Dropdown)
- **Options**: Add `update_settings` to existing options
- **Required**: Yes

#### 2. Settings Level Selection
- **Field Name**: `settings_level`
- **Type**: Multiple Choice (Dropdown)
- **Options**: 
  - `zone` - Update zone/domain level settings
  - `record` - Update individual DNS record settings
  - `account` - Update account-wide settings (coming soon)
- **Required**: Yes (when cf_action = update_settings)
- **Show If**: `cf_action == 'update_settings'`

---

## Zone Level Updates

### Survey Fields Needed
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: <select from dropdown>

# Optional Performance Settings:
cache_level: [basic|simplified|aggressive]
browser_cache_ttl: [14400|21600|43200|86400]  # seconds
http3: [on|off]
http2: [on|off]
brotli: [on|off]
rocket_loader: [on|off]

# Optional Security Settings:
ssl_mode: [off|flexible|full|full_strict]
min_tls_version: [1.0|1.1|1.2|1.3]
tls_1_3: [on|off|zrt]
always_use_https: [on|off]
automatic_https_rewrites: [on|off]
security_level: [off|essentially_off|low|medium|high|under_attack]

# Optional Network Settings:
ipv6: [on|off]
websockets: [on|off]

# Optional Content Settings:
development_mode: [on|off]
email_obfuscation: [on|off]
hotlink_protection: [on|off]
```

### Example: Update Performance Settings
1. Select `cf_action`: `update_settings`
2. Select `settings_level`: `zone`
3. Select `existing_domain`: `efustryton.co.za`
4. Set `cache_level`: `aggressive`
5. Set `http3`: `on`
6. Set `brotli`: `on`
7. Run Job Template

**Result**: Zone settings updated for efustryton.co.za
- cache_level = aggressive ✅
- http3 = on ✅
- brotli = on ✅

---

## Record Level Updates

### Survey Fields Needed
```yaml
cf_action: update_settings
settings_level: record
existing_domain: <select from dropdown>
record_name: <subdomain or select from dropdown>
record_type: <A|AAAA|CNAME|MX|TXT>  # Optional, for disambiguation

# Settings to update:
record_proxied: [true|false]  # Enable/disable orange cloud
record_ttl: [1|60|300|600|1800|3600|86400]  # 1 = automatic
record_value: <new IP or content>  # Optional, to update content too
```

### Example: Enable Proxy for Record
1. Select `cf_action`: `update_settings`
2. Select `settings_level`: `record`
3. Select `existing_domain`: `efustryton.co.za`
4. Enter `record_name`: `www`
5. Set `record_type`: `A`
6. Set `record_proxied`: `true`
7. Set `record_ttl`: `1` (automatic)
8. Run Job Template

**Result**: www.efustryton.co.za updated
- Proxied: false → true ✅ (Orange cloud enabled)
- TTL: 3600 → 1 ✅ (Automatic)

### Example: Disable Proxy and Set Custom TTL
1. Select `cf_action`: `update_settings`
2. Select `settings_level`: `record`
3. Select `existing_domain`: `efustryton.co.za`
4. Enter `record_name`: `api`
5. Set `record_proxied`: `false`
6. Set `record_ttl`: `300` (5 minutes)
7. Run Job Template

**Result**: api.efustryton.co.za updated
- Proxied: true → false ✅ (Grey cloud)
- TTL: 1 → 300 ✅ (5 minutes)

---

## AWX Survey Design Recommendations

### Conditional Field Visibility

Use AWX's conditional survey logic to show only relevant fields:

#### When `settings_level == 'zone'`:
Show:
- existing_domain
- cache_level
- browser_cache_ttl
- ssl_mode
- min_tls_version
- security_level
- http3, http2, brotli
- development_mode
- (all zone-level settings)

Hide:
- record_name
- record_type
- record_proxied
- record_ttl
- record_value

#### When `settings_level == 'record'`:
Show:
- existing_domain
- record_name
- record_type (optional)
- record_proxied
- record_ttl
- record_value (optional)

Hide:
- All zone-level settings

### Dropdown Value Suggestions

#### cache_level
```
- basic: Basic caching
- simplified: Simplified caching (default)
- aggressive: Aggressive caching (recommended)
```

#### browser_cache_ttl (seconds)
```
- 14400: 4 hours
- 21600: 6 hours
- 43200: 12 hours
- 86400: 1 day (recommended)
```

#### ssl_mode
```
- off: No SSL
- flexible: Flexible SSL (not recommended)
- full: Full SSL
- full_strict: Full SSL (Strict) - recommended
```

#### min_tls_version
```
- 1.0: TLS 1.0 (legacy)
- 1.1: TLS 1.1 (legacy)
- 1.2: TLS 1.2 (recommended)
- 1.3: TLS 1.3 (most secure)
```

#### security_level
```
- essentially_off: Off
- low: Low
- medium: Medium (default)
- high: High
- under_attack: I'm Under Attack!
```

#### record_ttl (seconds)
```
- 1: Automatic (recommended for proxied)
- 60: 1 minute
- 300: 5 minutes
- 600: 10 minutes
- 1800: 30 minutes
- 3600: 1 hour (default)
- 86400: 1 day
```

---

## Common Use Cases

### 1. Enable Aggressive Caching
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
cache_level: aggressive
browser_cache_ttl: 86400
```

### 2. Secure SSL Configuration
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
ssl_mode: full_strict
min_tls_version: "1.2"
always_use_https: "on"
automatic_https_rewrites: "on"
```

### 3. Enable Modern Protocols
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
http3: "on"
tls_1_3: "on"
brotli: "on"
```

### 4. Development Mode (Bypass Cache)
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
development_mode: "on"
```
**Note**: Remember to turn off after testing!

### 5. Proxy Critical Services
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: app
record_type: A
record_proxied: true
```

### 6. DNS-Only for Mail/SSH
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: mail
record_proxied: false
record_ttl: 3600
```

---

## Verification

### Check Zone Settings
After running zone-level updates, verify in Cloudflare Dashboard:
1. Go to Cloudflare Dashboard
2. Select domain
3. Navigate to SSL/TLS, Speed, Caching, etc. tabs
4. Verify settings match what you configured

### Check Record Settings
After running record-level updates:
1. Go to DNS tab in Cloudflare Dashboard
2. Find the record
3. Verify:
   - Orange cloud (proxied) vs Grey cloud (DNS only)
   - TTL value
   - Record content

### Using AWX Output
Check the job output in AWX:
```
============================================================
CLOUDFLARE AUTOMATION - EXECUTION SUMMARY
============================================================

Action: UPDATE_SETTINGS
Domain: example.com
Settings Level: ZONE

[GLOBAL LEVEL] Changes: 3 setting(s)
  - SUCCESS: cache_level = aggressive
  - SUCCESS: http3 = on
  - FAILED: browser_cache_ttl = 21600
```

---

## Troubleshooting

### "Setting not found" Error
**Cause**: Setting not available on your Cloudflare plan  
**Solution**: Check plan features, remove unsupported settings from job

### "Record not found" Error
**Cause**: Record doesn't exist or wrong name  
**Solution**: 
1. Verify record exists in DNS tab
2. Check record_name (include subdomain)
3. Add record_type if multiple records with same name

### Some Settings Failed
**Cause**: Free plan limitations or invalid values  
**Solution**: Review output to see which settings succeeded/failed

### "ttl must be a number" Error
**Cause**: TTL value is not a valid integer  
**Solution**: Use valid TTL values (1, 60, 300, 600, 1800, 3600, 86400)

---

## Best Practices

1. **Test in Development First**
   - Use development_mode: "on" for testing
   - Verify settings before applying to production

2. **Document Changes**
   - Note current settings before changing
   - Track what was changed and why

3. **Batch Related Settings**
   - Update all SSL settings together
   - Update all performance settings together

4. **Monitor After Changes**
   - Check website functionality
   - Monitor analytics for impact
   - Be ready to revert if needed

5. **Use Appropriate Cache Levels**
   - Static sites: aggressive
   - Dynamic sites: simplified or basic
   - Development: development_mode on (temporarily)

6. **Proxy Decisions**
   - Web traffic (HTTP/HTTPS): proxied = true
   - Direct access (SSH, FTP, mail): proxied = false
   - API endpoints: case-by-case decision

---

## Related Documentation
- [UPDATE-SETTINGS-GUIDE.md](./UPDATE-SETTINGS-GUIDE.md) - Complete reference
- [CLOUDFLARE-WORKFLOW-LEVELS.md](./CLOUDFLARE-WORKFLOW-LEVELS.md) - Level categorization
- [DYNAMIC-SURVEY-DROPDOWNS.md](./DYNAMIC-SURVEY-DROPDOWNS.md) - Survey configuration

---

## Support

For issues or questions:
1. Check AWX job output for detailed error messages
2. Verify Cloudflare API token has correct permissions
3. Review Cloudflare Dashboard for actual settings
4. Check documentation for valid values
