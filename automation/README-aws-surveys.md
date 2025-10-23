AWX Cloudflare survey changes

This short note explains the recent AWX survey updates for Cloudflare DNS job templates and how to update AWX.

What changed
- Added a `dry_run` multiplechoice question to Cloudflare job template surveys (choices: true/false, default: false).
- Wrapper playbooks map `survey_domain` -> `domain` and the core `manage-record.yml` now prefers the AWX-injected `CLOUDFLARE_API_TOKEN` when present.
- `manage-record.yml` now reliably constructs FQDN labels when `survey_domain` is supplied.

How to apply changes in AWX
1. Push your changes to the repository (already done).
2. Trigger a project update for the Cloudflare project in AWX (project id 8):

```bash
curl -sS -X POST "http://127.0.0.1:8052/api/v2/projects/8/update/" \
  -H "Authorization: Bearer $AWX_TOKEN" \
  -H "Content-Type: application/json" -d '{}' | jq '.'
```

3. Poll the project_update until its status is `successful`:

```bash
curl -sS "http://127.0.0.1:8052/api/v2/project_updates/<update_id>/" -H "Authorization: Bearer $AWX_TOKEN" | jq '.status'
```

4. Launch the job template (e.g. Cloudflare-manage-record id 9) with `dry_run=true` and the survey variables. Example payload:

```bash
curl -sS -X POST "http://127.0.0.1:8052/api/v2/job_templates/9/launch/" \
  -H "Authorization: Bearer $AWX_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"extra_vars": {"survey_domain":"efutechnologies.co.za","survey_action":"create","survey_record_name":"www","survey_record_type":"A","survey_record_value":"1.2.3.4","dry_run":"true"}}' | jq '.'
```

Notes and troubleshooting
- If you see "Unable to discover Cloudflare zone" ensure you provided the `survey_domain` when using a single-label `survey_record_name` like `www`.
- AWX must have a valid Cloudflare token (either injected via credential into the job template or present in the runner env as `CLOUDFLARE_API_TOKEN`) to perform mutating operations (dry_run will not require it if you enabled the local dry-run auto-skip flag).

Contact
If something looks off, open an issue in the repo or ping the automation owner.
