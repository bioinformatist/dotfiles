#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(realpath "$script_dir/../..")"
mode="${1:-ci}"
if [[ $# -gt 1 || ( "$mode" != ci && "$mode" != --local-maint ) ]]; then
  echo 'usage: test-cache-preflight.sh [--local-maint]' >&2
  exit 2
fi
tmp="$(mktemp -d)"
trap 'find -P "$tmp" -type d -exec chmod u+w {} +; rm -rf "$tmp"' EXIT
export TEST_ROOT="$tmp" MOCK_LOG="$tmp/mock.log"
mkdir -p "$tmp/bin" "$tmp/repo"
root=/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-system.drv
out=/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-system
glue=/nix/store/cccccccccccccccccccccccccccccccc-hm_test.drv
compile=/nix/store/dddddddddddddddddddddddddddddddd-codex-0.163.0.drv
fetch=/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-dependency
jq -s '.[0] as $b | .[1] as $w | $b + $w |
  .allowedLocalBuildMarkers = ($b.allowedLocalBuildMarkers + $w.allowedLocalBuildMarkers) |
  .allowedDirectFetchMarkers = ($b.allowedDirectFetchMarkers + $w.allowedDirectFetchMarkers)' \
  "$script_dir/policy.json" "$script_dir/policy-workstation.json" > "$tmp/policy.json"
cp "$script_dir/policy.json" "$tmp/base-policy.json"
jq -n --arg root "$root" --arg out "$out" \
  '[{drvPath: $root, outputs: {out: $out}}]' > "$tmp/outputs.json"

message() { jq -cn --arg msg "$1" '{action:"msg",level:0,msg:$msg}' | sed 's/^/@nix /'; }
for name in success blocked incomplete trust; do
  {
    message 'this derivation will be built:'
    if [[ "$name" == blocked || "$name" == trust ]]; then message "  $compile"
    else message "  $glue"; fi
    message 'this path will be fetched (1 MiB):'
    if [[ "$name" != incomplete ]]; then message "  $fetch"; fi
    if [[ "$name" == trust ]]; then
      echo '@nix {"action":"msg","level":1,"msg":"warning: ignoring untrusted substituter; you are not a trusted user"}'
    fi
  } > "$tmp/$name.log"
done
: > "$tmp/empty.log"

cat > "$tmp/bin/nix" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
jq -cn --args '$ARGS.positional' -- nix "$@" >> "$MOCK_LOG"
args=" $* "
case "$1" in
  eval)
    if [[ "$args" == *'#lib.maintenancePolicyBase'* ]]; then cat "$TEST_ROOT/base-policy.json"
    elif [[ "$args" == *'#lib.maintenancePolicy'* ]]; then cat "$TEST_ROOT/policy.json"
    elif [[ "$args" == *' --raw '* ]]; then
      echo /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-system.drv
    else
      if [[ "$MOCK_CASE" == eval-error ]]; then echo 'evaluation failed' >&2; exit 6; fi
      target=homePC
      [[ "$args" != *linglong* ]] || target=linglong
      [[ "$args" != *ci@headless* ]] || target='ci@headless'
      extra='["file:///headless?priority=60", "file:///desktop?priority=60"]'
      key=target-key
      drv=/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-system.drv
      if [[ "$target" == linglong ]]; then
        drv=/nix/store/ffffffffffffffffffffffffffffffff-system.drv
        [[ "$MOCK_CASE" != split ]] || key=other-key
      elif [[ "$target" == 'ci@headless' ]]; then
        drv=/nix/store/gggggggggggggggggggggggggggggggg-home.drv
        if [[ "$MOCK_CASE" != same-caches ]]; then extra='["file:///headless?priority=60"]'; fi
      fi
      jq -n --arg drv "$drv" --arg key "$key" --argjson extra "$extra" \
        '{drvPath:$drv,settings:{substituters:["file:///official?priority=40","file:///ustc?priority=10"],
          "extra-substituters":$extra,"trusted-public-keys":[$key],"extra-trusted-public-keys":["extra-key"]}}'
    fi
    ;;
  build)
    [[ "$args" == *' --option fallback false '* && "$args" == *' --no-write-lock-file '* ]] || exit 3
    if [[ "$args" != *' --dry-run '* ]]; then
      echo "$TEST_ROOT/system"
      exit 0
    fi
    roots=()
    for arg in "$@"; do
      case "$arg" in
        *'#nixosConfigurations.homePC.config.system.build.toplevel') roots+=(/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-system.drv) ;;
        *'#nixosConfigurations.linglong.config.system.build.toplevel') roots+=(/nix/store/ffffffffffffffffffffffffffffffff-system.drv) ;;
        *'#homeConfigurations."ci@headless".config.activationPackage') roots+=(/nix/store/gggggggggggggggggggggggggggggggg-home.drv) ;;
      esac
    done
    jq -n --args '$ARGS.positional | map({drvPath:.,outputs:{out:"/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-system"}})' "${roots[@]}" > "$TEST_ROOT/current-outputs.json"
    if [[ "$MOCK_CASE" == missing-root && ${#roots[@]} -gt 1 ]]; then
      jq '.[0:1]' "$TEST_ROOT/current-outputs.json"
    else cat "$TEST_ROOT/current-outputs.json"; fi
    case "$MOCK_CASE" in
      dry-error) echo 'terminal query failure' >&2; exit 7 ;;
      empty) cat "$TEST_ROOT/empty.log" >&2 ;;
      blocked|incomplete|trust) cat "$TEST_ROOT/$MOCK_CASE.log" >&2 ;;
      *) cat "$TEST_ROOT/success.log" >&2 ;;
    esac
    ;;
  *) echo "unexpected nix command: $*" >&2; exit 2 ;;
