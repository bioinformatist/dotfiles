#!/usr/bin/env bash
set -euo pipefail

china_substituter="${CHINA_SUBSTITUTER:-https://mirrors.ustc.edu.cn/nix-channels/store}"
report_only=false
blocked_output=""
hosts=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-only)
      report_only=true
      shift
      ;;
    --output|--blocked-output)
      blocked_output="$2"
      shift 2
      ;;
    --output=*|--blocked-output=*)
      blocked_output="${1#*=}"
      shift
      ;;
    --)
      shift
      hosts+=("$@")
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      hosts+=("$1")
      shift
      ;;
  esac
done

if [[ ${#hosts[@]} -eq 0 ]]; then
  hosts=(homePC linglong)
fi

if [[ -n "$blocked_output" ]]; then
  : > "$blocked_output"
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
  "user-units"
  "X-Restart-Triggers-"
  "unit-"
  "unit-home-manager-"
  "-nix.conf.drv"
  "X-Restart-Triggers-nix-daemon"
  "unit-nix-daemon"
  "-activation-script.drv"
  "-dbus-1.drv"
  "-dry-activate.drv"
  "-hwdb.bin.drv"
  "-manifest-for-users.json.drv"
  "-manifest.json.drv"
  "-system-generators.drv"
  "-system-path.drv"
  "-system-shutdown.drv"
  "-system-units.drv"
  "-tmpfiles.d.drv"
  "-udev-rules.drv"
  "-user-generators.drv"
  "-users-groups.json.drv"
  "-etc.drv"
  "-activate.drv"
  "nixos-system-"
  "-openai.yaml.drv"
  "-SKILL-header.md.drv"
  "-SKILL.md.drv"
  "-skill.drv"
  "-source.drv"
  "-codex-config.toml.drv"
  "-context7-auth-mcp-server.drv"
  "-github-mcp-server.drv"
  "-playwright-cli.drv"
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

record_blocked() {
  local host="$1"
  local drv="$2"

  if [[ -n "$blocked_output" ]]; then
    printf '%s\t%s\n' "$host" "$drv" >> "$blocked_output"
  else
    printf '  %s\t%s\n' "$host" "$drv" >&2
  fi
}

gate_host() {
  local host="$1"
  local output
  local blocked_count=0
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
    return 2
  fi

  mapfile -t derivations < <(
    awk '/^[[:space:]]*\/nix\/store\/.*\.drv$/ { sub(/^[[:space:]]+/, ""); print }' "$output" | sort -u
  )
  rm -f "$output"

  local drv
  for drv in "${derivations[@]}"; do
    if contains_marker "$drv" "${allowed_markers[@]}"; then
      continue
    elif contains_marker "$drv" "${risk_markers[@]}"; then
      record_blocked "$host" "$drv"
      blocked_count=$((blocked_count + 1))
    else
      record_blocked "$host" "$drv"
      blocked_count=$((blocked_count + 1))
    fi
  done

  if [[ "$blocked_count" -gt 0 ]]; then
    echo "china gate found ${blocked_count} blocked local derivations for ${host}"
    return 1
  fi

  echo "china gate passed for ${host}"
}

failed=0
blocked=0
for host in "${hosts[@]}"; do
  if gate_host "$host"; then
    continue
  else
    code=$?
    if [[ "$code" -eq 2 ]]; then
      failed=1
    else
      blocked=1
    fi
  fi
done

if [[ -n "$blocked_output" ]]; then
  sort -u "$blocked_output" -o "$blocked_output"
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

if [[ "$blocked" -ne 0 && "$report_only" != "true" ]]; then
  if [[ -n "$blocked_output" ]]; then
    echo "china gate failed; blocked local derivations:" >&2
    sed -n '1,20p' "$blocked_output" >&2
  fi
  exit 1
fi
