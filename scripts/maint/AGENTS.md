# Shared Maintenance Policy

- `policy.json` backs the public `lib.maintenancePolicyBase` and
  `lib.extendMaintenancePolicy` interfaces used by downstream repositories.
  Preserve their extension semantics when changing this data.
- Upstream CI and `maint-switch` do not consume this policy. For the current
  on-demand maintenance workflow, read `docs/maintenance.md`.
- Policy changes require manual review against actual downstream consumers.
