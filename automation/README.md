# Cloudflare / AWX automation

This folder holds playbooks used to manage Cloudflare DNS and to sync AWX job template surveys.

How to run (dry-run by default)

- Validate Cloudflare connectivity and preview changes (recommended):

```bash
ansible-playbook automation/playbooks/cloudflare/platform-workflow.yml \
  -e cloudflare_api_token="$CLOUDFLARE_API_TOKEN" \
  -e dry_run=true
```

- Run a playbook live (apply changes): set `dry_run=false` explicitly.

```bash
ansible-playbook automation/playbooks/cloudflare/platform-workflow.yml \
  -e cloudflare_api_token="$CLOUDFLARE_API_TOKEN" \
  -e dry_run=false
```

AWX survey sync playbook

- The AWX sync playbook queries Cloudflare for zones and updates configured AWX job template surveys with the current domain list.
- The playbook locates templates by name (not by hard-coded id), so it adapts when template IDs change.
- Example (dry-run):

```bash
ansible-playbook helm-charts/charts/awx/config/sync-cloudflare-domains.yml \
  -e cloudflare_api_token="$CLOUDFLARE_API_TOKEN" \
  -e awx_host="http://127.0.0.1:8080" \
  -e awx_username=admin \
  -e awx_password="<your-password>" \
  -e dry_run=true
```

- To apply changes, set `-e dry_run=false`.


Notes

- Mutating API calls are gated by `dry_run` and by default the playbooks set `dry_run=true`.
  Use `-e dry_run=false` to apply live changes.
- The AWX sync playbook will automatically attempt to read the AWX admin password from the
  Kubernetes secret `ansible-awx-admin-password` in namespace `awx` when `awx_password` is not provided.
- For production, remove `validate_certs: false` and configure CA trust.
