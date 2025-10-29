# Survey Fields to Cloudflare API Mapping

This document shows how AWX survey fields flow through the playbook to Cloudflare's API.

## Data Flow Architecture

```
┌─────────────────┐
│  AWX Survey     │  User fills out survey in AWX UI
│  (Job Template) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  extra_vars     │  Survey values passed as Ansible variables
│  (Playbook)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Jinja2         │  Template renders JSON with survey values
│  Template       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Cloudflare API │  HTTP PATCH/POST with rendered JSON
│  (Rules/Zone)   │
└─────────────────┘
```

---

## Survey Field Mappings

### 1. `edge_ttl_value` ✅

**Survey Configuration:**
- **Type**: `integer`
- **Default**: `7200` (2 hours)
- **Range**: 60 - 31536000 (1 minute to 1 year)
- **Description**: "Edge cache TTL value in seconds"

**Playbook Usage:**
- **File**: `automation/templates/cloudflare_modern_rules.j2`
- **Lines**: 68-78
- **Rule Type**: `edge_cache_ttl`
- **Trigger**: When `rule_action` includes `'edge_cache_ttl'` or `'all'`

**Template Code:**
```jinja
{% elif rule_action == 'edge_cache_ttl' %}
{
  "action": "set_cache_settings",
  "action_parameters": {
    "edge_ttl": {
      "mode": "override_origin",
      "default": {{ edge_ttl_value | default(7200) }}
    }
  },
  "expression": "(http.host eq \"{{ domain }}\")",
  "description": "Set Edge Cache TTL to {{ edge_ttl_value | default(7200) }} seconds for {{ domain }}",
  "enabled": true
}
{% endif %}
```

**Cloudflare API:**
- **Endpoint**: `POST /zones/{zone_id}/rulesets/phases/http_request_cache_settings/entrypoint`
- **Ruleset Phase**: `http_request_cache_settings`
- **Result**: Sets how long Cloudflare's edge servers cache content

---

### 2. `cache_level_mode` ✅

**Survey Configuration:**
- **Type**: `multiplechoice`
- **Default**: `bypass`
- **Options**: 
  - `bypass` - No caching
  - `standard` - Cache static files (images, CSS, JS)
  - `aggressive` - Cache all static and semi-static content
  - `cache_everything` - Cache all content including HTML
- **Description**: "Cache level mode for the domain"

**Playbook Usage:**
- **File**: `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`
- **Lines**: 76-77
- **Setting Type**: `Zone Setting` (not a rule)
- **Trigger**: When `cf_action` includes `'create_domain'`, `'standardize'`, or `'sync'`

**Playbook Code:**
```yaml
- name: Merge zone settings with survey values
  set_fact:
    merged_zone_settings: "{{ standard_zone_settings | default({}) | combine({'ssl_recommender': (ssl_tls_recommender | default('enabled')), 'cache_level': (cache_level_mode | default('standard'))}) }}"
```

**Cloudflare API:**
- **Endpoint**: `PATCH /zones/{zone_id}/settings/cache_level`
- **API Section**: Zone Settings (not Rules API)
- **Result**: Controls what types of content Cloudflare caches at the zone level

**Important Note:**
- ⚠️ `cache_level` is NOT supported in the Rules API (Results in "invalid JSON: unknown field cache_level")
- ✅ Must be applied as a zone-level setting via Zone Settings API
- Applied automatically when standardizing zones or creating new domains

---

### 3. `ssl_tls_recommender` ✅

**Survey Configuration:**
- **Type**: `multiplechoice`
- **Default**: `enabled`
- **Options**: 
  - `enabled` - SSL/TLS recommender ON
  - `disabled` - SSL/TLS recommender OFF
- **Description**: "Enable/disable SSL/TLS recommender"

**Playbook Usage:**
- **File**: `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`
- **Lines**: 81-93 (zone settings section)
- **Trigger**: When `cf_action` is `create_domain`, `standardize`, or `sync`

