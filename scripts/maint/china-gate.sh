#!/usr/bin/env bash
set -euo pipefail

default_china_substituters="https://mirrors.ustc.edu.cn/nix-channels/store https://anyrun.cachix.org https://hyprland.cachix.org"
default_china_extra_trusted_public_keys="anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
china_substituters="${CHINA_SUBSTITUTERS:-${CHINA_SUBSTITUTER:-$default_china_substituters}}"
china_extra_trusted_public_keys="${CHINA_EXTRA_TRUSTED_PUBLIC_KEYS:-$default_china_extra_trusted_public_keys}"
report_only=false
blocked_output=""
direct_output=""
hosts=()
homes=()
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
flake_root="$repo_root"
policy_file=""

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
    --direct-output)
      direct_output="$2"
      shift 2
      ;;
    --direct-output=*)
      direct_output="${1#*=}"
      shift
      ;;
    --flake-root)
      flake_root="$2"
      shift 2
      ;;
    --flake-root=*)
      flake_root="${1#*=}"
      shift
      ;;
    --policy-file)
      policy_file="$2"
      shift 2
      ;;
    --policy-file=*)
      policy_file="${1#*=}"
      shift
      ;;
    --home)
      homes+=("$2")
      shift 2
      ;;
    --home=*)
      homes+=("${1#*=}")
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

flake_root="$(cd -- "$flake_root" && pwd)"
if [[ -z "$policy_file" ]]; then
  policy_file="${flake_root}/scripts/maint/policy.json"
fi

if [[ ${#hosts[@]} -eq 0 && ${#homes[@]} -eq 0 ]]; then
  hosts=(homePC linglong)
fi

if [[ -n "$blocked_output" ]]; then
  : > "$blocked_output"
fi

if [[ -n "$direct_output" ]]; then
  : > "$direct_output"
fi

read_policy_list() {
  local attr="$1"
  local -n target="$2"

  mapfile -t target < <(
    nix eval --raw --impure --expr \
      "builtins.concatStringsSep \"\\n\" (builtins.fromJSON (builtins.readFile ${policy_file})).${attr}"
  )
}

read_policy_list riskMarkers risk_markers
read_policy_list allowedLocalBuildMarkers allowed_markers
read_policy_list allowedDirectFetchMarkers allowed_direct_markers

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

record_direct() {
  local host="$1"
  local drv="$2"

  if [[ -n "$direct_output" ]]; then
    printf '%s\t%s\n' "$host" "$drv" >> "$direct_output"
  else
    printf '  %s\t%s\n' "$host" "$drv" >&2
  fi
}

gate_attr() {
  local label="$1"
  local attr="$2"
  local output
  local blocked_count=0
  output="$(mktemp)"

  echo "Checking ${label} against ${china_substituters}"
  if ! nix build \
    --dry-run \
    -L \
    --option substituters "$china_substituters" \
    --option extra-substituters "" \
    --option extra-trusted-public-keys "$china_extra_trusted_public_keys" \
    "$attr" \
    >"$output" \
    2>&1; then
    echo "dry-run failed for ${label}" >&2
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
    elif contains_marker "$drv" "${allowed_direct_markers[@]}"; then
      record_direct "$label" "$drv"
    elif contains_marker "$drv" "${risk_markers[@]}"; then
      record_blocked "$label" "$drv"
      blocked_count=$((blocked_count + 1))
    else
      record_blocked "$label" "$drv"
      blocked_count=$((blocked_count + 1))
    fi
  done

  if [[ "$blocked_count" -gt 0 ]]; then
    echo "china gate found ${blocked_count} blocked local derivations for ${label}"
    return 1
  fi

  echo "china gate passed for ${label}"
}

failed=0
blocked=0
for host in "${hosts[@]}"; do
  if gate_attr "$host" "${flake_root}#nixosConfigurations.${host}.config.system.build.toplevel"; then
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

for home in "${homes[@]}"; do
  if gate_attr "$home" "${flake_root}#homeConfigurations.\"${home}\".activationPackage"; then
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

if [[ -n "$direct_output" ]]; then
  sort -u "$direct_output" -o "$direct_output"
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
