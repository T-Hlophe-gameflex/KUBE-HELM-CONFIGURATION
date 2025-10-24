<!--
This pull request template is a draft created by automation to speed up review for the
`cleanup/consolidate-scripts` branch. It contains a ready-to-send PR body describing the
purpose, changes, validation, and notes for reviewers. Edit as needed before creating the PR.
-->

# chore(scripts): consolidate duplicate scripts, add README, and apply shellcheck fixes

## Summary

This branch consolidates duplicated operational scripts and improves script robustness:

- Consolidate canonical scripts under `automation/` and replace legacy duplicates in `scripts/` with
  small stubs that point to the canonical implementations.
- Archive legacy copies under `automation/archive/` rather than keeping duplicate editable copies.
- Apply safe, non-behavioral ShellCheck fixes across scripts (quoting, `read -r`, safer jq payload building,
  small refactors) to improve portability and reduce risk of word-splitting bugs.

This PR is intentionally conservative — no destructive deletions were performed. Legacy files were moved
to `automation/archive/` and `scripts/` contains stubs to guide maintainers to the canonical helpers.

## Why

- Reduce maintenance overhead by having a single source-of-truth for AWX/Cloudflare helper scripts.
- Make scripts safer to run in CI and interactive environments by fixing common shell pitfalls.

## Changes (high level)

- `scripts/awx_cleanup_and_create_templates.sh` — replaced with a stub pointing to `automation/awx-api-cloudflare-templates.sh`
- `scripts/update_awx_survey_records.sh` — replaced with a stub pointing to `automation/scripts/update-awx-surveys.sh`
- `scripts/README.md` — new: documents canonical scripts and archive location
- `scripts/awx_readiness_check.sh` — quoting and safe curl auth
- `scripts/cf_inspect_and_test.sh` — `read -r`, safer `jq` usage and safe payload fallback
- `automation/archive/*` — archived legacy scripts (cleaned formatting)
- `automation/scripts/update-awx-surveys.sh` — `read -r` and sanitization for CF token
- `scripts/setup-kind.sh` — quoted subnet handling
- `scripts/cleanup.sh` — split local assignment, quoted kubectl deletes, consolidated README writes, and shellcheck comment for intentional unused var

Full diff is available in the branch: `cleanup/consolidate-scripts`.

## How I validated

- Ran `shellcheck` across `scripts/` and `automation/` and fixed all flagged issues. Final run produced no warnings.
- Performed syntax checks (`bash -n`) on updated scripts to ensure no parse errors.
- Did not run destructive cleanup commands. Interactive helpers were dry-run validated where possible.

## Manual testing suggestions (reviewers)

1. Inspect the stubbed `scripts/*` files to confirm they correctly point to canonical implementations.
2. Run `bash -n scripts/*.sh automation/**/*.sh` locally to check syntax.
3. Run `shellcheck -x scripts/*.sh automation/**/*.sh` (recommended) to confirm no warnings on your machine.
4. For interactive scripts, test in a safe environment (use test Cloudflare token with limited scopes, and `--yes`/dry-run flags):

   - `CLOUDFLARE_API_TOKEN=... ./scripts/cf_inspect_and_test.sh --zone example.com --create-test --yes`
   - `./scripts/awx_readiness_check.sh` (requires kubectl access and AWX port-forwarding privileges)

## Notes & follow-ups

- No files were permanently deleted. Legacy copies are in `automation/archive/` and can be restored from git history if needed.
- `AUTOMATION_DIR` is intentionally retained in `scripts/cleanup.sh` (commented) to preserve compatibility with external callers; remove it in a follow-up if truly unused.

## PR checklist

- [ ] Changes are small, focused and individually reviewable
- [ ] ShellCheck and syntax checks pass locally
- [ ] No secrets or tokens were committed
- [ ] Legacy files moved to `automation/archive/` and not deleted

---

Branch compare URL (open to create PR):

https://github.com/T-Hlophe-gameflex/KUBE-HELM-CONFIGURATION/compare/main...cleanup/consolidate-scripts
