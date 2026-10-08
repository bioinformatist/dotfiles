# Nix 2.34.7: --json describes requested outputs; internal-json stderr carries
# the complete dry-run build/fetch plan as level-0 messages.
def store_path: test("^/nix/store/[0-9a-z]{32}-[^[:space:]]+$");
def count($message; $singular; $plural):
  if ($message | test($singular)) then 1
  elif ($message | test($plural)) then
    ($message | capture($plural).n | tonumber)
  else null end;
def git_line:
  test("^remote: (Enumerating objects: [0-9]+, done\\.|(Counting|Compressing) objects: *[0-9]+% \\([0-9]+/[0-9]+\\)(, done\\.)?|Total [0-9]+ \\(delta [0-9]+\\), reused [0-9]+ \\(delta [0-9]+\\), pack-reused [0-9]+ \\(from [0-9]+\\)) *$") or
  test("^(Receiving objects|Resolving deltas): *[0-9]+% \\([0-9]+/[0-9]+\\)(, [0-9.]+ [A-Za-z]+ \\| [0-9.]+ [A-Za-z]+/s)?(, done\\.)? *$") or
  test("^From https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$") or
  test("^ \\* \\[new (branch|ref|tag)\\] +[^[:space:]]+ +-> +[^[:space:]]+$");
def git_progress: split("\r") | all(.[]; git_line);

[split("\n")[] | select(length > 0) |
  if startswith("@nix ") then .[5:] | fromjson
  else {action: "raw", msg: .} end] |
reduce .[] as $event (
  {section: null, remaining: 0, builds: [], fetches: [], unknown: []};
  if $event.action == "raw" then
    if ($event.msg | git_progress) then . else .unknown += [$event.msg] end
  elif $event.action != "msg" or $event.level != 0 then .
  else
    ($event.msg | if type == "string" then . else error("non-string Nix message") end) as $message |
    if .remaining > 0 then
      if ($message | startswith("  /nix/store/") and (.[2:] | store_path)) then
        .remaining -= 1 |
        if .section == "builds" then .builds += [$message[2:]]
        else .fetches += [$message[2:]] end
      else .unknown += [$message] end
    else
      (count($message; "^this derivation will be built:$";
        "^these (?<n>[0-9]+) derivations will be built:$")) as $build_count |
      (count($message; "^this path will be fetched \\([^)]*\\):$";
        "^these (?<n>[0-9]+) paths will be fetched \\([^)]*\\):$")) as $fetch_count |
      if $build_count != null then
        .section = "builds" | .remaining = $build_count
      elif $fetch_count != null then
        .section = "fetches" | .remaining = $fetch_count
      else .unknown += [$message] end
    end
  end
) |
.complete = (.remaining == 0 and (.unknown | length) == 0) |
del(.section, .remaining)
