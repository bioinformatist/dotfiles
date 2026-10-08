#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
base_root=""
head_root=""
work_dir=""
leaf=""
summary=""
upstream=inconclusive
china=inconclusive
reason=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-root) base_root="$2"; shift 2 ;;
    --head-root) head_root="$2"; shift 2 ;;
    --work-dir) work_dir="$2"; shift 2 ;;
    --leaf) leaf="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$base_root" || -z "$head_root" || -z "$work_dir" ]]; then
  echo "--base-root, --head-root and --work-dir are required" >&2
  exit 2
fi
base_root="$(realpath "$base_root")"
head_root="$(realpath "$head_root")"
work_dir="$(realpath "$work_dir")"
mkdir -p "$work_dir/base-store" "$work_dir/head-store"
for file in base-builds.tsv head-builds.tsv base-fetches.tsv head-fetches.tsv \
  base-unapproved.txt head-unapproved.txt upstream-new.txt \
  official-paths.txt ustc-results.tsv china-new.txt china-uncertain.txt; do
  : > "$work_dir/$file"
done

# Keep the cache set explicit. The USTC check below only examines paths that
# the official cache offers; community-only substitutes belong upstream.
substituters="https://cache.nixos.org https://cache.numtide.com https://anyrun.cachix.org https://hyprland.cachix.org https://noctalia.cachix.org"
keys="niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
ustc="https://mirrors.ustc.edu.cn/nix-channels/store"

append_list() {
  local title="$1" file="$2" destination="$3"
  [[ -s "$file" ]] || return 0
  {
    printf '\n### %s\n\n```text\n' "$title"
    sed -n '1,20p' "$file"
    if [[ "$(wc -l < "$file")" -gt 20 ]]; then echo '... truncated ...'; fi
    echo '```'
  } >> "$destination"
}

report() {
  local destination="${summary:-$work_dir/summary.md}"
  {
    echo '## Cache preflight'
    echo
    printf -- "- Upstream: \`%s\` (head %s, new %s)\n" "$upstream" \
      "$(wc -l < "$work_dir/head-unapproved.txt")" "$(wc -l < "$work_dir/upstream-new.txt")"
    printf -- "- USTC: \`%s\` (new paths checked %s of %s selected, new gaps %s; unchanged paths not probed)\n" \
      "$china" "$(wc -l < "$work_dir/ustc-results.tsv")" \
      "$(wc -l < "$work_dir/official-paths.txt")" \
      "$(wc -l < "$work_dir/china-new.txt")"
    if [[ -n "$reason" ]]; then printf -- '- Inconclusive reason: %s\n' "$reason"; fi
    echo
    echo "Raw Nix, cache and curl responses: $work_dir"
  } >> "$destination"
  append_list 'Head upstream gaps' "$work_dir/head-unapproved.txt" "$destination"
  append_list 'New upstream gaps' "$work_dir/upstream-new.txt" "$destination"
  append_list 'New USTC gaps' "$work_dir/china-new.txt" "$destination"
  append_list 'Uncertain USTC paths' "$work_dir/china-uncertain.txt" "$destination"
  printf 'upstream=%s china=%s reason=%s\n' "$upstream" "$china" "$reason"
}

update_china_lists() {
  awk -F '\t' '$2 == "miss" {print $1}' "$work_dir/ustc-results.tsv" \
    > "$work_dir/china-new.txt"
  awk -F '\t' '$2 == "inconclusive" {print $1}' "$work_dir/ustc-results.tsv" \
    > "$work_dir/china-uncertain.txt"
}

stop_inconclusive() {
  reason="$1"
  update_china_lists
  echo "cache preflight inconclusive: $reason" >&2
  report
  exit 1
}

