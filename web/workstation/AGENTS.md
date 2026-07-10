# Workstation Web

- Use the repo-local `$workstation-web-ui` skill for development, preview,
  debugging, builds, and browser verification in this subtree.
- Prefer Rust/WASM for UI state, validation, rendering, file generation,
  archives, downloads, clipboard access, and browser storage when mature Rust
  crates or `web-sys` bindings are sufficient. Keep JavaScript glue limited to
  browser API gaps.
- Do not add a product CLI entrypoint, backend service, online Nix/ISO builder,
  remote installer, secret upload, private-key handling, token handling, or
  persisted password handling unless explicitly requested.
- Initial passwords may only be processed in the browser long enough to
  generate `initialHashedPassword`. Never write plaintext passwords to
  generated files, URLs, logs, or browser storage.
- User preview servers must bind to `0.0.0.0` and report a LAN URL. Use
  `127.0.0.1` only for same-host Playwright or CDP checks.
