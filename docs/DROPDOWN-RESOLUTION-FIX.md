# Dropdown Resolution Fix - Domain Variable Display

## Issue Summary

**Problem**: When selecting a domain from the AWX survey dropdown (`existing_domain`), the domain field showed empty in job output despite correct selection.

**Symptom**:
```
TASK [CLOUDFLARE AUTOMATION - DELETE_RECORD]
  "DOMAIN: ",          ← Empty!
  "RECORD: ghttt",     ← Working correctly
```

**User Selection**: 
- `existing_domain`: efustryton.co.za (from dropdown)
- `domain`: "" (empty text field)
- `existing_record`: ghttt (from dropdown)

## Root Cause

**Variable Name Collision**: The playbook was trying to both READ from and WRITE to the `domain` variable in the same resolution logic:

```yaml
# PROBLEMATIC CODE (Before Fix)
- name: Store original domain input
  set_fact:
    domain_manual_input: "{{ domain | default('') }}"

- name: Resolve domain
  set_fact:
    domain: >-
      {%- if existing_domain is defined ... -%}
        {{ existing_domain | trim }}
      {%- elif domain_manual_input ... -%}  # Reading from domain_manual_input
        {{ domain_manual_input | trim }}
      {%- endif -%}
```

**Debug Discovery**: Running with `-vvv` revealed:
```
TASK [Resolve domain name from dropdown or manual entry]
ok: [localhost] => changed=false 
  ansible_facts:
    domain: efustryton.co.za  ← Variable WAS being set correctly!
```

But the debug task immediately after showed `DOMAIN: ` (empty). This indicated the set_fact was working, but the variable wasn't being used consistently throughout the playbook.

## Solution

**Use Dedicated Resolution Variable**: Changed to use `resolved_domain` throughout the playbook, similar to how records use `resolved_record_name`:

```yaml
# FIXED CODE
- name: Resolve domain name from dropdown or manual entry
  set_fact:
    resolved_domain: >-
      {%- if existing_domain is defined and (existing_domain | trim) != '' and (existing_domain | trim) != '[MANUAL_ENTRY]' -%}
        {{ existing_domain | trim }}
      {%- elif domain is defined and (domain | trim) != '' -%}
        {{ domain | trim }}  # Reading from original domain input
      {%- else -%}
        
      {%- endif -%}
```

**Key Changes**:
1. ✅ Set `resolved_domain` instead of overwriting `domain`
2. ✅ Read directly from `domain` survey variable (no intermediate storage needed)
3. ✅ Updated all references throughout playbook to use `{{ resolved_domain }}`
4. ✅ Consistent pattern with record resolution (`resolved_record_name`)

## Testing Results

### Test 1: Dropdown Selection ✅
```bash
ansible-playbook ... \
  -e "cf_action=delete_record" \
  -e "existing_domain=efustryton.co.za" \
  -e "existing_record=ghttt" \
  --check

OUTPUT:
  DOMAIN: efustryton.co.za  ✅
  RECORD: ghttt
```

### Test 2: Manual Entry ✅
```bash
ansible-playbook ... \
  -e "cf_action=delete_record" \
  -e "existing_domain=[MANUAL_ENTRY]" \
  -e "domain=newdomain.com" \
  -e "existing_record=[NONE]" \
  -e "record_name=testrecord" \
  --check

OUTPUT:
  DOMAIN: newdomain.com  ✅
  RECORD: testrecord
```

### Test 3: Mixed Mode ✅
```bash
ansible-playbook ... \
  -e "cf_action=create_record" \
  -e "existing_domain=efustryton.co.za" \
  -e "existing_record=[NONE]" \
  -e "record_name=api" \
  --check

OUTPUT:
  DOMAIN: efustryton.co.za  ✅
  RECORD: api
```

## Code Changes

**File**: `automation/playbooks/cloudflare/unified-cloudflare-awx-playbook.yml`

**Lines Modified**: 16-27 (resolution logic), all references throughout file

