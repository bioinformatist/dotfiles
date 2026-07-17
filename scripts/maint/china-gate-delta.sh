#!/usr/bin/env bash
set -euo pipefail

default_china_substituters="https://mirrors.ustc.edu.cn/nix-channels/store https://anyrun.cachix.org https://hyprland.cachix.org https://noctalia.cachix.org"
default_china_extra_trusted_public_keys="anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
china_substituters="${CHINA_SUBSTITUTERS:-${CHINA_SUBSTITUTER:-$default_china_substituters}}"
china_extra_trusted_public_keys="${CHINA_EXTRA_TRUSTED_PUBLIC_KEYS:-$default_china_extra_trusted_public_keys}"
base_flake_root=""
head_flake_root=""
base_policy_file=""
head_policy_file=""
blocked_output=""
direct_output=""
hosts=()
homes=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-flake-root)
      base_flake_root="$2"
      shift 2
      ;;
    --base-flake-root=*)
      base_flake_root="${1#*=}"
      shift
      ;;
    --head-flake-root)
      head_flake_root="$2"
      shift 2
      ;;
    --head-flake-root=*)
      head_flake_root="${1#*=}"
      shift
      ;;
    --base-policy-file)
      base_policy_file="$2"
      shift 2
      ;;
    --base-policy-file=*)
      base_policy_file="${1#*=}"
      shift
      ;;
    --head-policy-file|--policy-file)
      head_policy_file="$2"
      shift 2
      ;;
    --head-policy-file=*|--policy-file=*)
      head_policy_file="${1#*=}"
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

if [[ -z "$base_flake_root" || -z "$head_flake_root" || -z "$blocked_output" || -z "$direct_output" ]]; then
  echo "base/head flake roots, blocked output, and direct output are required" >&2
  exit 2
fi

base_flake_root="$(cd -- "$base_flake_root" && pwd)"
head_flake_root="$(cd -- "$head_flake_root" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

resolve_policy_file() {
  local flake_root="$1"
  local requested_file="$2"
  local evaluated_file="$3"

  if [[ -n "$requested_file" ]]; then
    realpath "$requested_file"
  elif [[ -f "${flake_root}/scripts/maint/policy.json" \
    && ! -f "${flake_root}/scripts/maint/policy-workstation.json" \
    && ! -f "${flake_root}/scripts/maint/policy-overrides.json" ]]; then
    # Revisions from before the flake policy interface stored one complete policy.
    realpath "${flake_root}/scripts/maint/policy.json"
  else
    nix eval --json "${flake_root}#lib.maintenancePolicy" > "$evaluated_file"
    realpath "$evaluated_file"
  fi
}

base_policy_file="$(resolve_policy_file "$base_flake_root" "$base_policy_file" "$tmp/base-policy.json")"
head_policy_file="$(resolve_policy_file "$head_flake_root" "$head_policy_file" "$tmp/head-policy.json")"

normalize_policy() {
  jq -S -c '
    .riskMarkers |= (sort | unique)
    | .allowedLocalBuildMarkers |= (sort | unique)
    | .allowedDirectFetchMarkers |= (sort | unique)
    | .leafDirectFetchMarkers |= with_entries(.value |= (sort | unique))
  ' "$1"
}

normalize_policy "$base_policy_file" > "$tmp/base-policy-normalized.json"
normalize_policy "$head_policy_file" > "$tmp/head-policy-normalized.json"
if ! cmp -s "$tmp/base-policy-normalized.json" "$tmp/head-policy-normalized.json"; then
  echo "policy changes require the full China gate" >&2
  exit 2