esac
MOCK
chmod +x "$tmp/bin/nix"

# C: local-only wiring through the real Nu entry point; no actual build or sudo.
if [[ "$mode" == --local-maint ]]; then
  mkdir -p "$tmp/config/dotfiles"
  cp "$script_dir/nix-plan.jq" "$script_dir/classify-plan.jq" "$tmp/config/dotfiles/"
  jq -n --arg repo "$tmp/repo" '{repo:$repo,host:"homePC",parallel:{maxJobs:4,cores:2},extraRiskMarkers:["codex"]}' \
    > "$tmp/config/dotfiles/maint.nuon"
  for cmd in sudo git readlink; do
    cat > "$tmp/bin/$cmd" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
cmd="${0##*/}"
jq -cn --args '$ARGS.positional' -- "$cmd" "$@" >> "$MOCK_LOG"
case "$cmd" in
  git) [[ "$*" != *rev-parse* ]] || echo baseline ;;
  readlink) echo "$TEST_ROOT/kernel" ;;
  sudo) ;;
esac
MOCK
    chmod +x "$tmp/bin/$cmd"
  done
  printf 'source "%s"\nmaint-switch --no-pull --boot\n' "$repo_root/home/shell/nushell/maint.nu" > "$tmp/run.nu"
  for name in success blocked incomplete empty dry-error trust missing-helper; do
    export MOCK_CASE="$name"
    : > "$MOCK_LOG"
    if [[ "$name" == missing-helper ]]; then rm "$tmp/config/dotfiles/classify-plan.jq"; fi
    rc=0
    XDG_CONFIG_HOME="$tmp/config" PATH="$tmp/bin:$PATH" nu --no-config-file "$tmp/run.nu" \
      > "$tmp/$name.out" 2> "$tmp/$name.err" || rc=$?
    if [[ "$name" == success || "$name" == empty ]]; then
      if [[ "$rc" -ne 0 ]]; then cat "$tmp/$name.err" >&2; exit 1; fi
      jq -s -e --arg target "$tmp/system" '
        [ .[] | if .[0] == "sudo" then "sudo"
          elif .[0] == "nix" and .[1] == "build" and (index("--dry-run") | not) then "build" else empty end ] == ["build","sudo"] and
        any(.[]; . == ["sudo","nixos-rebuild","--no-reexec","boot","--store-path",$target])' "$MOCK_LOG" > /dev/null
    else
      [[ "$rc" -ne 0 ]] || { echo "$name: Nu gate unexpectedly passed" >&2; exit 1; }
      jq -s -e 'all(.[]; .[0] != "sudo" and
        (.[0] != "nix" or .[1] != "build" or index("--dry-run") != null))' "$MOCK_LOG" > /dev/null
    fi
    jq -s -e 'all(.[] | select(.[0] == "nix" and .[1] == "build");
      index("--no-write-lock-file") != null and
      .[index("fallback") + 1] == "false")' "$MOCK_LOG" > /dev/null
    case "$name" in
      blocked) grep -q 'Current daemon plan needs unapproved local builds' "$tmp/$name.err" ;;
      incomplete) grep -q 'Nix roots or plan are incomplete' "$tmp/$name.err" ;;
      trust) grep -q 'Cache trust boundary (#205): CI uses the target' "$tmp/$name.out" ;;
      missing-helper) grep -q 'Maintenance helpers not ready' "$tmp/$name.err" ;;
    esac
    echo "local-maint $name passed"
  done
  echo 'local-maint tests passed'
  exit 0
fi

