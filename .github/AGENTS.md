# GitHub Maintenance

- `workflows/maintenance-leaf.yml` only owns release-pin leaves such as Codex,
  Orca, and ZeroClaw.
- Maintenance leaf gates are delta-based. Existing full-head China-cache misses
  are diagnostic baseline debt and must not block unrelated leaf PRs. Do not
  change this to full-head blocking unless the user explicitly changes the
  policy.
- Changes to maintenance workflows require manual review. Do not auto-merge
  them through generated leaf maintenance.