**Playbook Code:**
```yaml
- name: Merge zone settings with survey values
  set_fact:
    merged_zone_settings: "{{ standard_zone_settings | default({}) | combine({'ssl_recommender': (ssl_tls_recommender | default('enabled'))}) }}"

- name: Apply standard zone settings
  uri:
    url: "https://api.cloudflare.com/client/v4/zones/{{ zone_id }}/settings/{{ item.key }}"
    method: PATCH
    headers:
      Authorization: "Bearer {{ lookup('env','CLOUDFLARE_API_TOKEN') }}"
      Content-Type: "application/json"
    body_format: json
    body:
      value: "{{ item.value }}"
    return_content: true
    validate_certs: "{{ cf_validate_certs | default(true) }}"
  loop: "{{ merged_zone_settings | dict2items }}"
```

**Cloudflare API:**
- **Endpoint**: `PATCH /zones/{zone_id}/settings/ssl_recommender`
- **Setting Type**: Zone-level setting (not a rule)
- **Result**: Enables/disables automatic SSL/TLS encryption recommendations

---

## Rule Action Dropdown

When you select `rule_action = 'all'` (the default), the playbook automatically applies **7 rules**:

1. `force_https` - Redirect HTTP to HTTPS
2. `redirect_to_www` - Redirect apex to www
3. `redirect_from_www` - Redirect www to apex
4. **`cache_level`** - Uses `cache_level_mode` survey field ✅
5. **`edge_cache_ttl`** - Uses `edge_ttl_value` survey field ✅
6. **`argo_smart_routing`** - Enables Argo Smart Routing
7. `browser_cache_ttl` - Sets browser cache TTL

**Playbook Code (Line 152):**
```yaml
rule_actions_to_apply: >-
  {{ [rule_action] if rule_action != 'all' else ['force_https', 'redirect_to_www', 'redirect_from_www', 'cache_level', 'edge_cache_ttl', 'argo_smart_routing', 'browser_cache_ttl'] }}
```

---

## Testing Your Changes

### 1. Create a Test Domain
```bash
# Run AWX job with these survey values:
cf_action: create_domain
domain: test.example.com
rule_action: all
edge_ttl_value: 3600
cache_level_mode: standard
ssl_tls_recommender: enabled
```

### 2. Verify in Cloudflare Dashboard
- **Rules**: Go to your zone → Rules → Configuration Rules
  - Should see "Edge Cache TTL" rule with 3600 seconds
  - Should see "Cache Level" rule with "standard" mode
- **SSL/TLS Settings**: Go to SSL/TLS → Overview
  - Should see SSL/TLS Recommender toggle set to "ON"

### 3. Check AWX Job Output
Look for these debug messages:
```
[GLOBAL LEVEL] Zone Settings Applied: test.example.com
  Settings: ..., ssl_recommender=enabled

[DOMAIN LEVEL] Modern rule applied: cache_level
  Domain: test.example.com
  Cache Level: standard

[DOMAIN LEVEL] Modern rule applied: edge_cache_ttl
  Domain: test.example.com
  Edge TTL: 3600 seconds
```

---

## Files Modified

1. `automation/templates/cloudflare_modern_rules.j2` - Updated cache_level rule to use `cache_level_mode`
2. `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml` - Added SSL/TLS recommender merging
3. `automation/vars/cloudflare_standard_zone_settings.yml` - Added `ssl_recommender: "on"` default
4. AWX Survey (Job Template 21) - Added 3 new survey fields

---

## Summary

✅ **All 3 survey fields are now connected to Cloudflare:**

| Survey Field | Used In | API Endpoint | Status |
|-------------|---------|--------------|--------|
| `edge_ttl_value` | Template (rules) | Rules API | ✅ Working |
| `cache_level_mode` | Template (rules) | Rules API | ✅ Working |
| `ssl_tls_recommender` | Playbook (zone settings) | Zone Settings API | ✅ Working |

**Data Flow:**
1. User fills out AWX survey
2. Survey values passed as `extra_vars` to playbook
3. Playbook merges values with defaults
4. Template renders Jinja2 with survey values
5. Cloudflare API receives rendered JSON/values
6. Settings applied to your domain