# A: the shared classifier and parser, then only wrapper grouping/coverage.
jq -n --slurpfile policy "$tmp/policy.json" --arg glue "$glue" --arg compile "$compile" '
  {leaf:"",policy:($policy[0] | .allowedLocalBuildMarkers += [""] |
      .allowedDirectFetchMarkers += [""] |
      .leafDirectFetchMarkers.chatgpt = ["-chatgpt_26.1023.51421_amd64.deb.drv","-leaf-only.drv"]),
    plan:{complete:true,fetches:[],builds:[
      $glue, $compile,
      "/nix/store/6y7q9myfvi9nm7phb609yxkq0xkm88ch-chatgpt-26.1023.51421.drv",
      "/nix/store/sqd1rnabr4hf9zsa1q1dwx3zk54m8mmb-chatgpt-unwrapped-26.1023.51421.drv",
      "/nix/store/sgbk0kpc9in2c9bfbv43d7d4k8rp64xw-chatgpt_26.1023.51421_amd64.deb.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-chatgpt-26.1023.51421.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-chatgpt_26.1023.51421_amd64.deb.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-formatelf-0.2.2.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-power-profiles-daemon-linglong-0.30.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-power-profiles-daemon-linglong-0.30-build-python.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-helix-25.07.1.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-leaf-only.drv",
      "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-codex-x86_64-unknown-linux-musl.tar.gz.drv"
    ]}}' > "$tmp/mixed.json"
jq -f "$script_dir/classify-plan.jq" "$tmp/mixed.json" | jq -e '
  (.allowedLocal | length) == 5 and (.direct | length) == 2 and (.blocked | length) == 6 and
  all(.allowedLocal[]; contains("-codex-0.") | not)' > /dev/null
jq '.leaf = "chatgpt"' "$tmp/mixed.json" | jq -f "$script_dir/classify-plan.jq" | jq -e '
  (.direct | length) == 1 and (.direct[0] | contains("sgbk0kpc")) and (.blocked | length) == 7' > /dev/null
jq '.leaf = "unknown-leaf"' "$tmp/mixed.json" | jq -f "$script_dir/classify-plan.jq" | jq -e '.direct == []' > /dev/null
for invalid in 'del(.policy.allowedLocalBuildMarkers)' '.policy.leafDirectFetchMarkers.bad = [1]'; do
  if jq "$invalid" "$tmp/mixed.json" | jq -f "$script_dir/classify-plan.jq" > /dev/null 2>&1; then
    echo 'invalid policy was accepted' >&2; exit 1
  fi
done

parse() {
  jq -R -s --argjson expected "[\"$root\"]" --argjson outputs "$(cat "$tmp/outputs.json")" \
    -f "$script_dir/nix-plan.jq" "$1"
}
parse "$tmp/incomplete.log" | jq -e '.complete == false' > /dev/null
printf '@nix {bad json}\n' > "$tmp/invalid.log"
if parse "$tmp/invalid.log" > /dev/null 2>&1; then echo 'invalid JSON was accepted' >&2; exit 1; fi
for diagnostic in 'unrecognized Nix diagnostic' 'fatal: Git fetch failed' 'remote: error: fetch denied' \
  $'remote: Counting objects: 100% (2/2), done.\rremote: error: fetch denied' \
  '@nix {"action":"msg","level":0,"msg":"error: final cache query failed"}' \
  '@nix {"action":"unsupported"}'; do
  printf '%s\n' "$diagnostic" > "$tmp/diagnostic.log"
  parse "$tmp/diagnostic.log" | jq -e '.complete == false and (.unknown | length) == 1' > /dev/null
done
{
  cat "$tmp/success.log"
  echo '@nix {"action":"msg","level":1,"msg":"warning: retrying after a transient cache error"}'
  printf 'remote: Counting objects:  50%% (1/2)\rremote: Counting objects: 100%% (2/2), done.\n'
  printf 'Receiving objects: 100%% (2/2), 1.00 MiB | 2.00 MiB/s, done.\n'
  printf 'From https://github.com/anyrun-org/anyrun-interface\n * [new branch]      main -> main\n'
} > "$tmp/recovered.log"
parse "$tmp/recovered.log" | jq -e '.complete and (.builds | length) == 1 and (.fetches | length) == 1' > /dev/null

run_wrapper() {
  local name="$1" expected="$2" rc=0
  export MOCK_CASE="$name"
  : > "$MOCK_LOG"
  PATH="$tmp/bin:$PATH" bash "$script_dir/cache-preflight.sh" --flake-root "$tmp/repo" \
    --work-dir "$tmp/wrapper-$name" --leaf example-leaf > "$tmp/wrapper-$name.out" 2> "$tmp/wrapper-$name.err" || rc=$?
  if [[ "$expected" == pass ]]; then [[ "$rc" -eq 0 ]]; else [[ "$rc" -ne 0 ]]; fi
  jq -e --arg expected "$expected" '.status == $expected' "$tmp/wrapper-$name/result.json" > /dev/null
}
run_wrapper success pass
jq -e '[.[] | .targets[].target] | sort == ["ci@headless","homePC","linglong"]' "$tmp/wrapper-success/groups.json" > /dev/null
jq -e 'length == 2 and any(.[]; (.targets | length) == 2) and
  all(.[] | select(any(.targets[]; .target == "ci@headless"));
    all(.caches.substituters[]; contains("desktop") | not))' "$tmp/wrapper-success/groups.json" > /dev/null
