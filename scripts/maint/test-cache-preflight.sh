#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/base" "$tmp/head"
export MOCK_LOG="$tmp/mock.log"
: > "$MOCK_LOG"

cat > "$tmp/bin/nix" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
a=/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-official
b=/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-new-official
c=/nix/store/cccccccccccccccccccccccccccccccc-community
other=/nix/store/hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh-other-official
community=/nix/store/qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq-new-community
legacy=/nix/store/dddddddddddddddddddddddddddddddd-legacy.drv
bad=/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-bad.drv
glue=/nix/store/ffffffffffffffffffffffffffffffff-glue.drv
download=/nix/store/gggggggggggggggggggggggggggggggg-download.drv
case "$1" in
  eval)
    echo '{"allowedLocalBuildMarkers":["-glue.drv"],"allowedDirectFetchMarkers":["-download.drv"],"leafDirectFetchMarkers":{"zeroclaw":[]}}'
    ;;
  build)
    rev=base
    for arg in "$@"; do
      if [[ "$arg" == *head-store* ]]; then rev=head; fi
    done
    echo '[{"drvPath":"/nix/store/dddddddddddddddddddddddddddddddd-legacy.drv","outputs":{"out":"/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-official"}}]'
    if [[ "$MOCK_CASE" == emptyplan ]]; then exit 0; fi
    printf '@nix {"action":"msg","level":0,"msg":"this derivation will be built:"}\n' >&2
    printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$legacy" >&2
    if [[ "$rev" == head && "$MOCK_CASE" == newbuild ]]; then
      printf '@nix {"action":"msg","level":0,"msg":"this derivation will be built:"}\n' >&2
      printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$bad" >&2
    fi
    if [[ "$rev" == head && "$MOCK_CASE" == leafbad ]]; then
      printf '@nix {"action":"msg","level":0,"msg":"these 2 derivations will be built:"}\n' >&2
      printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$glue" >&2
      printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$download" >&2
    fi
    if [[ "$rev" == head && "$MOCK_CASE" == incomplete ]]; then
      printf '@nix {"action":"msg","level":0,"msg":"these 3 paths will be fetched (1 MiB download):"}\n' >&2
    else
      count=2
      if [[ "$rev" == head && "$MOCK_CASE" != baseline && "$MOCK_CASE" != newbuild && "$MOCK_CASE" != leafbad ]]; then count=3; fi
      if [[ "$rev" == head && "$MOCK_CASE" == denied ]]; then count=4; fi
      printf '@nix {"action":"msg","level":0,"msg":"these %s paths will be fetched (1 MiB download):"}\n' "$count" >&2
    fi
    printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$a" >&2
    printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$c" >&2
    if [[ "$rev" == head && "$MOCK_CASE" != baseline && "$MOCK_CASE" != newbuild && "$MOCK_CASE" != leafbad && "$MOCK_CASE" != incomplete ]]; then
      if [[ "$MOCK_CASE" == newcommunity ]]; then
        printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$community" >&2
      else
        printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$b" >&2
      fi
    fi
    if [[ "$rev" == head && "$MOCK_CASE" == denied ]]; then
      printf '@nix {"action":"msg","level":0,"msg":"  %s"}\n' "$other" >&2
    fi
    ;;
  path-info)
    [[ " $* " == *' --option http-connections 1 '* ]] || {
      echo 'Nix metadata HTTP concurrency is not capped' >&2
      exit 2
    }
    url=''
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == --store ]]; then url="$2"; break; fi
      shift
    done
    mapfile -t requested
    printf '%s %s\n' "$url" "${#requested[@]}" >> "$MOCK_LOG"
    if [[ "$MOCK_CASE" == requestfail && "$url" == *ustc* ]]; then
      echo 'connection failed' >&2
      exit 1
    fi
    printf '{'
    first=true
    missing=()
    for path in "${requested[@]}"; do
      if [[ "$first" == false ]]; then printf ','; fi
      first=false
      printf '"%s":' "$path"
      if [[ "$url" == *cache.nixos.org* && ( "$path" == "$c" || "$path" == "$community" ) ]]; then
        printf 'null'
        missing+=("$path")
      elif [[ "$url" == *ustc* ]]; then
        if [[ "$path" == "$b" ]]; then printf '{"url":"nar/new.nar.zst"}'
        else printf '{"url":"nar/old.nar.zst"}'; fi
      else
        printf '{"url":"nar/official.nar.zst"}'
      fi
    done
    printf '}\n'
    if [[ ${#missing[@]} -gt 0 ]]; then
      echo "don't know how to build these paths:" >&2
      printf '  %s\n' "${missing[@]}" >&2
    fi
    if [[ "$MOCK_CASE" == recovered && "$url" == *cache.nixos.org* ]]; then
      echo 'warning: retrying after a transient cache error' >&2
    fi
    ;;
  *) echo "unexpected nix command: $*" >&2; exit 2 ;;
esac
MOCK

cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ " $* " == *' --rate 1/s '* && " $* " == *' --retry 4 '* &&
  " $* " == *' --head '* && " $* " != *' --parallel'* ]] || {
  echo 'curl pacing or HEAD/retry options are wrong' >&2
  exit 2
}
index=0
for arg in "$@"; do
  if [[ "$arg" == https://mirrors.ustc.edu.cn/* ]]; then
    printf 'curl %s\n' "$arg" >> "$MOCK_LOG"
    code=200
    if [[ "$arg" == *new.nar.zst* && "$MOCK_CASE" == nar404 ]]; then code=404; fi
    if [[ "$arg" == *new.nar.zst* && "$MOCK_CASE" == denied ]]; then code=403; fi
    printf '%s\t%s\t0\t\n' "$index" "$code"
    if [[ "$MOCK_CASE" == denied ]]; then sleep 1; fi
    index=$((index + 1))
  fi
done
MOCK
chmod +x "$tmp/bin/nix" "$tmp/bin/curl"

run_case() {
  local name="$1" expected_rc="$2" upstream="$3" china="$4" rc=0
  export MOCK_CASE="$name"
  : > "$MOCK_LOG"
  mkdir -p "$tmp/$name"
  PATH="$tmp/bin:$PATH" bash "$script_dir/cache-preflight.sh" \
    --base-root "$tmp/base" --head-root "$tmp/head" \
    --work-dir "$tmp/$name" --leaf zeroclaw \
    > "$tmp/$name.out" 2> "$tmp/$name.err" || rc=$?
  [[ "$rc" -eq "$expected_rc" ]] || {
    echo "$name: expected rc $expected_rc, got $rc" >&2
    cat "$tmp/$name.err" >&2
    exit 1
  }
  grep -q "upstream=$upstream china=$china" "$tmp/$name.out" || {
    echo "$name: wrong statuses" >&2
    cat "$tmp/$name.out" >&2
    cat "$tmp/$name.err" >&2
    exit 1
  }
}

run_case baseline 0 pass pass
[[ ! -s "$MOCK_LOG" ]]
[[ "$(find "$tmp/baseline" -name '*.plan.json' | wc -l)" -eq 6 ]]
grep -q 'unchanged paths not probed' "$tmp/baseline/summary.md"
run_case newartifact 0 pass pass
[[ "$(grep -c 'https://cache.nixos.org 1' "$MOCK_LOG")" -eq 1 ]]
[[ "$(grep -c 'https://mirrors.ustc.edu.cn/nix-channels/store 1' "$MOCK_LOG")" -eq 1 ]]
[[ "$(grep -c 'curl https:' "$MOCK_LOG")" -eq 1 ]]
[[ "$(wc -l < "$tmp/newartifact/new-fetch-paths.txt")" -eq 1 ]]
run_case newcommunity 0 pass pass
[[ "$(grep -c 'https://cache.nixos.org 1' "$MOCK_LOG")" -eq 1 ]]
[[ "$(wc -l < "$tmp/newcommunity/official-paths.txt")" -eq 0 ]]
[[ "$(grep -c 'https://mirrors.ustc.edu.cn\|curl https:' "$MOCK_LOG" || true)" -eq 0 ]]
run_case recovered 0 pass pass
grep -q 'warning: retrying' "$tmp/recovered/official.err"
run_case newbuild 1 miss pass
grep -q -- '-bad.drv' "$tmp/newbuild/upstream-new.txt"
run_case leafbad 1 miss pass
grep -q -- '-download.drv' "$tmp/leafbad/upstream-new.txt"
if grep -q -- '-glue.drv' "$tmp/leafbad/upstream-new.txt"; then exit 1; fi
run_case nar404 1 pass miss
grep -q -- '-new-official' "$tmp/nar404/china-new.txt"
run_case denied 1 pass inconclusive
[[ "$(grep -c 'curl https:' "$MOCK_LOG")" -eq 1 ]]
[[ "$(wc -l < "$tmp/denied/curl-results.tsv")" -eq 1 ]]
[[ "$(wc -l < "$tmp/denied/ustc-results.tsv")" -eq 1 ]]
grep -q 'remaining URLs skipped' "$tmp/denied/summary.md"
run_case requestfail 1 pass inconclusive
[[ ! -s "$tmp/requestfail/china-new.txt" ]]
run_case incomplete 1 inconclusive inconclusive
run_case emptyplan 1 inconclusive inconclusive
[[ ! -s "$MOCK_LOG" ]]
grep -q 'Nix plan is incomplete or unparseable' "$tmp/emptyplan.err"

printf '@nix {"action":"msg","level":0,"msg":"these 2 paths will be fetched (1 MiB):"}\n@nix {"action":"msg","level":0,"msg":"  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-one"}\n' \
  | jq -R -s -f "$script_dir/nix-plan.jq" | jq -e '.complete == false' > /dev/null
if printf '@nix {bad json}\n' | jq -R -s -f "$script_dir/nix-plan.jq" > /dev/null 2>&1; then
  echo 'malformed Nix JSON was accepted' >&2
  exit 1
fi
printf 'unrecognized Nix diagnostic\n' | jq -R -s -f "$script_dir/nix-plan.jq" \
  | jq -e '.complete == false and .unknown == ["unrecognized Nix diagnostic"]' > /dev/null
{
  printf '@nix {"action":"msg","level":0,"msg":"this derivation will be built:"}\n'
  printf '@nix {"action":"msg","level":0,"msg":"  /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-build.drv"}\n'
  printf 'remote: Counting objects:  50%% (1/2)\rremote: Counting objects: 100%% (2/2), done.\n'
  printf 'Receiving objects: 100%% (2/2), 1.00 MiB | 2.00 MiB/s, done.\n'
  printf 'From https://github.com/anyrun-org/anyrun-interface\n'
  printf ' * [new branch]      main -> main\n'
  printf '@nix {"action":"msg","level":0,"msg":"this path will be fetched (1 MiB):"}\n'
  printf '@nix {"action":"msg","level":0,"msg":"  /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-fetch"}\n'
} | jq -R -s -f "$script_dir/nix-plan.jq" \
  | jq -e '.complete and (.builds | length) == 1 and (.fetches | length) == 1' > /dev/null
for diagnostic in 'unexpected raw line' 'fatal: Git fetch failed' 'remote: error: fetch denied' \
  $'remote: Counting objects: 100% (2/2), done.\rremote: error: fetch denied'; do
  printf '%s\n' "$diagnostic" | jq -R -s -f "$script_dir/nix-plan.jq" \
    | jq -e '.complete == false and (.unknown | length) == 1' > /dev/null
done

# One native handoff: Nix's internal JSON log from a cold local store enters
# the same parser used by the wrapper. No derivation is built.
mkdir -p "$tmp/smoke-store"
# $out is expanded by Nix's builder, not Bash.
# shellcheck disable=SC2016
nix build --dry-run --json --log-format internal-json --no-link \
  --store "local?root=$tmp/smoke-store" --option substituters '' \
  --expr 'derivation { name = "cache-preflight-smoke"; system = "x86_64-linux"; builder = "/bin/sh"; args = [ "-c" "echo smoke > $out" ]; }' \
  > "$tmp/smoke.outputs.json" 2> "$tmp/smoke.nix.log"
jq -e 'type == "array" and length == 1' "$tmp/smoke.outputs.json" > /dev/null
jq -R -s -f "$script_dir/nix-plan.jq" "$tmp/smoke.nix.log" \
  | jq -e '.complete and (.builds | length) == 1 and (.fetches | length) == 0' > /dev/null
echo 'cache-preflight tests passed'