fi
if [[ ${#hosts[@]} -eq 0 && ${#homes[@]} -eq 0 ]]; then
  hosts=(homePC linglong)
fi

: > "$blocked_output"
: > "$direct_output"
: > "$tmp/new-output-map.tsv"

labels=()
attrs=()
for host in "${hosts[@]}"; do
  labels+=("$host")
  attrs+=("nixosConfigurations.${host}.config.system.build.toplevel")
done
for home in "${homes[@]}"; do
  labels+=("$home")
  attrs+=("homeConfigurations.\"${home}\".activationPackage")
done

collect_required_outputs() {
  local flake_root="$1"
  local side="$2"
  local graph="$tmp/${side}.json"
  local edges="$tmp/${side}-edges.tsv"
  local installables=()
  local root_drvs=()
  local index

  for attr in "${attrs[@]}"; do
    installables+=("${flake_root}#${attr}")
  done
  nix derivation show --recursive --no-pretty "${installables[@]}" > "$graph"
  if ! jq -e '.version == 4 and (.derivations | type == "object")' "$graph" >/dev/null; then
    echo "unsupported derivation graph format for ${flake_root}" >&2
    return 2
  fi
  if jq -e 'any(.derivations[].inputs.drvs[]?; ((.dynamicOutputs // {}) | length) > 0)' "$graph" >/dev/null; then
    echo "dynamic derivation outputs require the full China gate for ${flake_root}" >&2
    return 2
  fi

  for index in "${!installables[@]}"; do
    local root_drv
    root_drv="$(nix path-info --derivation "${installables[$index]}")"
    if [[ "$root_drv" == *$'\n'* ]]; then
      echo "installable resolved to multiple root derivations: ${installables[$index]}" >&2
      return 2
    fi
    root_drvs+=("$root_drv")
  done

  jq -r '
    .derivations as $drvs
    | $drvs
    | to_entries[] as $parent
    | $parent.value.inputs.drvs
    | to_entries[] as $input
    | $input.value.outputs[] as $output
    | [$parent.key, $input.key, $output, $drvs[$input.key].env[$output]]
    | @tsv
  ' "$graph" | sort -u > "$edges"

  if ! awk -F '\t' 'NF != 4 || $1 !~ /[.]drv$/ || $2 !~ /[.]drv$/ || $4 !~ "^/nix/store/" { exit 1 }' "$edges"; then
    echo "derivation graph contains an unresolved dependency output for ${flake_root}" >&2
    return 2
  fi

  for index in "${!root_drvs[@]}"; do
    local root_drv="${root_drvs[$index]}"
    local root_key="${root_drv#/nix/store/}"
    local closure="$tmp/${index}-${side}-closure.drvs"
    local output="$tmp/${index}-${side}.tsv"

    if ! jq -e --arg root "$root_key" '.derivations[$root] != null' "$graph" >/dev/null; then
      echo "root derivation is absent from graph for ${installables[$index]}" >&2
      return 2
    fi
    nix-store -qR "$root_drv" \
      | sed -n 's#^/nix/store/\(.*[.]drv\)$#\1#p' \
      | sort -u > "$closure"
    awk -F '\t' '
      BEGIN { OFS="\t" }
      NR == FNR { reachable[$1] = 1; next }
      $1 in reachable { print $2, $3, $4 }
    ' "$closure" "$edges" > "$output"
    jq -r --arg root "$root_key" '
      .derivations as $drvs
      | $drvs[$root].outputs
      | keys[] as $output
      | [$root, $output, $drvs[$root].env[$output]]
      | @tsv
    ' "$graph" >> "$output"
    if ! awk -F '\t' 'NF != 3 || $1 !~ /[.]drv$/ || $3 !~ "^/nix/store/" { exit 1 }' "$output"; then
      echo "derivation graph contains an unresolved root output for ${installables[$index]}" >&2
      return 2
    fi
    sort -u "$output" -o "$output"
  done
}

collect_required_outputs "$base_flake_root" base
collect_required_outputs "$head_flake_root" head
for index in "${!labels[@]}"; do
  comm -13 "$tmp/${index}-base.tsv" "$tmp/${index}-head.tsv" > "$tmp/${index}-new.tsv"
  awk -F '\t' -v label="${labels[$index]}" 'BEGIN { OFS="\t" } { print label, "/nix/store/" $1, $3 }' "$tmp/${index}-new.tsv" >> "$tmp/new-output-map.tsv"
done

sort -u "$tmp/new-output-map.tsv" -o "$tmp/new-output-map.tsv"

mapfile -t allowed_markers < <(jq -r '.allowedLocalBuildMarkers[]' "$head_policy_file")
mapfile -t direct_markers < <(jq -r '.allowedDirectFetchMarkers[]' "$head_policy_file")

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

: > "$tmp/query-output-map.tsv"
while IFS=$'\t' read -r label drv output; do
  [[ -n "${label}${drv}${output}" ]] || continue
  if ! contains_marker "$drv" "${allowed_markers[@]}"; then
    printf '%s\t%s\t%s\n' "$label" "$drv" "$output" >> "$tmp/query-output-map.tsv"
  fi
done < "$tmp/new-output-map.tsv"

cut -f3 "$tmp/query-output-map.tsv" | sort -u > "$tmp/new.outputs"
if [[ ! -s "$tmp/new.outputs" ]]; then
  echo "China delta gate found no new outputs that require cache coverage"
  exit 0
fi

: > "$tmp/available.outputs"
read -r -a substituters <<< "$china_substituters"
ordered_substituters=()
deferred_substituters=()
for substituter in "${substituters[@]}"; do
  if [[ "$substituter" == *"mirrors.ustc.edu.cn"* ]]; then
    deferred_substituters+=("$substituter")
  else
    ordered_substituters+=("$substituter")
  fi
done
ordered_substituters+=("${deferred_substituters[@]}")

for substituter in "${ordered_substituters[@]}"; do
  comm -23 "$tmp/new.outputs" "$tmp/available.outputs" > "$tmp/remaining.outputs"
  if [[ ! -s "$tmp/remaining.outputs" ]]; then
    break
  fi
  if ! nix path-info \
    --json \
    --json-format 1 \
    --store "$substituter" \
    --stdin \
    < "$tmp/remaining.outputs" \
    > "$tmp/store.json" \
    2> "$tmp/store.err"; then
    echo "failed to query ${substituter}" >&2
    sed -n '1,40p' "$tmp/store.err" >&2
    exit 2
  fi

  jq -r 'to_entries[] | select(.value != null) | .key' "$tmp/store.json" > "$tmp/store.available"
  if [[ -s "$tmp/store.available" ]]; then
    if ! nix store verify \
      --no-contents \
      --store "$substituter" \
      --stdin \
      --option extra-trusted-public-keys "$china_extra_trusted_public_keys" \
      < "$tmp/store.available" \
      > /dev/null; then
      echo "untrusted cache metadata from ${substituter}" >&2
      exit 2
    fi
    cat "$tmp/store.available" >> "$tmp/available.outputs"
    sort -u "$tmp/available.outputs" -o "$tmp/available.outputs"
  fi
done
comm -23 "$tmp/new.outputs" "$tmp/available.outputs" > "$tmp/missing.outputs"

awk -F '\t' '
  BEGIN { OFS="\t" }
  NR == FNR { missing[$1] = 1; next }
  $3 in missing { print $1, $2 }
' "$tmp/missing.outputs" "$tmp/query-output-map.tsv" | sort -u > "$tmp/missing-drvs.tsv"

while IFS=$'\t' read -r label drv; do
  [[ -n "${label}${drv}" ]] || continue
  if contains_marker "$drv" "${allowed_markers[@]}"; then
    continue
  elif contains_marker "$drv" "${direct_markers[@]}"; then
    printf '%s\t%s\n' "$label" "$drv" >> "$direct_output"
  else
    printf '%s\t%s\n' "$label" "$drv" >> "$blocked_output"
  fi
done < "$tmp/missing-drvs.tsv"

sort -u "$blocked_output" -o "$blocked_output"
sort -u "$direct_output" -o "$direct_output"
echo "China delta gate queried $(wc -l < "$tmp/new.outputs" | tr -d '[:space:]') new required outputs; $(wc -l < "$tmp/missing-drvs.tsv" | tr -d '[:space:]') derivations need local builds"
