---
name: workstation-web-ui
description: Develop, preview, debug, or verify the web/workstation Leptos/Trunk product UI in this repo, especially from a headless server where user preview must bind to the LAN and browser checks use headless Chromium/CDP.
---

# Workstation Web UI

Use this skill for `web/workstation` UI work: Leptos, Trunk, Rust/WASM,
`leptos_i18n`, Thaw usage, local preview, headless browser checks, and release
build verification.

This skill does not replace `$product-form-ux`. Use `$product-form-ux` for
form flow, inline feedback, and output-panel judgment. For Lighthouse, Core Web
Vitals, broad accessibility audits, or SEO, prefer mature web-quality skills
such as `addyosmani/web-quality-skills` when available instead of duplicating
those rules here.

## Hard Rules

- Assume development and browser testing may happen on a headless server over
  SSH.
- For user preview from a graphical PC on the LAN, bind the server to
  `0.0.0.0` and report a LAN URL. Do not give only `127.0.0.1`.
- Use `127.0.0.1` only for same-host Playwright/CDP checks.
- Do not add backend services, online builders, product CLI entrypoints, secret
  upload, private-key handling, token handling, or persisted plaintext
  passwords unless explicitly requested.

## Preview

Start a LAN-reachable preview from the repo root:

```bash
nix develop .#workstation-web --command env ADDRESS=0.0.0.0 PORT=8088 workstation-web-serve
```

Find the LAN address:

```bash
hostname -I
```

Report the URL as:

```text
http://<lan-ip>:8088/
```

The repo wrapper defaults to `127.0.0.1`; set `ADDRESS=0.0.0.0` whenever the
user needs to open the page from another machine. The wrapper serves the
custom-domain root path by default; set `PUBLIC_URL=/dotfiles/` only when
explicitly checking the legacy GitHub project-page path.

## Headless Browser Check

Use the browser shell:

```bash
nix develop .#workstation-web-browser --command workstation-web-chrome http://127.0.0.1:8088/
```

Attach Playwright to CDP:

```bash
playwright-cli attach --cdp=http://127.0.0.1:9222
```

Capture at least desktop and mobile viewports when reviewing UI changes:

```bash
playwright-cli --s=default resize 1440 1000
playwright-cli --s=default snapshot
playwright-cli --s=default resize 390 900
playwright-cli --s=default snapshot
playwright-cli --s=default console
```

For final actions, verify the side effect, not just the button state or flash
message. For copy buttons, read or paste the clipboard value; for downloads,
confirm the generated file exists or the browser download event fired.

If Chinese text renders as tofu in headless screenshots, check the
`workstation-web-browser` font configuration before judging the UI.

## Verification

Run from the repo root unless noted:

```bash
nix develop .#default --command cargo fmt --manifest-path web/workstation/Cargo.toml --check
nix develop .#default --command cargo test --manifest-path web/workstation/Cargo.toml
nix develop .#default --command cargo clippy --manifest-path web/workstation/Cargo.toml -- -D warnings
```

Run Trunk from `web/workstation` so it finds `Trunk.toml`:

```bash
env NO_COLOR=true nix develop ../..#default --command trunk build --release --public-url /
```

`trunk` 0.21 rejects the common `NO_COLOR=1` convention; set
`NO_COLOR=true` or use the repo wrapper.
