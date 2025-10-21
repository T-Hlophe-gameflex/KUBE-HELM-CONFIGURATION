
# Cloudflare AWX Playbooks & Workflows

This folder contains dynamic Ansible playbooks for AWX job templates to manage Cloudflare DNS and enforce standards across domains. All playbooks support DRY RUN, dynamic domain/record selection, and naming convention enforcement.

## Playbooks Overview

### 1. `domain-workflow.yml`
- **Purpose:** Manage or replicate DNS records for a specific domain. Supports record creation, update, and cross-domain replication.
- **Features:**
  - Prompts for source/target domain and record
  - DRY RUN: Shows planned changes before applying
  - Enforces naming conventions via filter plugin

### 2. `global-workflow.yml`
- **Purpose:** Enforce global Cloudflare settings (SSL, caching, security, etc.) for a domain.
- **Features:**
  - Prompts for domain (or creates new)
  - Applies global config (e.g., SSL mode)
  - DRY RUN: Shows planned global config changes

### 3. `platform-workflow.yml`
- **Purpose:** Audit and enforce standards across all managed domains (naming, config drift, etc.).
- **Features:**
  - Loops over all domains
  - Audits records for naming and config drift
  - DRY RUN: Summarizes planned platform-level actions

## Survey Variables (AWX)
Configure AWX Job Template surveys to collect these variables:

- `survey_domain`: Target domain/zone (dropdown)
- `survey_action`: Action (`manage`, `standardize`, `sync`, `create`, `update`, `delete`)
- `survey_record_name`: Record name (text)
- `survey_record_type`: Record type (A, CNAME, TXT, etc)
- `survey_record_value`: Record content
- `survey_record_ttl`: TTL value or `auto`
- `survey_record_proxied`: Proxied true/false

**Tip:** Use the provided `update-awx-surveys.sh` script to auto-populate dropdowns from Cloudflare.

## Usage Examples

### Launching a Playbook (AWX API)
```json
{
  "extra_vars": {
    "dry_run": true,
    "survey_domain": "example.com",
    "survey_action": "create",
    "survey_record_name": "www",
    "survey_record_type": "A",
    "survey_record_value": "1.2.3.4",
    "survey_record_ttl": "3600",
    "survey_record_proxied": false
  }
}
```

### Local Testing (DRY RUN)
```sh
ansible-playbook domain-workflow.yml --check --extra-vars 'cloudflare_api_token=... dry_run=true survey_domain=example.com ...'
```

## Naming Conventions & Standards
- Naming logic is enforced via the `cloudflare_naming` filter plugin (see `../filter_plugins/cloudflare_name.py`).
- All records and domains are validated/migrated to match new standards.
- Global and platform workflows enforce config (SSL, TTL, proxy, etc.) per standards.

## Automating AWX Surveys
- Use `automation/scripts/update-awx-surveys.sh` to update all AWX job template surveys with live Cloudflare domains and config options.
- Script requirements: `jq`, `curl`, AWX and Cloudflare API tokens.
- See root `README.md` for more details.

## Migration Patterns
- Use platform workflow to audit all domains and migrate records to new naming/config standards.
- Use domain workflow to replicate or update records as needed.
- Use global workflow to enforce org-wide Cloudflare settings.

## Notes
- Ensure AWX Job Templates have the Cloudflare credential attached.
- Playbooks fall back to defaults if survey variables are not provided.
- All workflows support DRY RUN for safe testing.

---
For more details, see the root `README.md` and comments in each playbook.
