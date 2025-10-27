# Unified AWX Cloudflare Template: Usage & Migration Guide

## Overview
This unified AWX template/playbook replaces all previous Cloudflare DNS/domain management templates. It allows you to:
- Create new domains (zones)
- Standardize global and domain settings automatically
- Create, update, or delete DNS records (with standardized settings)
- Sync platform-wide standard records to all domains
- See a clear summary of all actions and settings in the job output

## How to Use in AWX
1. **Import the Playbook**
   - Upload `automation/unified-cloudflare-awx-playbook.yml` to your AWX project.
2. **Create a New Job Template**
   - Point it to the unified playbook.
   - Import the survey from `automation/unified-cloudflare-awx-survey.json` (AWX UI: Survey → Import).
3. **Set Cloudflare API Token**
   - Ensure the `CLOUDFLARE_API_TOKEN` environment variable is set in your AWX credential or job template.
4. **Run the Job**
   - Use the survey to select the action (create domain, create/update/delete record, sync, standardize).
   - Enter the required domain/record details as prompted.
   - Review the job output for a summary of all changes and settings.

## Migration from Old Templates
- **Remove**: All previous Cloudflare DNS/domain/standardization templates from AWX.
- **Replace**: Use only the new unified template for all actions.
- **No manual settings**: All global/domain/platform settings are now standardized automatically.

## Example Survey Actions
- **Create a new domain**: Select `create_domain`, enter the domain name.
- **Create a record**: Select `create_record`, enter domain, record name/type/value.
- **Update/delete a record**: Select `update_record` or `delete_record`, enter details.
- **Sync all domains**: Select `sync` to apply standard records everywhere.
- **Standardize settings**: Select `standardize` to re-apply all global/domain settings.

## Output
- The job output will show:
  - What action was performed
  - The settings applied at global, domain, and platform levels
  - API responses for all changes

---

For advanced customization, edit the `standard_zone_settings` and `standard_records` variables in the playbook.
