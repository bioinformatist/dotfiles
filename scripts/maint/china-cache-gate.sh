#!/usr/bin/env bash
set -euo pipefail

china_substituter="${CHINA_SUBSTITUTER:-https://mirrors.ustc.edu.cn/nix-channels/store}"
hosts=("$@")
if [[ ${#hosts[@]} -eq 0 ]]; then
  hosts=(homePC linglong)
fi

risk_markers=(
  "nvidia-x11"
  "linux-"
  "mesa-"
  "systemd-"
  "hyprland"
  "hyprlang"
  "hyprutils"
  "hyprgraphics"
  "hyprwayland-scanner"
  "hyprwire"
  "gcc-"
  "xgcc"
  "rustc-"
  "cargo-vendor"
  "chromium"
  "electron"
  "serenityos-emoji-font"
  "nanoemoji"
)

allowed_markers=(
  "hm_"
  "home-manager-path"
  "home-manager-files"
  "home-manager-generation"
  "user-environment"
  "unit-home-manager-"
  "-nix.conf.drv"
  "X-Restart-Triggers-nix-daemon"
  "unit-nix-daemon"
  "-system-units.drv"
  "-etc.drv"
  "-activate.drv"
  "nixos-system-"
)

contains_marker() {
  local text="$1"
  shift
  local marker
  for marker in "$@"; do
    if [[ "$text" == *"$marker"* ]]; then
      return 0
    fi
  done
  return 1
}

gate_host() {
  local host="$1"
  local output
  output="$(mktemp)"

  echo "Checking ${host} against ${china_substituter}"
  if ! nix build \
    --dry-run \
    -L \
    --option substituters "$china_substituter" \
    --option extra-substituters "" \
    ".#nixosConfigurations.${host}.config.system.build.toplevel" \
    >"$output" \
    2>&1; then
    echo "dry-run failed for ${host}" >&2
    cat "$output" >&2
    rm -f "$output"
    return 1
  fi

  mapfile -t derivations < <(grep -E '^[[:space:]]*/nix/store/.*\.drv$' "$output" | sed -E 's/^[[:space:]]+//')
  rm -f "$output"

  local blocked=()
  local drv
  for drv in "${derivations[@]}"; do
    if contains_marker "$drv" "${risk_markers[@]}"; then
      blocked+=("$drv")
    elif ! contains_marker "$drv" "${allowed_markers[@]}"; then
      blocked+=("$drv")
    fi
  done

  if [[ ${#blocked[@]} -gt 0 ]]; then
    echo "china-cache gate failed for ${host}; blocked local derivations:" >&2
    printf '  %s\n' "${blocked[@]:0:20}" >&2
    return 1
  fi

  echo "china-cache gate passed for ${host}"
}

failed=0
for host in "${hosts[@]}"; do
  if ! gate_host "$host"; then
    failed=1
  fi
done

exit "$failed"
