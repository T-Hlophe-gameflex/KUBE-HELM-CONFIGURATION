# Cloudflare Automation Workflows - Configuration Level Breakdown

## Overview

This document explains how the Cloudflare automation system handles different **configuration levels** and workflows. The automation is designed to apply settings at the right scope based on the action being performed.

---

## 🏗️ Architecture: Three Configuration Levels

```
┌─────────────────────────────────────────────────────────────┐
│                    CLOUDFLARE AUTOMATION                     │
└─────────────────────────────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌───────────────┐ ┌──────────────┐ ┌────────────────┐
    │  Domain Level │ │ Global Level │ │ Platform/DNS   │
    │               │ │              │ │ Level          │
    └───────────────┘ └──────────────┘ └────────────────┘
    Zone-specific     Account-wide     Infrastructure
    settings          rules            + DNS records
```

---

## 1️⃣ Domain Level Configuration Workflow

### 📌 Scope
**Target:** Individual zone (domain)  
**Affects:** Only the specified domain

### 🎯 What It Configures

| Configuration Type | Examples | Applied Via |
|-------------------|----------|-------------|
| **Zone Settings** | SSL/TLS mode, cache level, development mode, security level | Cloudflare Zone Settings API |
| **Firewall Rules** (Modern) | Force HTTPS, cache rules, redirects | Cloudflare Rules API (rulesets) |
| **Page Rules** (Legacy) | Cache everything, forward URL, edge cache TTL | Cloudflare Page Rules API |
| **DNS Records** | A, AAAA, CNAME, MX, TXT | Cloudflare DNS API |

### 🔄 Workflow Flow

```
User Action: "Create Domain" or "Standardize Domain"
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Zone Creation/Validation                           │
│  - Check if zone exists in Cloudflare                       │
│  - Create zone if doesn't exist (create_domain)             │
│  - Retrieve zone_id                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Apply Zone Settings (Domain Level)                 │
│  - SSL/TLS mode (e.g., "flexible", "full")                  │
│  - Cache level (e.g., "aggressive")                         │
│  - Security level (e.g., "medium")                          │
│  - Development mode (on/off)                                │
│  - Auto minify (HTML, CSS, JS)                              │
│  - Brotli compression                                       │
│  - HTTP/2, HTTP/3                                           │
│  - TLS 1.3                                                  │
│                                                              │
│  API: PATCH /zones/{zone_id}/settings/{setting_name}        │
│  Each setting sent individually to Cloudflare               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Apply Firewall Rules (Domain Level)                │
│  - Force HTTPS redirect                                     │
│  - Cache level rules                                        │
│  - Browser cache TTL                                        │
│  - Security headers                                         │
│                                                              │
│  API: POST /zones/{zone_id}/rulesets/phases/.../entrypoint  │
│  Creates/updates ruleset for this zone only                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Verification & Reporting                           │
│  - List applied settings (success/failed)                   │
│  - List created rules                                       │
│  - Output summary                                           │
└─────────────────────────────────────────────────────────────┘
```

### 📝 Example: Standardize Domain Workflow

```yaml
# User Input (AWX Survey)
cf_action: standardize
domain: example.com

# Playbook Execution
- name: Standardize domain example.com
  tasks:
    - Get zone_id for example.com
    - Apply standard zone settings
      * ssl: "flexible"
      * cache_level: "aggressive"
      * security_level: "medium"
      * development_mode: "off"
    - Apply standard firewall rules
      * force_https: enabled
      * cache_level: enabled
    - Report results
```

### 🎛️ Configuration Source

**File:** `automation/vars/cloudflare_standard_zone_settings.yml`

```yaml
cloudflare_standard_zone_settings:
  # SSL/TLS Settings
  ssl: "flexible"
  ssl_recommender: "on"
  always_use_https: "on"
  
  # Cache Settings
  cache_level: "aggressive"
  browser_cache_ttl: 14400
  
  # Security Settings
  security_level: "medium"
  challenge_ttl: 1800
  
  # Performance Settings
  minify:
    css: "on"
    html: "on"
    js: "on"
  brotli: "on"
  http2: "on"
  http3: "on"
```

### 🚦 Actions That Trigger Domain Level

