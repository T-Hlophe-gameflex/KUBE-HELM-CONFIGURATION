# Playbook Output Categorization Strategy

## Overview
Categorize all outputs into three levels:
- **🌐 DOMAIN LEVEL**: Zone/DNS/Rules specific to a domain
- **🌍 GLOBAL LEVEL**: Account-wide settings  
- **⚙️  PLATFORM LEVEL**: AWX/Automation platform updates

## Tasks to REMOVE (Unnecessary Debug Output)

1. ✗ `Display current DNS records for this domain` - Too verbose, adds clutter
2. ✗ `No DNS records fetched (debug fallback)` - Internal debug only
3. ✗ `Optionally show full DNS records JSON when debug_curl is true` - Only for deep debugging
4. ✗ `Debug page rules counts` - Too verbose
5. ✗ `Show AWX PATCH payload (dry-run)` - Internal debug only  
6. ✗ `Debug page rules apply results` - Covered in summary
7. ✗ `Debug numeric TTL value` - Internal validation
8. ✗ `Debug runtime cf_validate_certs value` - Internal config
9. ✗ `Show rendered record payload preview` - Too verbose
10. ✗ `Debug Cloudflare response when record result unknown or on debug` - Internal debug

## Tasks to KEEP & CATEGORIZE

### 🌐 DOMAIN LEVEL (Zone/DNS/Rules)
- ✓ Zone Created (ALREADY DONE)
- ✓ `Output zone settings result` → "🌐 DOMAIN LEVEL │ Zone Settings Applied"
- ✓ `Display page rules API warning` → "⚠️  DOMAIN LEVEL │ Page Rules Warning"
- ✓ `Critical info summary` → "📋 DOMAIN LEVEL │ Record Operation"
- ✓ `Output clone operation result` → "🌐 DOMAIN LEVEL │ Record Cloned"
- ✓ `Output record operation result` → "🌐 DOMAIN LEVEL │ Record {{ 'Created' if cf_action == 'create_record' else 'Updated' if cf_action == 'update_record' else 'Deleted' }}"
- ✓ Modern rules output (from apply_single_modern_rule.yml)

### ⚙️  PLATFORM LEVEL (AWX/Automation)
- ✓ `Warn AWX survey update failed` → "⚠️  PLATFORM LEVEL │ AWX Survey Update"

## Final Summary Task
Add at end of playbook:

```yaml
- name: "═══════════════════════════════════════════════════════════════"
  debug:
    msg: ""

- name: "📊 EXECUTION SUMMARY"
  debug:
    msg:
      - "════════════════════════════════════════════════════════════════"
      - "  ACTION COMPLETED: {{ cf_action | upper }}"
      - "  DOMAIN: {{ domain }}"
      - "════════════════════════════════════════════════════════════════"

- name: "🌐 DOMAIN LEVEL CHANGES ({{ domain_changes | length }})"
  debug:
    msg: "{{ domain_changes }}"
  when: domain_changes | length > 0

- name: "🌍 GLOBAL LEVEL CHANGES ({{ global_changes | length }})"
  debug:
    msg: "{{ global_changes }}"
  when: global_changes | length > 0

- name: "⚙️  PLATFORM LEVEL CHANGES ({{ platform_changes | length }})"
  debug:
    msg: "{{ platform_changes }}"
  when: platform_changes | length > 0

- name: "════════════════════════════════════════════════════════════════"
  debug:
    msg: "✓ Execution completed successfully"
```

## Implementation Notes
- Use icons for visual categorization
- Keep only essential information in output
- Track all changes in arrays for final summary
- Make output scannable and easy to understand
