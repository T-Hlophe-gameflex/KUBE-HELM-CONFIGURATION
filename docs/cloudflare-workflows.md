# Cloudflare Workflows — Design & Implementation Plan

This document defines the design, contracts, API mappings, naming conventions and phased plan to implement the Domain / Global / Platform workflows for Cloudflare DNS management via AWX job templates.

Goals
- Provide 3–4 consolidated AWX templates that let operators:
  - Manage domain-level records (create/update/replicate/delete)
  - Ensure global account/zone settings are enforced when adding domains/records
  - Apply platform-wide naming conventions and replicate records across domains
- Keep dry-run safety guard so changes are reviewed before live API calls
- Populate AWX surveys dynamically from the Cloudflare account (zones, records)

Top-level phases (summary)
- Phase 1 — Design & discovery (this doc)
- Phase 2 — Domain-level workflow implementation
- Phase 3 — Global-level workflow implementation
- Phase 4 — Platform-level workflow (naming rules, bulk apply)
- Phase 5 — Consolidate AWX templates & surveys
- Phase 6 — Automation & CI/tests
- Phase 7 — Docs & runbook
- Phase 8 — Rollout & validation

Contracts (tiny "API" for playbooks)
- Domain workflow playbook (inputs/outputs):
  - Inputs (survey vars):
    - survey_domain (string) — selected zone (e.g. efustryton.co.za)
    - survey_action (string) — one of: list_records, create, update, replicate, delete
    - survey_source_zone (string, optional) — when replicating from another domain
    - survey_record_choice (string, optional) — when choosing an existing record to replicate (format: id|name|type)
    - survey_record_name (string)
    - survey_record_type (string) — A, AAAA, CNAME, TXT, MX, SRV, etc.
    - survey_record_content (string)
    - survey_record_ttl (string)
    - survey_record_proxied (string) — 'true' or 'false'
    - dry_run (string) — 'true' or 'false'
  - Outputs:
    - On dry_run: Ansible debug message with 'DRY RUN: would call <METHOD> <URL>' and JSON payload
    - On apply: Cloudflare API response dict, and task result (changed/failed)
  - Error modes: invalid types, missing required fields, Cloudflare API errors (reported back to AWX stdout)

- Global workflow playbook (inputs/outputs):
  - Inputs: survey_global_action (e.g., check, enforce), selected settings to align, dry_run
  - Outputs: list of zones non-compliant, planned patches, applied patches

- Platform workflow playbook (inputs/outputs):
  - Inputs: domain list (or select all), naming pattern, dry_run, optional rollback tag
  - Outputs: mapping of old->new names, list of created/updated records, rollback plan

Cloudflare API mappings (quick reference)
- Zones:
  - List: GET /zones
  - Zone details: GET /zones/:zone_identifier
- DNS Records:
  - List records: GET /zones/:zone_identifier/dns_records
  - Create record: POST /zones/:zone_identifier/dns_records
  - Update record: PUT /zones/:zone_identifier/dns_records/:identifier
  - Delete record: DELETE /zones/:zone_identifier/dns_records/:identifier
- Zone settings (examples):
  - GET/PUT /zones/:zone_identifier/settings/:setting_name
- Authentication: Bearer token via header `Authorization: Bearer <token>` (stored in AWX credential as type 'net' — secret in password)

Data shapes
- Zone list item (what the UI/survey shows)
  - choice string for survey: "<zone_name>\n<zone_id_escaped>" — but AWX surveys expect newline-separated choices encoded as \n in JSON; use the update script to escape newlines.
- DNS record list item for replicate dropdown: a single-line JSON-ish label that AWX can display, with the record id encoded for the API call. Example choice label format:
  - "<name> | <type> | <content> | <id>" (store id as last pipe-part)

Survey UX & format notes
- AWX survey choices must be a newline-separated string when set via API; encode newlines as `\\n` inside the JSON body for AWX API. The `automation/scripts/update-awx-surveys.sh` script will:
  - Query Cloudflare zones
  - Build zone choices joined with the actual newline char
  - Escape newlines to `\\n` before embedding in AWX project PATCH payload
- For replicate flows the script should also build a per-zone records cache and use it when a source zone is selected; AWX surveys do not support dependent dropdowns out of the box — we will:
  - Populate a single record choices field with *all* known records across zones (optionally prefixed with zone) OR
  - Create the UI experience where the survey asks for source_zone first, then a runner callback (AWX lacks dynamic refresh) — so the practical approach is to provide either:
    - A choice with format `zone|record_id|record_name|type` where the user chooses the exact record to replicate
    - OR separate templates: 'replicate-record' job where the survey explicitly takes `source_zone` and `record_id` as text inputs