| Action | Zone Settings | Firewall Rules | Page Rules | DNS Records |
|--------|--------------|----------------|------------|-------------|
| `create_domain` | ✅ Yes | ✅ Yes | ✅ Yes | ➖ Optional |
| `standardize` | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| `sync` | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| `create_record` | ✅ Yes (cache) | ❌ No | ❌ No | ✅ Yes |

---

## 2️⃣ Global Level Configuration Workflow

### 📌 Scope
**Target:** Cloudflare account  
**Affects:** All zones in the account (when applicable)

### 🎯 What It Configures

| Configuration Type | Examples | Applied Via |
|-------------------|----------|-------------|
| **Account Rules** | Global rate limiting, WAF rules | Cloudflare Account-level Rulesets |
| **Access Policies** | IP allow/block lists | Cloudflare Access API |
| **Account Settings** | Default zone settings | Cloudflare Account API |

### 🔄 Workflow Flow

```
User Action: "Apply Global Security Policy"
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Account Validation                                 │
│  - Verify account access                                    │
│  - Check account tier (free/pro/business/enterprise)        │
│  - Validate permissions                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Apply Account-Level Rules                          │
│  - Global rate limiting                                     │
│  - WAF managed rulesets                                     │
│  - Custom firewall rules (applies to all zones)             │
│  - DDoS protection settings                                 │
│                                                              │
│  API: POST /accounts/{account_id}/rulesets                  │
│  Rules apply across all zones in account                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Default Zone Settings                              │
│  - Set defaults for new zones                               │
│  - Apply to existing zones (optional)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Verification & Reporting                           │
│  - List account-level rules                                 │
│  - Show zones affected                                      │
└─────────────────────────────────────────────────────────────┘
```

### 📝 Example: Global Security Hardening

```yaml
# User Input
cf_action: apply_global_security

# Playbook Execution
- name: Apply global security hardening
  tasks:
    - Apply account-level rate limiting
      * Limit: 1000 requests/minute per IP
      * Action: Challenge
    - Enable WAF managed rulesets
      * OWASP Core Ruleset
      * Cloudflare Managed Ruleset
    - Set default zone settings
      * security_level: "high"
      * challenge_ttl: 900
```

### 🎛️ Configuration Source

**File:** `automation/vars/cloudflare_global_settings.yml` (example)

```yaml
cloudflare_global_security:
  # Rate Limiting
  rate_limiting:
    enabled: true
    threshold: 1000
    period: 60
    action: "challenge"
  
  # WAF
  waf_managed_rulesets:
    - "cloudflare_owasp_core_ruleset"
    - "cloudflare_managed_ruleset"
  
  # Default Settings
  default_security_level: "high"
```

### 🚦 Actions That Trigger Global Level

| Action | Account Rules | WAF | Default Settings |
|--------|--------------|-----|------------------|
| `apply_global_security` | ✅ Yes | ✅ Yes | ✅ Yes |
| `standardize_all_zones` | ❌ No | ❌ No | ✅ Yes |

### ⚠️ Current Status

**Note:** Global level configuration is **not yet fully implemented** in the current playbook. The infrastructure supports it, but specific global actions need to be added.

**Future Implementation:**
```yaml
# Planned global actions
cf_action:
  - apply_global_security
  - enable_global_waf
  - set_account_defaults
  - standardize_all_zones
```

---

## 3️⃣ Platform/DNS Level Configuration Workflow

### 📌 Scope
**Target:** Infrastructure + DNS management  
**Affects:** DNS records, load balancers, origins

### 🎯 What It Configures

| Configuration Type | Examples | Applied Via |
|-------------------|----------|-------------|
| **DNS Records** | A, AAAA, CNAME, MX, TXT, SRV, CAA | Cloudflare DNS API |
| **Load Balancers** | Origin pools, health checks, steering | Cloudflare Load Balancing API |
| **Origin Configuration** | Origin servers, SSL verification | Zone-level settings |
| **DNS Settings** | Proxy status (orange/grey cloud) | DNS API |

### 🔄 Workflow Flow

