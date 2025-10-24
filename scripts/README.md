# Canonical scripts

This folder previously contained multiple legacy scripts that were duplicated under `automation/`. To reduce confusion we consolidated canonical scripts under `automation/` and moved legacy copies to `automation/archive/`. The two scripts that were replaced with stubs are:

- scripts/awx_cleanup_and_create_templates.sh -> stub that points to automation/awx-api-cloudflare-templates.sh
- scripts/update_awx_survey_records.sh -> stub that points to automation/scripts/update-awx-surveys.sh

Canonical automation scripts:

- automation/awx-api-cloudflare-templates.sh  - AWX bootstrap and job template creation/patching helper
- automation/scripts/update-awx-surveys.sh     - Populates job template surveys with Cloudflare zones and records

If you need to recover an archived copy, check automation/archive/ for previous versions.
