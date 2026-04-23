This repository uses a repo-local Codex `Stop` hook.

Files:
- `hooks.json`: wires Codex to the hook command.
- `hooks/check-nix-stop.sh`: runs `nix-instantiate --parse` on changed `*.nix` files before a turn ends.

Intent:
- Keep the check cheap enough to run every turn.
- Catch obvious Nix syntax errors before Codex stops.
- Avoid replacing heavier manual verification after rebuild.