```
User Action: "Create DNS Record"
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: DNS Record Validation                              │
│  - Validate record type (A, CNAME, etc.)                    │
│  - Validate record content (IP, hostname, etc.)             │
│  - Check for conflicts (duplicate records)                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Create/Update DNS Record                           │
│  - Create DNS record in Cloudflare                          │
│  - Set proxy status (proxied=true for orange cloud)         │
│  - Set TTL (auto if proxied, custom if not)                 │
│                                                              │
│  API: POST /zones/{zone_id}/dns_records                     │
│  {                                                           │
│    "type": "A",                                             │
│    "name": "www.example.com",                               │
│    "content": "192.0.2.1",                                  │
│    "proxied": true,                                         │
│    "ttl": 1                                                 │
│  }                                                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: Apply Record-Level Settings (Optional)             │
│  - If proxied, apply cache rules for this record            │
│  - If proxied, apply security rules                         │
│                                                              │
│  Triggered by: create_record with cache_level=true          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Update AWX Survey Dropdowns                        │
│  - Fetch all DNS records from all zones                     │
│  - Update "existing_record_name" dropdown in AWX            │
│  - Update "domain" dropdown (if new zone)                   │
│                                                              │
│  Script: update_awx_survey_dropdowns.sh                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 5: Verification & Reporting                           │
│  - Verify DNS propagation                                   │
│  - Display record details                                   │
└─────────────────────────────────────────────────────────────┘
```

### 📝 Example: Create DNS Record

```yaml
# User Input (AWX Survey)
cf_action: create_record
domain: example.com
record_type: A
record_name: api
record_content: 203.0.113.10
proxied: true
cache_level: true  # Apply cache settings to this record

# Playbook Execution
- name: Create DNS record
  tasks:
    - Get zone_id for example.com
    - Create A record: api.example.com → 203.0.113.10
      * proxied: true (orange cloud)
      * ttl: 1 (automatic)
    - Apply cache_level setting (because cache_level=true)
      * cache_level_mode: "aggressive"
    - Update AWX survey dropdowns
      * Add "api.example.com" to existing_record_name
    - Report results
```

### 🎛️ Record Types Supported

| Type | Purpose | Content Example | Proxied Support |
|------|---------|----------------|-----------------|
| **A** | IPv4 address | 192.0.2.1 | ✅ Yes |
| **AAAA** | IPv6 address | 2001:db8::1 | ✅ Yes |
| **CNAME** | Alias to another domain | target.example.com | ✅ Yes |
| **MX** | Mail server | mail.example.com | ❌ No |
| **TXT** | Text record | "v=spf1 include:_spf.example.com ~all" | ❌ No |
| **SRV** | Service record | 10 5 5060 sipserver.example.com | ❌ No |
| **CAA** | Certificate authority | 0 issue "letsencrypt.org" | ❌ No |

### 🚦 Actions That Trigger Platform/DNS Level

| Action | DNS Create | DNS Update | DNS Delete | Cache Settings | Load Balancer |
|--------|-----------|-----------|-----------|----------------|---------------|
| `create_record` | ✅ Yes | ❌ No | ❌ No | ✅ Optional | ❌ No |
| `update_record` | ❌ No | ✅ Yes | ❌ No | ❌ No | ❌ No |
| `delete_record` | ❌ No | ❌ No | ✅ Yes | ❌ No | ❌ No |

### 🔄 DNS Propagation

After creating/updating DNS records, propagation takes time:

```
Cloudflare Internal: ~1 second
Cloudflare Edge Network: ~3 seconds
Global DNS Resolvers: 1-5 minutes (depends on TTL)
User DNS Cache: Varies (can be hours if old TTL was high)
```

---

## 🔀 Workflow Interaction Matrix

### How Levels Work Together

```
┌─────────────────────────────────────────────────────────────┐
│  Example: Full Domain Setup                                 │
└─────────────────────────────────────────────────────────────┘

Action: create_domain + standardize + create_record

STEP 1: Platform Level - Create Zone
  └─> API: POST /zones
      Create: example.com

STEP 2: Domain Level - Apply Zone Settings
  └─> API: PATCH /zones/{id}/settings/ssl
      Set: ssl = "flexible"
  └─> API: PATCH /zones/{id}/settings/cache_level
      Set: cache_level = "aggressive"

STEP 3: Domain Level - Apply Firewall Rules
  └─> API: POST /zones/{id}/rulesets/phases/http_request_firewall_managed/entrypoint
      Create: force_https rule

STEP 4: Platform Level - Create DNS Record
  └─> API: POST /zones/{id}/dns_records
      Create: A record www.example.com → 192.0.2.1

STEP 5: Domain Level - Apply Record Cache Settings (Optional)
  └─> API: PATCH /zones/{id}/settings/cache_level
      Ensure: cache_level = "aggressive" (for proxied record)

STEP 6: Platform Level - Update Survey Dropdowns
  └─> Script: update_awx_survey_dropdowns.sh
      Update: AWX dropdowns with example.com + www.example.com
```