**Commit**: `ac17a7d` - "fix: Use resolved_domain variable to properly display dropdown selection"

**Changed References** (26 occurrences):
- `{{ domain }}` → `{{ resolved_domain }}`
- `{{ domain | trim }}` → `{{ resolved_domain | trim }}`
- `{{ domain | default('...') }}` → `{{ resolved_domain | default('...') }}`

## Deployment

1. ✅ **Local Testing**: All scenarios verified
2. ✅ **Git Commit**: Pushed to main branch (commit `ac17a7d`)
3. ✅ **AWX Sync**: Project sync Job 994 completed successfully
4. ⏳ **AWX UI Testing**: Ready for testing in AWX web interface

## AWX Survey Configuration

**Survey Fields** (unchanged):
```json
{
  "existing_domain": {
    "type": "multiplechoice",
    "required": true,
    "default": "efustryton.co.za",
    "choices": [
      "efustryton.co.za",
      "efutechnologies.co.za",
      "[MANUAL_ENTRY]"
    ]
  },
  "domain": {
    "type": "text",
    "required": false,
    "default": ""
  },
  "existing_record": {
    "type": "multiplechoice",
    "required": false,
    "default": "[NONE]",
    "choices": ["[NONE]", "@", "applications", "ghttt", ...]
  },
  "record_name": {
    "type": "text",
    "required": false,
    "default": ""
  }
}
```

## Resolution Logic Flow

```
┌─────────────────────────────────────────────────────────────┐
│ AWX Survey Input                                            │
├─────────────────────────────────────────────────────────────┤
│ • existing_domain: "efustryton.co.za" OR "[MANUAL_ENTRY]"  │
│ • domain: "" OR "custom.com"                                │
└───────────────────────┬─────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Resolution Logic (set_fact)                                 │
├─────────────────────────────────────────────────────────────┤
│ IF existing_domain != "" AND != "[MANUAL_ENTRY]":          │
│   resolved_domain = existing_domain (dropdown value)        │
│ ELIF domain != "":                                          │
│   resolved_domain = domain (manual text entry)              │
│ ELSE:                                                       │
│   resolved_domain = "" (empty)                              │
└───────────────────────┬─────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Playbook Tasks                                              │
├─────────────────────────────────────────────────────────────┤
│ • Debug output: "DOMAIN: {{ resolved_domain }}"            │
│ • Zone lookup: url="...zones?name={{ resolved_domain }}"   │
│ • API calls: use {{ resolved_domain }} throughout          │
└─────────────────────────────────────────────────────────────┘
```

## Lessons Learned

1. **Variable Naming Consistency**: Use `resolved_*` pattern for all dropdown-to-manual resolutions
2. **Avoid Variable Overwriting**: Don't overwrite input variables; use dedicated output variables
3. **Debug with -vvv**: Verbose output revealed the variable WAS being set correctly
4. **Sed Caution**: Bulk replacements can be dangerous; manual review needed for Jinja2 logic
5. **Pattern Consistency**: Record resolution already used `resolved_record_name` correctly

## Related Documentation

- [DYNAMIC-SURVEY-DROPDOWNS.md](./DYNAMIC-SURVEY-DROPDOWNS.md) - Survey dropdown implementation
- [CLOUDFLARE-WORKFLOW-LEVELS.md](./CLOUDFLARE-WORKFLOW-LEVELS.md) - Workflow architecture
- [SURVEY-FIELDS-MAPPING.md](./SURVEY-FIELDS-MAPPING.md) - Survey field reference

## Next Steps

1. Test in AWX UI by selecting from dropdown and running a job
2. Verify auto-update script still works after create_domain/create_record actions
3. Monitor for any edge cases with empty selections
4. Consider adding validation for required fields

---

**Status**: ✅ Fixed and Deployed  
**AWX Sync**: Job 994 (Successful)  
**Git Commit**: ac17a7d  
**Date**: 2025-10-29
