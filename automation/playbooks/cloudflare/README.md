
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
  # Cloudflare AWX Playbooks & Workflows

  This folder contains dynamic Ansible playbooks for AWX job templates to manage Cloudflare DNS and enforce standards across domains. All playbooks support DRY RUN, dynamic domain/record selection, and naming convention enforcement.

  ## Playbooks Overview

  ### 1. `domain-workflow.yml`
  - Purpose: Manage or replicate DNS records for a specific domain. Supports record creation, update, and cross-domain replication.
  - Features:
    - Prompts for source/target domain and record
    - DRY RUN: Shows planned changes before applying
    - Enforces naming conventions via filter plugin

  ### 2. `global-workflow.yml`
  - Purpose: Enforce global Cloudflare settings (SSL, caching, security, etc.) for a domain.
  - Features:
    - Prompts for domain (or creates new)
    - Applies global config (e.g., SSL mode)
    - DRY RUN: Shows planned global config changes

  ### 3. `platform-workflow.yml`
  - Purpose: Audit and enforce standards across all managed domains (naming, config drift, etc.).
  - Features:
    - Loops over all domains
    - Audits records for naming and config drift
    - DRY RUN: Summarizes planned platform-level actions

  ## Survey Variables (AWX)
  Configure AWX Job Template surveys to collect these variables:

  - `survey_domain`: Target domain/zone (dropdown)
  - `survey_action`: Action (`manage`, `standardize`, `sync`, `create`, `update`, `delete`) (mapped to `cf_action` at runtime)
    - NOTE: AWX surveys and survey-generator scripts now use `cf_action` as the survey variable. Wrappers map the survey value into `cf_action` and the tasks use `resolved_action` for backwards compatibility.
  - `survey_record_name`: Record name (text)
  - `survey_record_type`: Record type (A, CNAME, TXT, etc)
  - `survey_record_value`: Record content
  - `survey_record_ttl`: TTL value or `auto`
  - `survey_record_proxied`: Proxied true/false

  **Tip:** Use the provided `update-awx-surveys.sh` script to auto-populate dropdowns from Cloudflare.

  Notes on AWX types and token precedence:
  - AWX survey `multiplechoice` fields submit values as strings. For boolean-like fields (e.g. `dry_run`) use the literal strings `"true"` or `"false"` in the survey choices — the wrapper/playbook normalizes them into booleans at runtime. If your AWX job gives an error like "Value True for 'dry_run' expected to be one of ['true','false']" it means the survey provided an actual boolean instead of the expected string values.
  - Token precedence: attach a Cloudflare credential to the AWX job template (recommended). The wrapper resolves token preference as:
    1. Runner environment variable `CLOUDFLARE_API_TOKEN` (set by AWX credential injection)
    2. Survey-provided token variable (`survey_cloudflare_token`) — only use for one-offs
    3. Local environment fallback (not recommended for AWX)
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

  ## AWX Job Templates — Detailed

  Below are the common AWX job templates that consume the playbooks in this folder. The wrapper playbooks map AWX survey variables to the internal variables consumed by the task files (for example `survey_record_name` -> `record_name`).

  - Manage Record (Cloudflare)
    - Playbook: `wrapper-manage-record.yml`
    - Purpose: Create, update, or delete a single DNS record in a Cloudflare zone.
    - Key survey fields: `survey_domain`, `survey_record_name`, `survey_record_type`, `survey_record_value`, `survey_record_ttl`, `survey_record_proxied`, `survey_action`, `dry_run`
    - Behavior: resolves the zone, looks up existing record, builds a desired payload, and either shows the payload (dry-run) or performs create/update/delete operations against the Cloudflare API.

  - Manage Domain (Cloudflare)
    - Playbook: `wrapper-manage-record.yml` (domain-level mode)
    - Purpose: Run a series of record operations or standards enforcement for a full domain.
    - Key survey fields: domain-selection, standards profile, dry_run

  - Sync Platform / Platform Workflow
    - Playbook/tasks: `platform-sync.yml`, `apply-platform-sync-item.yml`
    - Purpose: Ensure that common platform records are present across zones (used for service discovery, shared services, etc.).

  ## How the wrappers and tasks work together
  - Wrapper playbooks (e.g. `wrapper-manage-record.yml`) map AWX survey variables to playbook variables and resolve the Cloudflare token precedence (runner env `CLOUDFLARE_API_TOKEN` preferred, then survey values). They then include the core task files (e.g. `manage-record.yml`).
  - Core tasks perform validation, zone discovery, existing record lookup, payload assembly, and conditional mutating API calls (guarded by `dry_run`).

  ## Why dry_run = true by default for testing

  We follow a safety-first approach. Before making any change to live DNS, always start with `dry_run=true`. Reasons:

  - Preview changes: The playbooks produce human-readable debug lines that show the exact payload that would be sent to Cloudflare (for create/update) or the exact record id/name that would be deleted.
  - Prevent accidental mutation: Many mistakes (wrong domain, wrong record name, wrong type/value) are inexpensive to catch in a dry-run but can cause outage if applied to production DNS.
  - Token safety: Dry-run allows you to test the logic without requiring an API token in the runner; the playbook skips mutating steps when `dry_run=true` and will not assert presence of `CLOUDFLARE_API_TOKEN` unless you attempt to apply.

  Suggested workflow:
  1. Set `dry_run=true` and run the AWX job with the intended survey values.
  2. Inspect the job stdout for `DRY-RUN: desired_payload=...` and `DRY-RUN: Would delete record ...` messages.
  3. When satisfied, re-run with `dry_run=false` (and ensure AWX job template has the Cloudflare credential attached) to perform the change.

  ## Common troubleshooting notes
  - If the job aborts with `CLOUDFLARE_API_TOKEN must be present in the runner environment to perform mutating operations` then attach the Cloudflare credential to the template or supply the token via the survey (prefer the credential).
  - If the Cloudflare API returns `Content for CNAME record is invalid` or similar 400 errors, validate the `survey_record_value` is a plain hostname (no protocol, no path, not an IP). The `manage-record.yml` now performs a pre-check for CNAME targets and gives a helpful error.
  - If AWX prints `An identical record already exists` when creating, check whether the desired payload matches an existing record (you may want to use `update` instead of `create`, or change content).

  ## Helpful commands for operators
  - Run a local quick-list (requires `jq`):
    ```bash
    export CLOUDFLARE_API_TOKEN=...
    ZID=$(curl -sS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=example.com&per_page=1" | jq -r '.result[0].id // empty')
    curl -sS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$ZID/dns_records?per_page=1000" | jq '.result[] | {id: .id, name: .name, type: .type, content: .content}'
    ```

  ## Contact / Ownership
  - Owners: Cloud DNS Automation Team
  - For urgent DNS changes use the AWX UI and follow the dry-run -> apply workflow.