### Decision Tree: Which Level Is Used?

```
Question: What am I configuring?
    │
    ├─> Entire account / All zones
    │   └─> Global Level
    │       Examples: WAF, rate limiting, default settings
    │
    ├─> One specific domain's behavior
    │   └─> Domain Level
    │       Examples: SSL mode, cache level, firewall rules
    │
    └─> DNS records / Infrastructure
        └─> Platform/DNS Level
            Examples: A records, CNAMEs, load balancers
```

---

## 📊 Configuration Precedence

When settings conflict across levels, Cloudflare uses this precedence:

```
1. Account-Level Rules (Global)
   ↓ (can override zone settings)
   
2. Zone-Level Rules (Domain)
   ↓ (can override default settings)
   
3. DNS Record Settings (Platform)
   ↓ (specific to that record only)
   
4. Default Settings
   (fallback if nothing else specified)
```

### Example Precedence Scenario

```yaml
# Scenario: Cache Level Setting

Account Level (Global):
  default_cache_level: "standard"

Zone Level (Domain - example.com):
  cache_level: "aggressive"  ← This wins for example.com

DNS Record (Platform - api.example.com):
  proxied: true  ← Uses zone-level cache_level setting

DNS Record (Platform - mail.example.com):
  proxied: false  ← No caching (not proxied)

Result:
  - api.example.com: cache_level = "aggressive" (from zone)
  - mail.example.com: no caching (not proxied)
  - Other zones: cache_level = "standard" (from account default)
```

---

## 🎯 Action to Level Mapping

### Complete Action Matrix

| AWX Action | Domain Level | Global Level | Platform/DNS Level |
|-----------|-------------|-------------|-------------------|
| `create_domain` | ✅ Zone settings + Rules | ❌ | ✅ Create zone |
| `standardize` | ✅ Zone settings + Rules | ❌ | ❌ |
| `sync` | ✅ Zone settings + Rules | ❌ | ❌ |
| `create_record` | ✅ Cache settings (opt) | ❌ | ✅ DNS record |
| `update_record` | ❌ | ❌ | ✅ DNS record |
| `delete_record` | ❌ | ❌ | ✅ DNS record |
| `apply_global_security` | ❌ | ✅ Account rules | ❌ |
| `standardize_all_zones` | ✅ All zones | ✅ Set defaults | ❌ |

---

## 🛠️ Implementation Details

### How Playbook Determines Level

**File:** `unified-cloudflare-awx-playbook.yml`

```yaml
# Domain Level: Zone Settings
- name: Apply zone settings (Domain Level)
  when: cf_action in ['create_domain', 'standardize', 'sync', 'create_record']
  # Applies to specified domain only

# Domain Level: Firewall Rules
- name: Apply firewall rules (Domain Level)
  when: cf_action in ['create_domain', 'standardize', 'sync']
  # Applies rules to specified domain

# Platform Level: DNS Records
- name: Create DNS record (Platform Level)
  when: cf_action == 'create_record'
  # Creates DNS record in specified domain

# Platform Level: Update Survey Dropdowns
- name: Update AWX survey dropdowns (Platform Level)
  when: cf_action in ['create_domain', 'create_record']
  # Updates AWX UI with latest domains/records
```

### API Endpoints by Level

| Level | Primary Endpoints | Scope |
|-------|------------------|-------|
| **Domain** | `/zones/{zone_id}/settings/*` | Single zone |
| **Domain** | `/zones/{zone_id}/rulesets/*` | Single zone |
| **Global** | `/accounts/{account_id}/rulesets/*` | All zones |
| **Platform** | `/zones/{zone_id}/dns_records/*` | Single zone DNS |
| **Platform** | `/zones` | Zone management |

---

## 🔍 Troubleshooting by Level

### Domain Level Issues

**Problem:** SSL/TLS settings not applying

