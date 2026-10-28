#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
flake_root=""
work_dir=""
leaf=""
summary=""
status=inconclusive
reason=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake-root) flake_root="$2"; shift 2 ;;
    --work-dir) work_dir="$2"; shift 2 ;;
    --leaf) leaf="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$flake_root" || -z "$work_dir" ]]; then
  echo "--flake-root and --work-dir are required" >&2
  exit 2
fi
flake_root="$(realpath "$flake_root")"
mkdir -p "$work_dir"
work_dir="$(realpath "$work_dir")"
store_root="$(mktemp -d "$work_dir/store.XXXXXX")"
for file in builds.tsv fetches.tsv allowed-local.tsv direct.tsv blocked.tsv; do
  : > "$work_dir/$file"
done

report() {
  local destination="${summary:-$work_dir/summary.md}" file
  jq -n --arg status "$status" --arg reason "$reason" \
    '{status: $status, reason: $reason}' > "$work_dir/result.json"
  {
    echo '## Cache preflight'
    echo
    printf -- '- Candidate: `%s`\n- Status: `%s`\n' "$flake_root" "$status"
    printf -- '- Builds: %s; fetches: %s; blocked: %s\n' \
      "$(wc -l < "$work_dir/builds.tsv")" "$(wc -l < "$work_dir/fetches.tsv")" \
      "$(wc -l < "$work_dir/blocked.tsv")"
    if [[ -n "$reason" ]]; then printf -- '- Reason: %s\n' "$reason"; fi
    echo
    echo 'Metadata planning only; downloads, signatures and host activation require separate acceptance.'
    echo "Complete lists, target/group mappings and raw Nix logs: $work_dir"
    for file in builds.tsv fetches.tsv blocked.tsv; do
      [[ -s "$work_dir/$file" ]] || continue
      printf '\n### %s (first 20)\n\n```text\n' "$file"
      sed -n '1,20p' "$work_dir/$file"
      echo '```'
    done
  } >> "$destination"
  printf 'status=%s reason=%s\n' "$status" "$reason"
}

stop_inconclusive() {
  reason="$1"
  echo "cache preflight inconclusive: $reason" >&2
  report
  exit 1
}

for policy in maintenancePolicy maintenancePolicyBase; do
  if ! nix eval --json --impure --no-write-lock-file \
    --option allow-import-from-derivation false \
    "$flake_root#lib.$policy" > "$work_dir/$policy.json" \
    2> "$work_dir/$policy.err"; then
    stop_inconclusive "$policy evaluation failed"
  fi
done

