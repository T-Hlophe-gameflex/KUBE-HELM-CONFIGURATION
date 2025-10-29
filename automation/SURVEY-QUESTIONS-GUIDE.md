# AWX Survey Questions - Complete Guide

## Overview

The AWX survey questions are defined in **`automation/unified-cloudflare-awx-survey.json`** as a JSON array. This file contains 8 question objects that create the interactive form users see when launching the "Cloudflare AWX Survey" template.

---

## How It Works

```
JSON File → Apply Script → AWX API → AWX Database → Web UI Form → Playbook Variables
```

1. **JSON File** (`automation/unified-cloudflare-awx-survey.json`)
   - Contains array of question definitions
   - Pure data, no logic

2. **Apply Script** (`automation/apply-survey-post-method.sh`)
   - Reads the JSON file
   - POSTs to AWX API endpoint: `/api/v2/job_templates/21/survey_spec/`
   - AWX stores the configuration

3. **AWX Database**
   - Survey linked to Template ID 21
   - survey_enabled: true
   - survey_spec: { ...questions... }

4. **AWX Web UI**
   - Displays form when user clicks "Launch"
   - Collects user input
   - Passes values as extra_vars to playbook

5. **Ansible Playbook** (`automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`)
   - Receives variables from survey
   - Uses them to manage Cloudflare DNS

---

## Question Structure

Each question object in the JSON array has these properties:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `question_name` | string | Yes | Display name shown in the form |
| `question_description` | string | Yes | Help text shown to user |
| `required` | boolean | Yes | Whether field must be filled (true/false) |
| `type` | string | Yes | Field type: `text`, `integer`, or `multiplechoice` |
| `variable` | string | Yes | Ansible variable name used in playbook |
| `choices` | array | No | Array of options (required for `multiplechoice`) |
| `default` | string/number | No | Default value |
| `min` | number | No | Minimum value (for `integer` type) |
| `max` | number | No | Maximum value (for `integer` type) |

---

## Current Survey Questions

### 1. Cloudflare Action (cf_action)
**Type:** multiplechoice | **Required:** Yes

The action to perform in Cloudflare.

**Variable:** `cf_action`  
**Default:** `create_record`  
**Choices:**
- `create_domain` - Create a new domain/zone
- `create_record` - Create a new DNS record
- `update_record` - Update an existing DNS record
- `delete_record` - Delete a DNS record
- `clone_record` - Clone/duplicate a DNS record
- `standardize` - Apply standard settings to domain
- `sync` - Sync domain configuration

**Playbook Usage:**
```yaml
when: cf_action == 'create_domain'
when: cf_action in ['create_record', 'update_record']
```

---

### 2. Domain Name (domain)
**Type:** text | **Required:** Yes

The Cloudflare domain/zone to manage.

**Variable:** `domain`  
**Example:** `example.com`, `mysite.net`

**Playbook Usage:**
```yaml
- name: Get zone ID for domain
  uri:
    url: "https://api.cloudflare.com/client/v4/zones?name={{ domain }}"
```

---

### 3. Record Name (record_name)
**Type:** text | **Required:** No

The DNS record name (subdomain or @).

**Variable:** `record_name`  
**Examples:**
- `www` - Creates www.example.com
- `api` - Creates api.example.com
- `@` - Root domain (example.com)
- `` (empty) - Also means root domain

**Playbook Usage:**
```yaml
record: "{{ record_name | default(selected_record_name | default('')) }}"
```

---

### 4. Record Type (record_type)
**Type:** multiplechoice | **Required:** No

The DNS record type.

**Variable:** `record_type`  
**Default:** `A`  
**Choices:**
- `A` - IPv4 address
- `AAAA` - IPv6 address
- `CNAME` - Canonical name (alias)
- `TXT` - Text record
- `MX` - Mail exchange
- `SRV` - Service record
- `NS` - Name server
- `CAA` - Certificate authority authorization

**Playbook Usage:**
```yaml
when: record_type in ['A', 'AAAA', 'CNAME']
```

---

### 5. Record Content/Value (record_value)
**Type:** text | **Required:** No

The DNS record content (IP, hostname, or text).

**Variable:** `record_value`  
**Examples:**
- For A record: `192.168.1.1`
- For CNAME: `example.com`
- For TXT: `v=spf1 include:_spf.google.com ~all`

**Playbook Usage:**
```yaml
body:
  content: "{{ record_value }}"
```

---

### 6. Record TTL (global_ttl)
**Type:** integer | **Required:** No

Time to Live in seconds.

**Variable:** `global_ttl`  
**Default:** `3600` (1 hour)  
**Range:** 1 - 2147483647  
**Special Value:** `1` = Automatic (Cloudflare decides)

**Common Values:**
- `1` - Automatic
- `300` - 5 minutes
- `1800` - 30 minutes
- `3600` - 1 hour
- `86400` - 1 day

**Playbook Usage:**
```yaml
body:
  ttl: "{{ global_ttl | default(1) }}"
```

---