```bash
# Debug: Check zone settings API
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/ssl" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Expected response
{
  "success": true,
  "result": {
    "id": "ssl",
    "value": "flexible",
    "modified_on": "2025-10-29T12:00:00Z"
  }
}
```

**Problem:** Firewall rules not working

```bash
# Debug: List rulesets for zone
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Check for 403 Forbidden (free plan limitation)
```

### Global Level Issues

**Problem:** Account-level rules not visible

**Solution:** Verify account tier supports account-level rulesets (requires Business or Enterprise)

### Platform/DNS Level Issues

**Problem:** DNS record not resolving

```bash
# Debug: Check DNS record creation
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Verify record exists and is proxied (if orange cloud needed)
{
  "result": [
    {
      "type": "A",
      "name": "www.example.com",
      "content": "192.0.2.1",
      "proxied": true,  ← Should be true for Cloudflare features
      "ttl": 1
    }
  ]
}
```

**Problem:** Survey dropdowns not updating

```bash
# Debug: Run update script manually
export CLOUDFLARE_API_TOKEN="your_token"
bash automation/scripts/update_awx_survey_dropdowns.sh

# Check AWX survey spec
curl -X GET "http://localhost:8052/api/v2/job_templates/21/survey_spec/" \
  -u "admin:password"
```

---

## 📈 Best Practices by Level

### Domain Level
- ✅ Always validate zone_id before applying settings
- ✅ Use ignore_errors for settings not available on free plans
- ✅ Apply settings in logical order (SSL first, then cache, then rules)
- ✅ Test on one domain before bulk operations

### Global Level
- ✅ Verify account tier before applying account-level rules
- ✅ Test on non-production account first
- ✅ Document all global rules (affects all zones!)
- ✅ Use caution with default settings (applies to new zones)

### Platform/DNS Level
- ✅ Always verify DNS record doesn't exist before creating
- ✅ Set proxied=true for records needing Cloudflare features
- ✅ Use proper TTL values (1 for proxied, higher for non-proxied)
- ✅ Update survey dropdowns after DNS changes
- ✅ Wait for DNS propagation before testing

---

## 🚀 Future Enhancements

### Planned Features by Level

**Domain Level:**
- [ ] Bulk zone standardization
- [ ] Zone template system
- [ ] Custom ruleset templates
- [ ] Zone cloning

**Global Level:**
- [ ] Account-level security policies
- [ ] Default zone templates
- [ ] Multi-account management
- [ ] Account-level WAF configuration

**Platform/DNS Level:**
- [ ] Bulk DNS record import/export
- [ ] DNS record validation before creation
- [ ] Load balancer management
- [ ] Origin pool configuration
- [ ] Health check monitoring

---

## 📝 Summary

### Key Takeaways

1. **Domain Level** = Configure one specific domain's behavior (zone settings, firewall rules)
2. **Global Level** = Configure account-wide settings (applies to all zones)
3. **Platform/DNS Level** = Manage infrastructure (DNS records, load balancers, origins)

### When to Use Each Level

| If you want to... | Use this level |
|------------------|----------------|
| Change SSL mode for one domain | Domain Level |
| Add a firewall rule to one domain | Domain Level |
| Set default security for all zones | Global Level |
| Enable WAF for entire account | Global Level |
| Create a DNS record | Platform/DNS Level |
| Configure load balancer | Platform/DNS Level |
| Update AWX dropdowns | Platform/DNS Level |

### Workflow Triggers

```yaml
# Domain Level Workflow
cf_action: standardize
domain: example.com

# Global Level Workflow (future)
cf_action: apply_global_security
account_id: your_account_id

# Platform/DNS Level Workflow
cf_action: create_record
domain: example.com
record_type: A
record_name: www
```

---

## 📚 Related Documentation

- [Dynamic Survey Dropdowns Implementation](./DYNAMIC-SURVEY-DROPDOWNS.md)
- [Cache Level Implementation Guide](./CACHE-LEVEL-IMPLEMENTATION.md)
- [Zone Settings Troubleshooting](./ZONE-SETTINGS-TROUBLESHOOTING.md)
- [Cloudflare Workflows Overview](./cloudflare-workflows.md)

---

*Last Updated: October 29, 2025*  
*Commit: 888dbd2 - Dynamic dropdowns + Error handling*
