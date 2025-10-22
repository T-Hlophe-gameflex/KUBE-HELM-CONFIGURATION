# Cloudflare Workflows and Configuration Mapping

This document maps Cloudflare settings into three workflows used by our automation:

Workflows
- Domain workflow: per-zone settings applied when a zone is created or when enforcing zone-level policy (e.g., Argo, SSL/TLS mode, TLS versions, IPv6, HTTP/2, Always Use HTTPS).
- Global workflow: account-wide defaults that operate across zones or records (e.g., TTL defaults, proxied defaults, Argo account settings).
- Platform (record) workflow: per-record synchronization and templating used to clone records across zones (e.g., standard A/CNAME/TXT records for service discovery).

Categorization (examples)
- Argo Smart Routing: Domain workflow (must be enabled for every new domain) — configured via `domain-standardize.yml`.
- SSL/TLS Mode: Domain workflow (Full (strict) default) — configured via `domain-standardize.yml`.
- TTL, Proxied defaults for specific records: Global workflow — `global-standardize.yml` and `templates/cloudflare/global-targets.j2`.
- Standard records templates (e.g., service SRV/CNAME records): Platform workflow — `platform-sync.yml` and `templates/cloudflare/platform-targets.j2`.

Recommendations
- Ensure `automation/vars/cloudflare_standard_zone_settings.yml` is included by playbooks that run domain-standardize operations.
- Normalize record names to lowercase when comparing and when building payloads to avoid spurious changes.
- Use the `automation/tasks/cloudflare/naming-helper.yml` for survey-driven naming suggestions.
- For AWX survey dropdowns, use the `scripts/update_awx_survey_records.sh` helper to populate choices dynamically from Cloudflare (script is idempotent and does not change any Cloudflare resources).

See the repo `automation/tasks/cloudflare` for examples and templates.