jq -s -e '[.[] | select(.[1] == "build")] as $b | ($b | length) == 2 and
  ([$b[] | .[index("--store") + 1]] | unique | length) == 1 and
  all($b[]; index("--json") != null and .[index("extra-substituters") + 1] == "" and
    .[index("extra-trusted-public-keys") + 1] == "" and .[index("trusted-public-keys") + 1] == "extra-key target-key")' "$MOCK_LOG" > /dev/null
run_wrapper split pass
jq -e 'length == 3' "$tmp/wrapper-split/groups.json" > /dev/null
run_wrapper same-caches pass
jq -e 'length == 2' "$tmp/wrapper-same-caches/groups.json" > /dev/null
for name in empty missing-root dry-error eval-error; do run_wrapper "$name" inconclusive; done
grep -q 'terminal query failure' "$tmp/wrapper-dry-error/"*.nix.log
echo 'shared logic and wrapper tests passed'

# B: native small text objects, independent stores/caches per case, default TTLs.
nix-store --generate-binary-cache-key cache-preflight-test "$tmp/test.sec" "$tmp/test.pub"
for scenario in first second third missing-reference; do
  dir="$tmp/native-$scenario"
  mkdir -p "$dir/source" "$dir/target"
  source_store="local?root=$dir/source"
  nix eval --json --store "$source_store" --argstr scenario "$scenario" \
    --expr '{scenario}: let dep = builtins.toFile "cache-preflight-${scenario}-dep" scenario; in { inherit dep; root = builtins.toFile "cache-preflight-${scenario}-root" dep; }' > "$dir/objects.json"
  object="$(jq -r '.root' "$dir/objects.json")"
  dependency="$(jq -r '.dep' "$dir/objects.json")"
  for priority in 10 40 60; do
    cache="file://$dir/cache-$priority?priority=$priority"
    nix store info --store "$cache" > /dev/null
    if [[ "$scenario" == first || ( "$scenario" == second && "$priority" != 10 ) ||
      ( "$scenario" == third && "$priority" == 60 ) ||
      ( "$scenario" == missing-reference && "$priority" == 10 ) ]]; then
      nix copy --from "$source_store" --to "$cache" --option secret-key-files "$tmp/test.sec" "$object"
    fi
  done
  if [[ "$scenario" == missing-reference ]]; then
    hash="${dependency##*/}"; hash="${hash:0:32}"
    rm "$dir/cache-10/$hash.narinfo"
  fi
  rc=0
  nix build --dry-run --json --log-format internal-json --debug --no-link \
    --store "local?root=$dir/target" --option fallback false --option require-sigs true \
    --option substituters "file://$dir/cache-60?priority=60 file://$dir/cache-40?priority=40 file://$dir/cache-10?priority=10" \
    --option extra-substituters '' --option trusted-public-keys "$(cat "$tmp/test.pub")" \
    --option extra-trusted-public-keys '' "$object" > "$dir/outputs.json" 2> "$dir/nix.log" || rc=$?
  expected='[10]'
  [[ "$scenario" != second ]] || expected='[10,40]'
  [[ "$scenario" != third ]] || expected='[10,40,60]'
  jq -e -R -s --arg object "$object" --argjson expected "$expected" '
    [split("\n")[] | select(startswith("@nix ")) | .[5:] | fromjson |
      select(.action == "msg" and (.msg | startswith("checking substituter ")) and
        (.msg | endswith("for path '\''" + $object + "'\''"))) |
      .msg | capture("cache-(?<priority>[0-9]+)").priority | tonumber] == $expected' "$dir/nix.log" > /dev/null
  if [[ "$scenario" == missing-reference ]]; then
    if [[ "$rc" -eq 0 ]]; then
      jq -R -s --argjson expected "[\"$object\"]" --argjson outputs "$(cat "$dir/outputs.json")" \
        -f "$script_dir/nix-plan.jq" "$dir/nix.log" | jq -e '.complete == false' > /dev/null
    fi
    grep -Fq "$dependency" "$dir/nix.log"
  else
    [[ "$rc" -eq 0 ]]
    jq -R -s --argjson expected "[\"$object\"]" --argjson outputs "$(cat "$dir/outputs.json")" \
      -f "$script_dir/nix-plan.jq" "$dir/nix.log" | jq -e --arg object "$object" --arg dep "$dependency" \
        '.complete and .builds == [] and (.fetches | sort) == ([$object,$dep] | sort)' > /dev/null
  fi
  echo "native $scenario passed"
done
echo 'cache-preflight tests passed'
