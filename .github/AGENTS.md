# GitHub Maintenance

- Maintenance Gate checks the full candidate at `github.sha`. Existing and new
  unapproved local builds both block; there is no base-revision exemption or
  requirement that every path be available from USTC.
- Preserve the `maintenance gate` required check, all three targets, and raw
  diagnostics. Leave its configuration and default cache tests to CI.
- Changes to maintenance workflows require manual review. Do not auto-merge
  them through generated leaf maintenance.
