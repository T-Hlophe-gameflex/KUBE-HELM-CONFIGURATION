Cloudflare AWX playbooks
========================

Overview
--------
This folder contains wrapper playbooks that AWX job templates use to invoke Cloudflare DNS management tasks located under `automation/tasks/cloudflare/`.

Survey variables
----------------
When you configure an AWX Job Template, add a Survey to collect runtime variables. The playbooks expect the following survey variable names (they map into playbook variables):

- `survey_domain` — the target domain/zone (string; set as multiplechoice for dropdown)
- `survey_action` — action like `manage`, `standardize`, `sync`, `create`, `update`, `delete` (use multiplechoice)
- `survey_record_name` — record name (text)
- `survey_record_type` — record type (A, CNAME, TXT, etc)
- `survey_record_value` — record content
- `survey_record_ttl` — TTL value or `auto`
- `survey_record_proxied` — proxied true/false

How to add domains to the dropdown
----------------------------------
AWX Surveys accept the choices field as a pipe-separated list. Example choices string:

"example.com|example.org|sub.example.com"

Use the AWX web UI or the API endpoint `/api/v2/job_templates/<id>/survey_spec/` to set the survey spec for each template.

Automating surveys via AWX API
------------------------------
You can POST a JSON survey spec to `/api/v2/job_templates/<id>/survey_spec/` to create/update the survey. See the repository root README for an example.

Notes
-----
- Ensure the AWX Job Template has the Cloudflare credential attached (this repo previously created one named "Cloudflare API Credentials").
- The playbooks will read survey variables and fall back to defaults defined in the task files if not provided.
