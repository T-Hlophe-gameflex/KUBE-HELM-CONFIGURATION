# Cache Level Implementation Guide

## Overview

The `cache_level` functionality is implemented using **TWO separate Cloudflare APIs** working together:

### 1. Rules API - Cache Boolean (Enable/Disable)
- **What it does**: Enables or disables caching entirely
- **API**: POST `/zones/{zone_id}/rulesets/phases/http_request_cache_settings/entrypoint`
- **Field**: `"cache": true` or `"cache": false`
- **Trigger**: When `rule_action` includes `'cache_level'` or `'all'`

### 2. Zone Settings API - Cache Level Mode
- **What it does**: Sets the cache level (bypass/standard/aggressive/cache_everything)
- **API**: PATCH `/zones/{zone_id}/settings/cache_level`
- **Field**: `"value": "bypass|standard|aggressive|cache_everything"`
- **Trigger**: When `cf_action` is `'create_domain'`, `'standardize'`, `'sync'`, or `'create_record'`

---

## How It Works Together

When you run `create_record` with `rule_action=all`:

```yaml
# Step 1: Zone Settings Applied (cache_level_mode)
PATCH /zones/{zone_id}/settings/cache_level
Body: {"value": "aggressive"}  # From cache_level_mode survey field

# Step 2: Cache Rule Applied (cache_level)
POST /zones/{zone_id}/rulesets/phases/http_request_cache_settings/entrypoint
Body: {
  "action": "set_cache_settings",
  "action_parameters": {
    "cache": true  # Enables caching
  }
}
```

---

## Survey Fields

### `rule_action` (Dropdown)
- **Options**: none, all, force_https, redirect_to_www, **cache_level**, edge_cache_ttl, argo_smart_routing, etc.
- **Default**: `all`
- **Effect**: When set to `cache_level` or `all`, creates a cache rule (cache: true)

### `cache_level_mode` (Dropdown)
- **Options**: bypass, standard, aggressive, cache_everything
- **Default**: `bypass`
- **Effect**: Sets the zone-level cache mode via Zone Settings API

---

## Actions That Apply cache_level

| Action | Zone Settings | Cache Rule | Result |
|--------|--------------|------------|--------|
| `create_domain` | ✅ Yes | ✅ Yes (if rule_action=all) | Full cache control |
| `create_record` | ✅ Yes | ✅ Yes (if rule_action=all) | Full cache control |
| `standardize` | ✅ Yes | ❌ No | Zone settings only |
| `sync` | ✅ Yes | ❌ No | Zone settings only |
| `update_record` | ❌ No | ✅ Yes (if rule_action=all) | Rule only |
| `delete_record` | ❌ No | ❌ No | No cache changes |

---

## Testing

### Test 1: Create Record with Full Cache Control

```bash
bash automation/scripts/test-playbook-local.sh
# Select option 2 or 3 (create record)
# Domain: efustryton.co.za
# Record: test-cache
# Type: CNAME
# Value: efutech.co.za
# rule_action: all (or cache_level)
# cache_level_mode: aggressive
```

**Expected Output:**
```
[GLOBAL LEVEL] Zone Settings Applied: efustryton.co.za
  Settings: cache_level=aggressive

[DOMAIN LEVEL] Modern rule applied: cache_level
  Action: cache_level
  Phase: http_request_cache_settings
  Description: Set cache enabled for efustryton.co.za

[SUCCESS] Create Record: test-cache.efustryton.co.za (CNAME)
```

### Test 2: Standardize Zone (Zone Settings Only)

```bash
ansible-playbook automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml \
  -e "cf_action=standardize" \
  -e "domain=efustryton.co.za" \
  -e "cache_level_mode=standard"
```

**Expected Output:**
```
[GLOBAL LEVEL] Zone Settings Applied: efustryton.co.za
  Settings: cache_level=standard
```

---

## Important Notes

### ⚠️ Cloudflare API Limitation

The Rules API does **NOT** support the `cache_level` field. This was discovered during testing:

```json
// ❌ WRONG - Causes API error
{
  "action": "set_cache_settings",
  "action_parameters": {
    "cache": true,
    "cache_level": "aggressive"  // ← NOT SUPPORTED
  }
}

// ✅ CORRECT
{
  "action": "set_cache_settings",
  "action_parameters": {
    "cache": true  // Only boolean supported
  }
}
```

**Error Message (if cache_level field included):**
```
"invalid JSON: unknown field cache_level"
```

### 🔧 Why Two APIs?

- **Rules API**: Granular control (per-rule, per-expression)
- **Zone Settings API**: Global control (entire zone)

By using both:
- Rule enables caching for the specific domain/expression
- Zone setting defines what gets cached (static only vs everything)

---

## File Locations

- **Main Playbook**: `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`
  - Line 56: Zone settings trigger (includes `create_record`)
  - Line 72: Zone settings merge (includes `cache_level_mode`)
  - Line 142: Rules list (includes `cache_level`)

- **Template**: `automation/templates/cloudflare_modern_rules.j2`
  - Lines 58-66: cache_level rule definition

- **Zone Settings**: `automation/vars/cloudflare_standard_zone_settings.yml`
  - Line 8: Default cache_level (overridden by survey)

---

## Troubleshooting

### Issue: cache_level not applied
**Check:**
1. Is `cf_action` one of: `create_domain`, `standardize`, `sync`, or `create_record`?
2. Is `cache_level_mode` survey field set?
3. Check zone settings output in playbook logs

### Issue: Cache rule not created
**Check:**
1. Is `rule_action` set to `cache_level` or `all`?
2. Check Modern Rules section in playbook logs
3. Verify ruleset exists for `http_request_cache_settings` phase

### Issue: API error "invalid JSON"
**Cause:** Template has `cache_level` field (not supported by Rules API)
**Fix:** Ensure template only has `"cache": true/false` boolean

---

## Commit History

- `aa061f9`: Move cache_level from Rules API to Zone Settings API
- `34305a8`: Enable cache_level for create_record action
- `637d8ee`: Remove unsupported cache_level field from template

---

## References

- [Cloudflare Rules API Docs](https://developers.cloudflare.com/api/operations/zone-rulesets-update-zone-ruleset)
- [Cloudflare Zone Settings API](https://developers.cloudflare.com/api/operations/zone-settings-edit-zone-settings-info)
- [Cache Settings Action Parameters](https://developers.cloudflare.com/ruleset-engine/rules-language/actions/#set-cache-settings)
