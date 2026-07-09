#!/usr/bin/env bash
set -euo pipefail

base_blocked=""
base_direct=""
head_blocked=""
head_direct=""
output_dir=""
leaf=""
github_output=""
summary=""
fail_on_miss=false

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
policy_file="${repo_root}/scripts/maint/policy.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-blocked)
      base_blocked="$2"
      shift 2
      ;;
    --base-blocked=*)
      base_blocked="${1#*=}"
      shift
      ;;
    --base-direct)
      base_direct="$2"
      shift 2
      ;;
    --base-direct=*)
      base_direct="${1#*=}"
      shift
      ;;
    --head-blocked)
      head_blocked="$2"
      shift 2
      ;;
    --head-blocked=*)
      head_blocked="${1#*=}"
      shift
      ;;
    --head-direct)
      head_direct="$2"
      shift 2
      ;;
    --head-direct=*)
      head_direct="${1#*=}"
      shift
      ;;
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --output-dir=*)
      output_dir="${1#*=}"
      shift
      ;;
    --leaf)
      leaf="$2"
      shift 2
      ;;
    --leaf=*)
      leaf="${1#*=}"
      shift
      ;;
    --github-output)
      github_output="$2"
      shift 2
      ;;
    --github-output=*)
      github_output="${1#*=}"
      shift
      ;;
    --summary)
      summary="$2"
      shift 2
      ;;
    --summary=*)
      summary="${1#*=}"
      shift
      ;;
    --fail-on-miss)
      fail_on_miss=true
      shift
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      echo "unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

required=(
  "$base_blocked"
  "$base_direct"
  "$head_blocked"
  "$head_direct"
  "$output_dir"
)
for value in "${required[@]}"; do
  if [[ -z "$value" ]]; then
    echo "base/head files and --output-dir are required" >&2
    exit 2
  fi
done

mkdir -p "$output_dir"

new_blocked="${output_dir}/china-new.blocked"
new_direct="${output_dir}/china-new.direct"
direct_allowed="${output_dir}/china-direct.allowed"
head_unapproved="${output_dir}/china-unapproved.blocked"
new_unapproved="${output_dir}/china-new-unapproved.blocked"

comm -13 "$base_blocked" "$head_blocked" > "$new_blocked"
comm -13 "$base_direct" "$head_direct" > "$new_direct"

: > "$direct_allowed"
cp "$head_blocked" "$head_unapproved"
cp "$new_blocked" "$new_unapproved"

if [[ -n "$leaf" ]]; then
  mapfile -t direct_markers < <(
    jq -r --arg leaf "$leaf" '.leafDirectFetchMarkers[$leaf][]?' "$policy_file"
  )
else
  mapfile -t direct_markers < <(
    jq -r '.allowedDirectFetchMarkers[]' "$policy_file"
  )
fi

while IFS=$'\t' read -r host drv; do
  [[ -n "${host}${drv}" ]] || continue

  allowed_direct=false
  for marker in "${direct_markers[@]}"; do
    if [[ -n "$marker" && "$drv" == *"$marker"* ]]; then
      allowed_direct=true
      break
    fi
  done

  if [[ "$allowed_direct" == "true" ]]; then
    printf '%s\t%s\n' "$host" "$drv" >> "$direct_allowed"
  else
    printf '%s\t%s\n' "$host" "$drv" >> "$head_unapproved"
    printf '%s\t%s\n' "$host" "$drv" >> "$new_unapproved"
  fi
done < "$new_direct"

sort -u "$direct_allowed" -o "$direct_allowed"
sort -u "$head_unapproved" -o "$head_unapproved"
sort -u "$new_unapproved" -o "$new_unapproved"

line_count() {
  local file="$1"
  wc -l < "$file" | tr -d '[:space:]'
}

head_blocked_count="$(line_count "$head_blocked")"
new_blocked_count="$(line_count "$new_blocked")"
direct_fetch_count="$(line_count "$direct_allowed")"
head_unapproved_count="$(line_count "$head_unapproved")"
new_unapproved_count="$(line_count "$new_unapproved")"
status=pass
if [[ -s "$head_unapproved" ]]; then
  status=miss
fi
direct_fetch=false
if [[ -s "$direct_allowed" ]]; then
  direct_fetch=true
fi

if [[ -n "$github_output" ]]; then
  {
    echo "status=${status}"
    echo "direct_fetch=${direct_fetch}"
    echo "head_blocked_count=${head_blocked_count}"
    echo "new_blocked_count=${new_blocked_count}"
    echo "direct_fetch_count=${direct_fetch_count}"
    echo "head_unapproved_count=${head_unapproved_count}"
    echo "new_unapproved_count=${new_unapproved_count}"
  } >> "$github_output"
fi

append_records() {
  local title="$1"
  local file="$2"

  [[ -s "$file" ]] || return 0
  {
    echo ""
    echo "### ${title}"
    echo '```text'
    sed -n '1,20p' "$file"
    if [[ "$(wc -l < "$file")" -gt 20 ]]; then
      echo "... truncated ..."
    fi
    echo '```'
  } >> "$summary"
}

if [[ -n "$summary" ]]; then
  {
    echo "## Maintenance gate"
    echo ""
    echo "- Head blocked derivations: \`${head_blocked_count}\`"
    echo "- New blocked derivations: \`${new_blocked_count}\`"
    echo "- Declared direct fetches: \`${direct_fetch_count}\`"
    echo "- Head unapproved derivations: \`${head_unapproved_count}\`"
    echo "- New unapproved derivations: \`${new_unapproved_count}\`"
  } >> "$summary"

  append_records "Head blocked derivations" "$head_blocked"
  append_records "New blocked derivations" "$new_blocked"
  append_records "Declared direct fetches" "$direct_allowed"
  append_records "Head unapproved derivations" "$head_unapproved"
  append_records "New unapproved derivations" "$new_unapproved"
fi

if [[ "$status" == "miss" && "$fail_on_miss" == "true" ]]; then
  exit 1
fi
