# GitHub Maintenance

- `workflows/maintenance-leaf.yml` only owns the Orca and ZeroClaw release-pin
  leaves. Codex release and Improve updates land atomically in `codex-base` and
  reach this repository through the Renovate-managed root flake input.
- Maintenance leaf gates are delta-based. Existing full-head China-cache misses
  are diagnostic baseline debt and must not block unrelated leaf PRs. Do not
  change this to full-head blocking unless the user explicitly changes the
  policy.
- Changes to maintenance workflows require manual review. Do not auto-merge
  them through generated leaf maintenance.
