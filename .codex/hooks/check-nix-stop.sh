#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"

# Avoid looping forever if Codex already continued once because of this hook.
if [[ "$stop_hook_active" == "true" ]]; then
  printf '%s\n' '{"continue":true}'
  exit 0
fi

if [[ -z "$cwd" ]]; then
  printf '%s\n' '{"continue":true}'
  exit 0
fi

if ! repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; then
  printf '%s\n' '{"continue":true}'
  exit 0
fi

# Keep this hook cheap and predictable: it only syntax-checks Nix files that
# are currently changed in the repository worktree.
mapfile -t changed_nix_files < <(
  {
    git -C "$repo_root" diff --name-only -- "*.nix"
    git -C "$repo_root" diff --cached --name-only -- "*.nix"
    git -C "$repo_root" ls-files --others --exclude-standard -- "*.nix"
  } | awk 'NF && !seen[$0]++'
)

if [[ "${#changed_nix_files[@]}" -eq 0 ]]; then
  printf '%s\n' '{"continue":true}'
  exit 0
fi

failed=()
for rel_path in "${changed_nix_files[@]}"; do
  abs_path="$repo_root/$rel_path"
  if [[ ! -f "$abs_path" ]]; then
    continue
  fi

  if ! nix-instantiate --parse "$abs_path" >/dev/null 2>&1; then
    failed+=("$rel_path")
  fi
done

if [[ "${#failed[@]}" -eq 0 ]]; then
  printf '%s\n' '{"continue":true}'
  exit 0
fi

reason="nix-instantiate --parse failed for: $(IFS=', '; printf '%s' "${failed[*]}"). Fix the Nix syntax before stopping."

jq -nc --arg reason "$reason" '{
  decision: "block",
  reason: $reason
}'
