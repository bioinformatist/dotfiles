# Maintenance Gate

- `policy.json` is the reusable policy base. `policy-workstation.json` contains
  workstation-only additions. Desktop CI and local `maint-switch` consume
  `lib.maintenancePolicy`; synthetic headless CI uses `lib.maintenancePolicyBase`.
- CI and Nu share `nix-plan.jq` and `classify-plan.jq`. Keep native dependency
  planning and cache priority; the gate checks the full candidate and blocks
  incomplete plans. A valid empty plan is allowed only for the local daemon.
- Review exact binary wrappers before allowing them; package names and fixed
  outputs alone do not establish that a derivation avoids compilation. Pin an
  older cached version during an input update, never dynamically in the gate.
- If a gate blocks a clearly generated NixOS or Home Manager glue derivation,
  update the shared base or the owning overlay narrowly. Downstreams must extend
  the locked base instead of forwarding a full copy. Do not bypass the gate or
  allowlist heavy components.
- Changes to the policy or gate scripts require manual review. Do not
  auto-merge them through generated leaf maintenance.