plan_revision() {
  local revision="$1" root="$2" target attr prefix parsed
  if ! nix eval --json --impure --no-write-lock-file \
    "$root#lib.maintenancePolicy" > "$work_dir/$revision-policy.json" \
    2> "$work_dir/$revision-policy.err"; then
    reason="$revision policy evaluation failed"
    return 1
  fi
  if ! jq -e '.allowedLocalBuildMarkers | type == "array"' \
    "$work_dir/$revision-policy.json" > /dev/null ||
    ! jq -e '.allowedDirectFetchMarkers | type == "array"' \
      "$work_dir/$revision-policy.json" > /dev/null; then
    reason="$revision policy has invalid marker arrays"
    return 1
  fi
  for target in homePC linglong 'ci@headless'; do
    if [[ "$target" == 'ci@headless' ]]; then
      attr="$root#homeConfigurations.\"ci@headless\".activationPackage"
    else
      attr="$root#nixosConfigurations.$target.config.system.build.toplevel"
    fi
    prefix="$work_dir/$revision-${target//@/_}"
    echo "Planning $revision $target: $attr"
    if ! nix build --dry-run --json --log-format internal-json --no-link \
      --impure --no-write-lock-file \
      --store "local?root=$work_dir/$revision-store" \
      --option allow-import-from-derivation false \
      --option substituters "$substituters" \
      --option extra-substituters '' \
      --option extra-trusted-public-keys "$keys" \
      "$attr" > "$prefix.outputs.json" 2> "$prefix.nix.log"; then
      reason="$revision $target Nix dry-run failed"
      return 1
    fi
    if ! jq -e 'type == "array" and length > 0 and
      all(.[]; type == "object" and (.drvPath | type == "string") and
        (.outputs | type == "object" and length > 0))' \
      "$prefix.outputs.json" > /dev/null; then
      reason="$revision $target Nix output JSON is invalid"
      return 1
    fi
    parsed="$prefix.plan.json"
    if ! jq -R -s -f "$script_dir/nix-plan.jq" "$prefix.nix.log" > "$parsed" ||
      ! jq -e '.complete == true and (.builds | type == "array") and
        (.fetches | type == "array") and
        ((.builds | length) + (.fetches | length) > 0)' "$parsed" > /dev/null; then
      reason="$revision $target Nix plan is incomplete or unparseable"
      return 1
    fi
    jq -r --arg target "$target" '.builds[] | [$target, .] | @tsv' "$parsed" \
      >> "$work_dir/$revision-builds.tsv"
    jq -r --arg target "$target" '.fetches[] | [$target, .] | @tsv' "$parsed" \
      >> "$work_dir/$revision-fetches.tsv"
  done
  sort -u "$work_dir/$revision-builds.tsv" -o "$work_dir/$revision-builds.tsv"
  sort -u "$work_dir/$revision-fetches.tsv" -o "$work_dir/$revision-fetches.tsv"
}

contains_marker() {
  local path="$1" marker
  shift
  for marker in "$@"; do
    if [[ -n "$marker" && "$path" == *"$marker"* ]]; then return 0; fi
  done
  return 1
}

classify_builds() {
  local revision="$1" policy="$work_dir/$1-policy.json" target drv
  local -a local_markers direct_markers leaf_markers
  if ! jq -e 'all(.allowedLocalBuildMarkers[]; type == "string") and
    all(.allowedDirectFetchMarkers[]; type == "string") and
    (.leafDirectFetchMarkers | type == "object")' "$policy" > /dev/null; then
    reason="$revision policy markers are invalid"
    return 1
  fi
  mapfile -t local_markers < <(jq -r '.allowedLocalBuildMarkers[]' "$policy")
  mapfile -t direct_markers < <(jq -r '.allowedDirectFetchMarkers[]' "$policy")
  if [[ -n "$leaf" ]]; then
    mapfile -t leaf_markers < <(jq -r --arg leaf "$leaf" '.leafDirectFetchMarkers[$leaf][]?' "$policy")
  else
    leaf_markers=("${direct_markers[@]}")
  fi
  while IFS=$'\t' read -r target drv; do
    [[ -n "$drv" ]] || continue
    if contains_marker "$drv" "${local_markers[@]}"; then continue; fi
    if contains_marker "$drv" "${direct_markers[@]}" &&
      contains_marker "$drv" "${leaf_markers[@]}"; then continue; fi
    printf '%s\n' "$drv" >> "$work_dir/$revision-unapproved.txt"
  done < "$work_dir/$revision-builds.tsv"
  sort -u "$work_dir/$revision-unapproved.txt" -o "$work_dir/$revision-unapproved.txt"
}

# Nix 2.34.7 returns one JSON key per requested path, using null for a 404.
# A successful query may still contain warnings from recovered native retries.
query_cache() {
  local name="$1" url="$2" input="$3" output="$work_dir/$1.json"
  local stderr="$work_dir/$1.err"
  if [[ ! -s "$input" ]]; then echo '{}' > "$output"; : > "$stderr"; return 0; fi
  if ! nix path-info --json --json-format 1 --store "$url" --stdin \
    --option http-connections 1 \
    < "$input" > "$output" 2> "$stderr"; then
    reason="$name cache query failed"
    return 1
  fi
  jq -R -s 'split("\n") | map(select(length > 0))' "$input" > "$input.json"
  if ! jq -e --slurpfile requested "$input.json" \
    'type == "object" and (keys == ($requested[0] | sort)) and
      all(.[]; . == null or type == "object")' "$output" > /dev/null; then
    reason="$name cache query returned an incomplete manifest"
    return 1
  fi
}

if ! plan_revision base "$base_root"; then stop_inconclusive "$reason"; fi
if ! plan_revision head "$head_root"; then stop_inconclusive "$reason"; fi
if ! classify_builds base || ! classify_builds head; then stop_inconclusive "$reason"; fi
comm -13 "$work_dir/base-unapproved.txt" "$work_dir/head-unapproved.txt" \
  > "$work_dir/upstream-new.txt"
upstream=pass
if [[ -s "$work_dir/upstream-new.txt" ]]; then upstream=miss; fi

for revision in base head; do
  awk -F '\t' '{print $2}' "$work_dir/$revision-fetches.tsv" | sort -u \
    > "$work_dir/$revision-fetch-paths.txt"
