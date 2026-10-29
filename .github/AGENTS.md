# GitHub Maintenance

- Keep `maintenance gate` as the single actual check job at `github.sha`, with
  the existing configuration evaluation and small builds. Leave them to CI.
- Preserve pull-request, merge-group, and manual triggers. See
  `docs/maintenance.md` for scope and host acceptance boundaries.
- Changes to maintenance workflows require manual review.