for target in homePC linglong 'ci@headless'; do
  prefix="$work_dir/${target//@/_}"
  policy=maintenancePolicy
  if [[ "$target" == 'ci@headless' ]]; then
    config_attr="$flake_root#homeConfigurations.\"ci@headless\".config"
    attr="$config_attr.activationPackage"
    toplevel='c.activationPackage.drvPath'
    policy=maintenancePolicyBase
  else
    config_attr="$flake_root#nixosConfigurations.$target.config"
    attr="$config_attr.system.build.toplevel"
    toplevel='c.system.build.toplevel.drvPath'
  fi
  if ! nix eval --json --impure --no-write-lock-file \
    --option allow-import-from-derivation false "$config_attr" \
    --apply "c: { settings = c.nix.settings; drvPath = $toplevel; }" \
    > "$prefix.evaluation.json" 2> "$prefix.evaluation.err"; then
    stop_inconclusive "$target configuration evaluation failed"
  fi
  if ! jq -e --arg target "$target" --arg attr "$attr" \
    --slurpfile policy "$work_dir/$policy.json" '
      .settings as $s |
      {target: $target, attr: $attr, drvPath: .drvPath,
        caches: {
          substituters: (($s.substituters // []) + ($s."extra-substituters" // []) | unique),
          keys: (($s."trusted-public-keys" // []) + ($s."extra-trusted-public-keys" // []) | unique)
        }, policy: $policy[0]} |
      if (.drvPath | type == "string" and test("^/nix/store/[0-9a-z]{32}-[^[:space:]]+\\.drv$")) and
        all(.caches[]; type == "array" and length > 0 and
          all(.[]; type == "string" and length > 0 and (test("[[:space:]]") | not)))
      then . else error("invalid target cache settings or root derivation") end
    ' "$prefix.evaluation.json" > "$prefix.target.json" 2> "$prefix.target.err"; then
    stop_inconclusive "$target cache settings or root derivation are invalid"
  fi
done

jq -s 'group_by({caches, policy}) | to_entries |
  map({id: .key, caches: .value[0].caches, policy: .value[0].policy, targets: .value})' \
  "$work_dir/homePC.target.json" "$work_dir/linglong.target.json" \
  "$work_dir/ci_headless.target.json" > "$work_dir/groups.json"

while IFS= read -r group; do
  id="$(jq -r '.id' <<< "$group")"
  prefix="$work_dir/group-$id"
  printf '%s\n' "$group" > "$prefix.json"
  mapfile -t attrs < <(jq -r '.targets[].attr' <<< "$group")
  expected="$(jq -c '[.targets[].drvPath]' <<< "$group")"
  targets="$(jq -r '[.targets[].target] | join(",")' <<< "$group")"
  substituters="$(jq -r '.caches.substituters | join(" ")' <<< "$group")"
  keys="$(jq -r '.caches.keys | join(" ")' <<< "$group")"
  echo "Planning $targets"
  if ! nix build --dry-run --json --log-format internal-json --no-link \
    --impure --no-write-lock-file --store "local?root=$store_root" \
    --option allow-import-from-derivation false --option fallback false \
    --option substituters "$substituters" --option extra-substituters '' \
    --option trusted-public-keys "$keys" --option extra-trusted-public-keys '' \
    --option require-sigs true \
    "${attrs[@]}" > "$prefix.outputs.json" 2> "$prefix.nix.log"; then
    stop_inconclusive "$targets Nix dry-run failed"
  fi
  if ! jq -R -s --argjson expected "$expected" \
    --argjson outputs "$(cat "$prefix.outputs.json")" \
    -f "$script_dir/nix-plan.jq" "$prefix.nix.log" > "$prefix.plan.json" \
    2> "$prefix.plan.err" ||
    ! jq -e '.complete and ((.builds | length) + (.fetches | length) > 0)' \
      "$prefix.plan.json" > /dev/null; then
    stop_inconclusive "$targets Nix plan is empty, incomplete or unparseable"
  fi
  if ! jq -n --slurpfile plan "$prefix.plan.json" \
    --argjson policy "$(jq -c '.policy' <<< "$group")" --arg leaf "$leaf" \
    '{plan: $plan[0], policy: $policy, leaf: $leaf}' \
    | jq -f "$script_dir/classify-plan.jq" > "$prefix.classified.json" \
      2> "$prefix.classified.err"; then
    stop_inconclusive "$targets maintenance policy or plan is invalid"
  fi
  for field in builds fetches; do
    jq -r --arg targets "$targets" --arg field "$field" \
      '.[$field][] | [$targets, .] | @tsv' "$prefix.plan.json" >> "$work_dir/$field.tsv"
  done
  for field in allowedLocal direct blocked; do
    file="$field"
    if [[ "$field" == allowedLocal ]]; then file=allowed-local; fi
    jq -r --arg targets "$targets" --arg field "$field" \
      '.[$field][] | [$targets, .] | @tsv' "$prefix.classified.json" >> "$work_dir/$file.tsv"
  done
done < <(jq -c '.[]' "$work_dir/groups.json")

status=pass
if [[ -s "$work_dir/blocked.tsv" ]]; then
  status=blocked
  reason='No usable substitute for unapproved local builds in the current Nix plan; this does not prove absence from every remote cache.'
fi
report
[[ "$status" == pass ]]