### 7. Proxy Status (global_proxied)
**Type:** multiplechoice | **Required:** No

Enable Cloudflare proxy (orange cloud icon).

**Variable:** `global_proxied`  
**Default:** `false`  
**Choices:**
- `true` - Proxy enabled (traffic goes through Cloudflare)
- `false` - DNS only (traffic goes directly to origin)

**Note:** Only works for A, AAAA, and CNAME records.

**Playbook Usage:**
```yaml
body:
  proxied: "{{ global_proxied | default(false) | bool }}"
```

---

### 8. Page Rule Template (selected_page_rule)
**Type:** multiplechoice | **Required:** No

Pre-configured page rule to apply to the domain.

**Variable:** `selected_page_rule`  
**Default:** `none`  
**Choices:**
- `none` - Don't apply any page rules
- `Browser Cache 5m` - Set browser cache TTL to 5 minutes
- `Cache Everything` - Cache all content including HTML
- `Block known bots` - Set high security for bot paths
- `all` - Apply all available page rule templates

**Playbook Usage:**
```yaml
when: selected_page_rule != 'none'
```

---

## Modifying Survey Questions

### Step 1: Edit the JSON File

```bash
nano automation/unified-cloudflare-awx-survey.json
```

### Step 2: Apply Changes to AWX

```bash
./automation/apply-survey-post-method.sh
```

### Step 3: Verify Changes

```bash
./automation/verify-survey.sh
```

### Step 4: Commit to Git

```bash
git add automation/unified-cloudflare-awx-survey.json
git commit -m "Update survey questions"
git push origin main
```

---

## Adding a New Question

To add a new question, insert a new JSON object into the array:

```json
{
  "question_name": "Priority",
  "question_description": "Record priority (for MX/SRV records)",
  "required": false,
  "type": "integer",
  "variable": "record_priority",
  "default": 10,
  "min": 0,
  "max": 65535
}
```

**Important:** 
- Add comma after previous question (if not last)
- Ensure valid JSON syntax
- Integer defaults must be numbers, not strings: `10` not `"10"`
- Run apply script after editing

---

## Question Types Explained

### text
Simple text input field.
```json
{
  "type": "text",
  "variable": "my_var",
  "default": ""
}
```

### integer
Number input with optional min/max constraints.
```json
{
  "type": "integer",
  "variable": "my_number",
  "default": 100,
  "min": 1,
  "max": 1000
}
```
**Important:** Default must be a number, not a string!

### multiplechoice
Dropdown selection.
```json
{
  "type": "multiplechoice",
  "variable": "my_choice",
  "choices": ["option1", "option2", "option3"],
  "default": "option1"
}
```

---

## Variable Naming Convention

Survey variables are passed to the playbook as extra_vars. Choose clear names:

- Use lowercase with underscores: `record_type`, `global_ttl`
- Use descriptive names: `cf_action` (not just `action`)
- Prefix globals: `global_ttl`, `global_proxied`
- Match playbook expectations

---

## Common Issues

### Integer Default as String
❌ **Wrong:** `"default": "3600"`  
✅ **Correct:** `"default": 3600`

### Missing Comma
❌ **Wrong:**
```json
{
  "variable": "var1"
}
{
  "variable": "var2"
}
```
✅ **Correct:**
```json
{
  "variable": "var1"
},
{
  "variable": "var2"
}
```

### Invalid Choice
If default is not in choices array:
```json
{
  "choices": ["A", "B", "C"],
  "default": "D"  ← Error!
}
```

---

## Related Files

| File | Purpose |
|------|---------|
| `automation/unified-cloudflare-awx-survey.json` | Survey question definitions |
| `automation/apply-survey-post-method.sh` | Apply survey to AWX |
| `automation/verify-survey.sh` | Verify survey configuration |
| `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml` | Playbook that uses survey variables |
| `automation/README-SURVEY-SETUP.md` | Setup documentation |
| `automation/SURVEY-QUESTIONS-GUIDE.md` | This file |

---

## Testing Your Survey

1. **Open AWX:** http://127.0.0.1:8052
2. **Navigate to:** Templates → "Cloudflare AWX Survey"
3. **Click:** Launch button (🚀)
4. **Verify:** All 8 questions appear
5. **Fill in:** Required fields (Cloudflare Action, Domain Name)
6. **Submit:** Click Next → Launch

---

## Advanced: Dynamic Survey Updates

The playbook can dynamically update survey choices based on API queries (domains list, records list, etc.). This happens when:

```yaml
when: update_awx_surveys | default(false)
```

This advanced feature queries Cloudflare API and updates dropdown choices automatically.

---

## Support

For issues:
1. Check JSON syntax: `python3 -m json.tool automation/unified-cloudflare-awx-survey.json`
2. Verify survey: `./automation/verify-survey.sh`
3. Check AWX logs for API errors
4. Re-apply survey: `./automation/apply-survey-post-method.sh`

---

**Last Updated:** October 29, 2025  
**AWX Template:** Cloudflare AWX Survey (ID: 21)  
**Total Questions:** 8
