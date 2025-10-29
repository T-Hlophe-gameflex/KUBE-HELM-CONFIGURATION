# Cloudflare Update Settings Guide

## Overview
The `update_settings` action provides a unified interface to update Cloudflare configuration at three different levels:

1. **Zone Level** - Settings that apply to an entire domain/zone
2. **Record Level** - Settings for individual DNS records
3. **Account Level** - Global account-wide settings (planned)

## Usage

### Basic Syntax
```yaml
cf_action: update_settings
settings_level: <zone|record|account>
resolved_domain: example.com
# Additional parameters based on settings_level
```

---

## Zone Level Settings

### Overview
Zone settings control behavior for an entire domain. These settings affect all traffic and resources under the domain.

### Usage
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com  # Or use domain dropdown
```

### Available Zone Settings

#### Performance Settings
| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `cache_level` | Cache behavior | `basic`, `simplified`, `aggressive` | `aggressive` |
| `browser_cache_ttl` | Browser cache TTL (seconds) | `30`-`31536000` | `14400` |
| `rocket_loader` | Async JavaScript loading | `on`, `off` | `off` |
| `mirage` | Image optimization | `on`, `off` | `off` |
| `polish` | Image compression | `off`, `lossless`, `lossy` | `off` |
| `webp` | WebP image format | `on`, `off` | `off` |
| `brotli` | Brotli compression | `on`, `off` | `on` |
| `http2` | HTTP/2 protocol | `on`, `off` | `on` |
| `http3` | HTTP/3 (QUIC) | `on`, `off` | `off` |
| `early_hints` | Early Hints support | `on`, `off` | `off` |
| `zero_rtt` | 0-RTT connection resumption | `on`, `off` | `off` |

#### Security Settings
| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `ssl_mode` | SSL/TLS mode | `off`, `flexible`, `full`, `full_strict` | `full_strict` |
| `min_tls_version` | Minimum TLS version | `1.0`, `1.1`, `1.2`, `1.3` | `1.2` |
| `tls_1_3` | TLS 1.3 protocol | `on`, `off`, `zrt` | `on` |
| `always_use_https` | Redirect HTTP to HTTPS | `on`, `off` | `off` |
| `automatic_https_rewrites` | Rewrite HTTP links to HTTPS | `on`, `off` | `on` |
| `opportunistic_encryption` | Opportunistic encryption | `on`, `off` | `on` |
| `security_level` | Security level | `off`, `essentially_off`, `low`, `medium`, `high`, `under_attack` | `medium` |
| `challenge_ttl` | Challenge TTL (seconds) | `300`-`2592000` | `1800` |
| `browser_check` | Browser integrity check | `on`, `off` | `on` |
| `waf` | Web Application Firewall | `on`, `off` | `off` |
| `hotlink_protection` | Prevent image hotlinking | `on`, `off` | `off` |

#### Network Settings
| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `ipv6` | IPv6 connectivity | `on`, `off` | `on` |
| `websockets` | WebSocket connections | `on`, `off` | `on` |

#### Content Settings
| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `email_obfuscation` | Obfuscate email addresses | `on`, `off` | `on` |
| `server_side_exclude` | Server-side excludes | `on`, `off` | `on` |
| `development_mode` | Development mode (bypass cache) | `on`, `off` | `off` |
| `image_resizing` | On-the-fly image resizing | `on`, `off` | `off` |

### Examples

#### Update Performance Settings
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
cache_level: aggressive
browser_cache_ttl: 21600  # 6 hours
http3: "on"
brotli: "on"
```

#### Update Security Settings
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
ssl_mode: full_strict
min_tls_version: "1.2"
tls_1_3: "on"
always_use_https: "on"
automatic_https_rewrites: "on"
security_level: medium
```

#### Development Mode (Bypass Cache)
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
development_mode: "on"
```

---

## Record Level Settings

### Overview
Record settings control behavior for individual DNS records, primarily proxy status and TTL.

### Usage
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: subdomain  # Or use record dropdown
```

### Available Record Settings

| Parameter | Description | Values | Default |
|-----------|-------------|--------|---------|
| `record_proxied` | Proxy through Cloudflare | `true`, `false` | Varies by type |
| `record_ttl` | DNS TTL (seconds) | `1` (auto), `60`-`86400` | `1` |
| `record_value` | Update record content | Any valid IP/CNAME/etc | Current value |

### Proxy Status Notes
- **Proxied (Orange Cloud)**: Traffic routes through Cloudflare (DDoS protection, caching, etc.)
- **DNS Only (Grey Cloud)**: Direct DNS resolution without Cloudflare proxy
- Some record types (MX, TXT, SRV) cannot be proxied

### TTL Notes
- `1` = Automatic TTL (recommended for proxied records)
- `60`-`86400` = Manual TTL in seconds
- TTL is ignored for proxied records (always uses Cloudflare's TTL)

### Examples

#### Enable Proxy for Record
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: www
record_proxied: true
record_ttl: 1  # Auto
```

