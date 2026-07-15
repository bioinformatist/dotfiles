# Maintenance Gate

- `policy.json` is the reusable policy base. `policy-workstation.json` contains
  workstation-only additions, and `lib.maintenancePolicy` is the effective
  policy consumed by `maint-switch` and the China gate.
- If a gate blocks a clearly generated NixOS or Home Manager glue derivation,
  update the shared base or the owning overlay narrowly. Downstreams must extend
  the locked base instead of forwarding a full copy. Do not bypass the gate or
  allowlist heavy components.
- Changes to the policy or gate scripts require manual review. Do not
  auto-merge them through generated leaf maintenance.