done
comm -13 "$work_dir/base-fetch-paths.txt" "$work_dir/head-fetch-paths.txt" \
  > "$work_dir/new-fetch-paths.txt"
if ! query_cache official https://cache.nixos.org "$work_dir/new-fetch-paths.txt"; then
  stop_inconclusive "$reason"
fi
jq -r 'to_entries[] | select(.value != null) | .key' "$work_dir/official.json" \
  | sort > "$work_dir/official-paths.txt"
if ! query_cache ustc "$ustc" "$work_dir/official-paths.txt"; then
  stop_inconclusive "$reason"
fi

# curl owns serial pacing and retries. URL validation keeps all requests on USTC.
declare -a paths=() curl_args=()
curl_args=(--rate 1/s --head --silent --show-error --no-buffer \
  --retry 4 --max-time 30 --write-out '%{urlnum}\t%{response_code}\t%{exitcode}\t%{redirect_url}\n')
if ! jq -r --rawfile requested "$work_dir/official-paths.txt" \
  '. as $manifest |
    ($requested | split("\n")[] | select(length > 0)) as $path |
    [$path, ($manifest[$path] == null), ($manifest[$path].url // "" | tostring)] | @tsv' \
  "$work_dir/ustc.json" > "$work_dir/ustc-projection.tsv"; then
  stop_inconclusive 'USTC manifest projection failed'
fi
while IFS=$'\t' read -r path missing url; do
  if [[ "$missing" == true ]]; then
    printf '%s\tmiss\tmetadata missing\n' "$path" >> "$work_dir/ustc-results.tsv"
  elif [[ ! "$url" =~ ^nar/[A-Za-z0-9._-]+$ ]]; then
    printf '%s\tinconclusive\tinvalid NAR URL\n' "$path" >> "$work_dir/ustc-results.tsv"
    stop_inconclusive 'USTC manifest contains an invalid NAR URL'
  else
    paths+=("$path")
    curl_args+=(--output /dev/null --url "$ustc/$url")
  fi
done < "$work_dir/ustc-projection.tsv"

if [[ ${#paths[@]} -gt 0 ]]; then
  # Read each completed transfer while curl is still running, so an uncertain
  # response can stop the remaining URLs before curl starts them.
  mkfifo "$work_dir/curl.pipe"
  # curl write-out uses stdout buffering independently of --no-buffer.
  stdbuf -oL curl "${curl_args[@]}" > "$work_dir/curl.pipe" 2> "$work_dir/curl.err" &
  curl_pid=$!
  completed=0
  transfer_uncertain=false
  while IFS=$'\t' read -r index code exitcode redirect; do
    printf '%s\t%s\t%s\t%s\n' "$index" "$code" "$exitcode" "$redirect" \
      >> "$work_dir/curl-results.tsv"
    if [[ ! "$index" =~ ^[0-9]+$ || "$index" -ne "$completed" ||
      "$completed" -ge "${#paths[@]}" || ! "$code" =~ ^[0-9]{3}$ ||
      ! "$exitcode" =~ ^[0-9]+$ ]]; then
      reason='curl returned an invalid transfer manifest'
      transfer_uncertain=true
      break
    fi
    completed=$((completed + 1))
    if [[ "$exitcode" != 0 || -n "$redirect" ]]; then
      state=inconclusive
    elif [[ "$code" == 200 ]]; then
      state=ready
    elif [[ "$code" == 404 || "$code" == 410 ]]; then
      state=miss
    else
      state=inconclusive
    fi
    printf '%s\t%s\tHTTP %s, curl %s\n' "${paths[$index]}" "$state" \
      "$code" "$exitcode" >> "$work_dir/ustc-results.tsv"
    if [[ "$state" == inconclusive ]]; then
      reason='USTC NAR response is uncertain; remaining URLs skipped'
      transfer_uncertain=true
      break
    fi
  done < "$work_dir/curl.pipe"
  if [[ "$transfer_uncertain" == true ]]; then kill "$curl_pid" 2>/dev/null || true; fi
  curl_rc=0
  wait "$curl_pid" || curl_rc=$?
  rm "$work_dir/curl.pipe"
  if [[ "$transfer_uncertain" == true ]]; then
    stop_inconclusive "$reason"
  fi
  if [[ "$curl_rc" -ne 0 || "$completed" -ne "${#paths[@]}" ]]; then
    stop_inconclusive 'curl returned an incomplete transfer manifest'
  fi
else
  : > "$work_dir/curl-results.tsv"
  : > "$work_dir/curl.err"
fi
sort -u "$work_dir/ustc-results.tsv" -o "$work_dir/ustc-results.tsv"

update_china_lists
china=pass
if [[ -s "$work_dir/china-new.txt" ]]; then china=miss; fi
if [[ -s "$work_dir/china-uncertain.txt" ]]; then
  china=inconclusive
  reason='USTC metadata or NAR response is uncertain'
fi
report
if [[ "$upstream" != pass || "$china" != pass ]]; then exit 1; fi