Naming conventions & transformation contract
- Input patterns we support:
  - Legacy: $domain-{env}{num}
  - New: {env}{num}-{service}
  - Mixed: {service}-{env}{num}
  - Special: {name}-{service}
  - Direct: {function_name}
- Transform functions:
  - normalize_name(original_name, domain, env, service, pattern) -> new_name
  - sanitize_label(s) -> convert invalid chars, enforce lowercase, max length
- Tests for transforms include round-trip, edge-case long names, numeric suffix handling

Edge cases / validation
- TTL: Cloudflare expects a string in the survey but numeric in API; canonicalize to int before API call and use string in survey
- Proxied: AWX survey send 'true'/'false' strings; convert to boolean in playbook
- Record types with special fields (e.g., MX has priority; SRV has service/priority/weight/port): ensure extra fields included when needed
- Rate limits & throttling: implement retry/backoff for 429 responses
- Idempotency: when creating a record, check for an existing record with same name/type/content and either update or report 'already exists'

Domain-level workflow — implementation plan (Phase 2 start)
1) Playbooks and Tasks
  - `automation/playbooks/cloudflare/domain-workflow.yml` (wrapper; maps survey vars -> task variables)
  - `automation/tasks/cloudflare/domain/list-zones.yml` (list zones -> set_fact)
  - `automation/tasks/cloudflare/domain/list-records.yml` (GET records for a zone and return choices)
  - `automation/tasks/cloudflare/domain/manage-record.yml` (create/update/delete/replicate record; supports dry_run flag and idempotency checks)
2) AWX surveys & variable names
  - Survey variables: `survey_domain`, `survey_action`, `survey_record_choice`, `survey_record_name`, `survey_record_type`, `survey_record_value`, `survey_record_ttl`, `survey_record_proxied`, `dry_run`
  - `update-awx-surveys.sh` will populate zone choices and a global record choice list for replication.
3) Example manage-record flow (replicate):
  - User selects `replicate` action, chooses `source_choice` (encoded with zone+id), chooses `target_zone` (second dropdown), optionally edits `record_name`, `ttl`, `proxied`
  - Playbook fetches source record via GET /zones/:source_zone/dns_records/:id, normalizes fields, applies naming transform for target domain, then issues POST to create record in target zone (unless `dry_run` true: then debug print)
4) Dry-run pattern
  - All write tasks wrap HTTP calls in a condition: when dry_run == 'true' then `debug` with DRY RUN header and JSON payload. Live calls use `uri` module with Content-Type: application/json and AWX credential token injected.

Small code contract for manage-record (pseudo)
- Inputs: domain, action, record_id?, record_name, record_type, record_value, record_ttl, record_proxied, dry_run
- Steps:
  1. If action in [list_records]: call GET /zones/:domain/dns_records and return choices
  2. If action == replicate: GET source record, transform name, set payload, if dry_run debug else POST
  3. If action == create: build payload from fields, if dry_run debug else POST
  4. If action == update: call PUT with payload
  5. If action == delete: call DELETE

Testing approach
- Unit tests for naming transforms (pure python / ansible filter plugin)
- Ansible role/task tests: run wrapper playbook locally with `dry_run=true` and assert the debug message contains expected method/URL/payload
- Integration tests: mock Cloudflare API via tiny http server or use a test CF account with restricted permissions

Backlog & improvements
- Add an Ansible filter plugin `cloudflare_name_transform` in `automation/filter_plugins/` to centralize naming rules and unit-test it.
- Add role `cloudflare` with `defaults/main.yml` describing canonical TTL, proxied default, record type meta
- Update `automation/scripts/update-awx-surveys.sh` to cache record lists per zone and to allow selective refresh
- Add a small Python helper `automation/tools/cf_helpers.py` to wrap Cloudflare API pagination and normalize results (used by survey updater and by ad-hoc tasks)

Next immediate tasks (what I'll implement after you confirm)
1. Finish Phase 1: add this file (done). Mark Phase 2 in-progress and implement Domain-level wrapper and manage-record tasks (dry_run first).
2. Implement a naming transform (Ansible filter plugin) and unit tests.
3. Implement and test `update-awx-surveys.sh` to include both zones and per-zone record choices (escaped newlines) and run it to populate AWX surveys.

If you want to proceed now I will:
- Start Phase 2 (set todo id 2 in-progress) and implement `automation/playbooks/cloudflare/domain-workflow.yml` plus `automation/tasks/cloudflare/domain/manage-record.yml` (dry_run behavior), commit, push and trigger AWX project update. I will then run a dry-run job via AWX API or locally and return the DRY RUN payload.


