# Maintenance Gate

- `policy.json` is the source of truth for `maint-switch` and China gate
  markers.
- If a gate blocks a clearly generated NixOS or Home Manager glue derivation,
  update the policy narrowly and let downstreams inherit or forward it. Do not
  bypass the gate or allowlist heavy components.
- Changes to the policy or gate scripts require manual review. Do not
  auto-merge them through generated leaf maintenance.
