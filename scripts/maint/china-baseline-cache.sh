#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
cache_dir="${2:-}"
base_sha="${3:-}"
nix_version="${4:-}"
runner_os="${5:-}"
runner_arch="${6:-}"

if [[ "$mode" != "create" && "$mode" != "validate" ]]; then
  echo "usage: $0 <create|validate> <cache-dir> <base-sha> <nix-version> <runner-os> <runner-arch>" >&2
  exit 2
fi

required=("$cache_dir" "$base_sha" "$nix_version" "$runner_os" "$runner_arch")
for value in "${required[@]}"; do
  if [[ -z "$value" ]]; then
    echo "cache directory and baseline identity fields are required" >&2
    exit 2
  fi
done

blocked="$cache_dir/china-base.blocked"
direct="$cache_dir/china-base.direct"
manifest="$cache_dir/manifest.json"

validate_report() {
  local report="$1"

  [[ -f "$report" ]] || return 1
  sort -c -u "$report"
  awk -F '\t' '
    NF != 2 { exit 1 }
    $1 !~ /^(homePC|linglong|ci@headless)$/ { exit 1 }
    $2 !~ /^\/nix\/store\/.*\.drv$/ { exit 1 }
  ' "$report"
}

if [[ "$mode" == "create" ]]; then
  mkdir -p "$cache_dir"
  validate_report "$blocked"
  validate_report "$direct"

  blocked_sha="$(sha256sum "$blocked" | cut -d' ' -f1)"
  direct_sha="$(sha256sum "$direct" | cut -d' ' -f1)"
  jq -n \
    --argjson schema 1 \
    --arg baseSha "$base_sha" \
    --arg nixVersion "$nix_version" \
    --arg runnerOs "$runner_os" \
    --arg runnerArch "$runner_arch" \
    --arg blockedSha256 "$blocked_sha" \
    --arg directSha256 "$direct_sha" \
    '{
      schema: $schema,
      baseSha: $baseSha,
      nixVersion: $nixVersion,
      runnerOs: $runnerOs,
      runnerArch: $runnerArch,
      targets: ["homePC", "linglong", "ci@headless"],
      blockedSha256: $blockedSha256,
      directSha256: $directSha256
    }' > "$manifest"
  exit 0
fi

validate_report "$blocked"
validate_report "$direct"
[[ -f "$manifest" ]]

blocked_sha="$(sha256sum "$blocked" | cut -d' ' -f1)"
direct_sha="$(sha256sum "$direct" | cut -d' ' -f1)"
jq -e \
  --arg baseSha "$base_sha" \
  --arg nixVersion "$nix_version" \
  --arg runnerOs "$runner_os" \
  --arg runnerArch "$runner_arch" \
  --arg blockedSha256 "$blocked_sha" \
  --arg directSha256 "$direct_sha" \
  '
    .schema == 1 and
    .baseSha == $baseSha and
    .nixVersion == $nixVersion and
    .runnerOs == $runnerOs and
    .runnerArch == $runnerArch and
    .targets == ["homePC", "linglong", "ci@headless"] and
    .blockedSha256 == $blockedSha256 and
    .directSha256 == $directSha256
  ' "$manifest" >/dev/null