#### Disable Proxy and Set Custom TTL
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: api
record_proxied: false
record_ttl: 300  # 5 minutes
```

#### Update Record Content and Proxy
```yaml
cf_action: update_settings
settings_level: record
existing_domain: example.com
record_name: app
record_type: A
record_value: 203.0.113.50
record_proxied: true
```

---

## Account Level Settings

### Overview
Account-level settings affect all zones under your Cloudflare account.

### Status
🚧 **Coming Soon** - Account-level settings implementation is planned for future release.

### Planned Features
- Subscription management
- Billing preferences
- Account member settings
- Default zone settings
- API token management

---

## AWX Survey Configuration

### Dropdown Fields Categorization

#### Zone Level Fields
These dropdowns should be visible when `settings_level = zone`:
- `existing_domain` - Select domain to update
- `cache_level` - Cache behavior
- `ssl_mode` - SSL/TLS mode
- `min_tls_version` - Minimum TLS version
- `security_level` - Security level
- `browser_cache_ttl` - Browser cache TTL (dropdown or number input)

#### Record Level Fields
These dropdowns should be visible when `settings_level = record`:
- `existing_domain` - Select domain
- `existing_record` - Select record to update
- `record_name` - Or specify new record name
- `record_type` - Record type filter
- `record_proxied` - Proxy status (boolean)
- `record_ttl` - TTL value (dropdown: Auto, 5min, 30min, 1hour, 1day)

#### Conditional Survey Logic (Recommended)
```yaml
# Show zone settings when:
settings_level == 'zone'

# Show record settings when:
settings_level == 'record'

# Show account settings when:
settings_level == 'account'
```

---

## API Reference

### Zone Settings Endpoint
```
PATCH /zones/{zone_id}/settings/{setting_id}
```

**Request Body:**
```json
{
  "value": "<setting_value>"
}
```

**Response:**
```json
{
  "success": true,
  "result": {
    "id": "cache_level",
    "value": "aggressive",
    "modified_on": "2024-01-15T12:00:00Z"
  }
}
```

### DNS Record Update Endpoint
```
PUT /zones/{zone_id}/dns_records/{record_id}
```

**Request Body:**
```json
{
  "type": "A",
  "name": "example.com",
  "content": "203.0.113.10",
  "ttl": 1,
  "proxied": true
}
```

---

## Implementation Notes

### Zone Settings Implementation
- Uses individual PATCH requests per setting (recommended by Cloudflare)
- Skips undefined parameters (only updates specified settings)
- Returns success/failure count for each setting
- Ignores failures for unsupported settings on free plans

### Record Settings Implementation
- Retrieves current record details
- Merges updated values with existing values
- Uses PUT to update complete record
- Validates record exists before updating

### Error Handling
- Individual setting failures don't stop other updates
- Failed settings are tracked and reported in summary
- Unknown settings are skipped with warning

### Performance Considerations
- Zone settings: Multiple API calls (one per setting)
- Record settings: 3 API calls (lookup zone, lookup record, update record)
- Batch updates recommended for multiple settings

---

## Troubleshooting

### Common Issues

#### "Setting not found" Error
**Cause**: Setting not available on your plan or deprecated  
**Solution**: Check Cloudflare plan features, remove unsupported settings

#### "Record not found" Error
**Cause**: Record doesn't exist or wrong record_name  
**Solution**: Verify record exists, check record_name includes subdomain

#### Zone Settings Update Fails
**Cause**: Invalid value for setting  
**Solution**: Check allowed values in settings table above

#### Record Update Requires record_type
**Cause**: Multiple records with same name  
**Solution**: Specify `record_type` to identify exact record

---

## Best Practices

### Zone Settings
1. Update multiple related settings together (e.g., all SSL settings)
2. Test in development environment first
3. Document current settings before changes
4. Use aggressive caching with appropriate TTLs
5. Enable security features appropriate for content type

### Record Settings
1. Use automatic TTL (`1`) for proxied records
2. Set longer TTLs for stable records
3. Disable proxy for records requiring direct access (SSH, FTP, mail)
4. Document proxy status for troubleshooting

### Performance
1. Batch multiple setting updates in single playbook run
2. Use `development_mode: on` temporarily for testing
3. Monitor setting changes via Cloudflare dashboard
4. Schedule settings updates during low-traffic periods

---

## Migration from Old Actions

### Old: Manual API Calls
```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/ZONE_ID/settings/cache_level" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"value":"aggressive"}'
```

### New: Unified update_settings
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
cache_level: aggressive
```

### Old: standardize action (still supported)
```yaml
cf_action: standardize
existing_domain: example.com
```

### New: update_settings with specific settings
```yaml
cf_action: update_settings
settings_level: zone
existing_domain: example.com
cache_level: aggressive
ssl_mode: full_strict
min_tls_version: "1.2"
```

---

## Appendix

### Full Settings List
For complete list of all 60+ Cloudflare zone settings, see:
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/operations/zone-settings-list)
- Current implementation supports 28 most common settings

### Related Documentation
- [CLOUDFLARE-WORKFLOW-LEVELS.md](./CLOUDFLARE-WORKFLOW-LEVELS.md) - Workflow categorization
- [ZONE-SETTINGS-TROUBLESHOOTING.md](./ZONE-SETTINGS-TROUBLESHOOTING.md) - Troubleshooting guide
- [DYNAMIC-SURVEY-DROPDOWNS.md](./DYNAMIC-SURVEY-DROPDOWNS.md) - Survey configuration

### Change Log
- **2024-01-XX**: Initial implementation with zone and record level support
- **Future**: Account-level settings implementation planned
