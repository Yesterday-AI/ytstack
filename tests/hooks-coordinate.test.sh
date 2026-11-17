#!/usr/bin/env bash
# Tests for the operating path of a coordinate session (issue #76, part of #75).
#
#   hooks/pre-tool-use-agent (PreToolUse on Agent, Task, SendMessage)
#     - no coordinate marker -> silent
#     - Agent prompt without "# Brief: " line -> additionalContext warning, never a deny
#     - Agent prompt with a rendered brief -> silent; every Agent call is logged
#     - short SendMessage -> silent; long SendMessage without a brief -> warning
#   hooks/session-start
#     - coordinate marker -> the operating checklist, byte for byte the block of
#       docs/ux/coordinator-format.md; without the marker -> none
#   hooks/stop (coordinate lints)
#     - LANES.md older than the newest dispatch -> systemMessage once per session
#     - STATE pointer behind the newest milestone -> systemMessage
#     - the same finding in 3 sessions in a row -> block once; cleared -> streak 0
#
# Run: /bin/bash tests/hooks-coordinate.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
H="$ROOT/hooks"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3' in: $2";; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'";; *) ok "$1";; esac; }

JQ=""; for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do [ -x "$c" ] && { JQ="$c"; break; }; done
[ -n "$JQ" ] || JQ=$(command -v jq)
[ -n "$JQ" ] || { echo "FATAL: jq needed"; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytcoord.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"
unset CLAUDE_PLUGIN_DATA PLUGIN_DATA 2>/dev/null
SH="$XDG_STATE_HOME/ytstack/sessions"

P="$TMP/p"; mkdir -p "$P/.ytstack"
( cd "$P" || exit 2; git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  printf 'project: p\nlast_updated: %s\ncurrent_milestone: M001\nactive_slice: none\nactive_task: none\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .ytstack/STATE.md
  printf -- '---\nmilestone: M001\n---\n' > .ytstack/M001-ROADMAP.md
  git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }
marker() { mkdir -p "$SH/$1"; printf '%s\n' "$P/.ytstack" > "$SH/$1/coordinate"; }

tool() { # tool <session> <tool name> <text> -> OUT
  OUT=$("$JQ" -n --arg s "$1" --arg t "$2" --arg x "$3" --arg c "$P" \
    '{session_id: $s, cwd: $c, hook_event_name: "PreToolUse", tool_name: $t, tool_input: (if $t == "SendMessage" then {to: "w1", message: $x} elif $t == "Bash" then {command: $x} else {prompt: $x, description: "d", isolation: "worktree"} end)}' \
    | bash "$H/pre-tool-use-agent" 2>&1)
}
stop() { OUT=$("$JQ" -n --arg s "$1" --arg c "$P" '{session_id: $s, cwd: $c, hook_event_name: "Stop"}' | bash "$H/stop" 2>&1); }
ctx() { printf '%s' "$OUT" | "$JQ" -r "$1 // empty" 2>/dev/null; }

echo "# pre-tool-use-agent"
tool a1 Agent "Implement the export."
eq "no marker: silent" "" "$OUT"
marker a1
tool a1 Agent "Implement the export. Change src/a.ts."
has "hand-written Agent prompt: warned" "$(ctx .hookSpecificOutput.additionalContext)" "carries no rendered brief"
has "names ytstack-brief render" "$(ctx .hookSpecificOutput.additionalContext)" "bin/ytstack-brief\" render"
eq "never a permission decision" "" "$(ctx .hookSpecificOutput.permissionDecision)"
tool a1 Agent "# Brief: M001-S01-T01 (p)

## Outcome
x"
eq "rendered brief: silent" "" "$OUT"
tool a1 Agent "Context first.
# Brief: M001-S01-T01 (p)"
eq "brief marker on a later line: silent" "" "$OUT"
eq "every Agent call logged" 3 "$(grep -c . "$SH/a1/dispatches")"
tool a1 SendMessage "Go on."
eq "short SendMessage: silent" "" "$OUT"
LONG=$(awk 'BEGIN { for (i = 0; i < 60; i++) printf "do the thing "; }')
tool a1 SendMessage "$LONG"
has "long SendMessage without a brief: warned" "$(ctx .hookSpecificOutput.additionalContext)" "SendMessage prompt carries no rendered brief"
tool a1 Bash "ls"
eq "another tool: silent" "" "$OUT"
lookup() { OUT=$("$JQ" -n --arg t "$1" --arg c "$P" '{session_id: "a1", cwd: $c, hook_event_name: "PreToolUse", tool_name: "Agent", tool_input: {prompt: "Where is X defined?", subagent_type: $t}}' | bash "$H/pre-tool-use-agent" 2>&1); }
lookup Explore; eq "an Explore lookup: no warning" "" "$OUT"
lookup semble-search; eq "a search agent: no warning" "" "$OUT"
eq "lookups are not counted as dispatches" 3 "$(grep -c . "$SH/a1/dispatches")"
lookup general-purpose; has "a general-purpose agent without a brief: warned" "$(ctx .hookSpecificOutput.additionalContext)" "no rendered brief"
eq "and counted" 4 "$(grep -c . "$SH/a1/dispatches")"
# without jq the hook reads and writes JSON through python3 (Codex finding on PR #87)
OUT=$("$JQ" -n --arg c "$P" '{session_id: "a1", cwd: $c, hook_event_name: "PreToolUse", tool_name: "Agent", tool_input: {prompt: "Implement it.", subagent_type: "general-purpose"}}' | YT_FORCE_NO_JQ=1 bash "$H/pre-tool-use-agent" 2>&1)
has "no jq: still warned, through python3" "$(ctx .hookSpecificOutput.additionalContext)" "no rendered brief"
eq "no jq: still counted" 5 "$(grep -c . "$SH/a1/dispatches")"

echo "# pre-tool-use-agent: isolation, merges and closes by hand (issue #83)"
noiso() { OUT=$("$JQ" -n --arg c "$P" --arg t "$1" '{session_id: "a1", cwd: $c, hook_event_name: "PreToolUse", tool_name: "Agent", tool_input: {prompt: "# Brief: M001-S01 (p)\nx", subagent_type: $t}}' | bash "$H/pre-tool-use-agent" 2>&1); }
noiso general-purpose
has "a rendered brief without isolation: hinted" "$(ctx .hookSpecificOutput.additionalContext)" 'isolation: "worktree"'
case "$(ctx .hookSpecificOutput.additionalContext)" in *"no rendered brief"*) bad "and not called hand-written";; *) ok "and not called hand-written";; esac
eq "never a permission decision" "" "$(ctx .hookSpecificOutput.permissionDecision)"
noiso Explore; eq "a lookup without isolation: silent" "" "$OUT"
OUT=$("$JQ" -n --arg c "$P" '{session_id: "a1", cwd: $c, hook_event_name: "PreToolUse", tool_name: "Agent", tool_input: {prompt: "Implement it.", subagent_type: "general-purpose"}}' | YT_FORCE_NO_JQ=1 bash "$H/pre-tool-use-agent" 2>&1)
has "no jq: the isolation hint too" "$(ctx .hookSpecificOutput.additionalContext)" 'isolation: "worktree"'
N0=$(grep -c . "$SH/a1/dispatches")
tool a1 Bash "gh pr merge 12 --squash"
has "gh pr merge by hand: the finish-lane merge is named" "$(ctx .hookSpecificOutput.additionalContext)" "bin/ytstack-finish-lane\" -C <worktree> merge --pr <N> --at <reviewed head>"
tool a1 Bash "cd /x && rtk gh pr merge 12"
has "behind cd and a wrapper too" "$(ctx .hookSpecificOutput.additionalContext)" "ytstack-finish-lane"
tool a1 Bash "gh pr close 14 --comment 'cap'"
has "gh pr close: a cap waits" "$(ctx .hookSpecificOutput.additionalContext)" "--status parked"
has "and CI reruns" "$(ctx .hookSpecificOutput.additionalContext)" "gh run rerun"
# a command, not text (PR #94 review)
hint() { tool a1 Bash "$1"; case "$OUT" in *finish-lane*) HV=merge ;; *parked*) HV=close ;; '') HV=silent ;; *) HV=other ;; esac
  [ -z "$OUT" ] || printf '%s' "$OUT" | "$JQ" -e . >/dev/null 2>&1 || HV="$HV invalid-json"; eq "$2: $(printf '%s' "$1" | tr '\n' '|')" "$3" "$HV"; }
hint $'cd /x\ngh pr merge 12 --squash' "on the next line" merge
hint 'if gh pr merge 12; then echo ok; fi' "after if" merge
hint 'GH_TOKEN=x gh pr merge 12' "behind an assignment" merge
hint 'gh -R o/r pr merge 12' "with -R before pr" merge
hint 'gh --repo o/r pr close 9' "with --repo before pr" close
hint 'xargs -n1 gh pr close < list' "behind xargs" close
hint 'test -n "$x" || gh pr close 4' "after ||" close
hint 'git commit -m "docs: note; gh pr merge is forbidden"' "inside double quotes" silent
hint "echo 'a; gh pr close 3'" "inside single quotes" silent
hint '# later: ; gh pr merge 5' "in a comment" silent
hint 'ls # gh pr merge 5' "in a trailing comment" silent
tool a1 Bash "gh pr view 12 --json state"; eq "another gh call: silent" "" "$OUT"
tool a1 Bash "echo 'gh pr merge is not run here' > notes.txt"; eq "an echo of the words: silent" "" "$OUT"
eq "Bash calls are no dispatches" "$N0" "$(grep -c . "$SH/a1/dispatches")"
tool nomark Bash "gh pr merge 12"; eq "no marker: silent" "" "$OUT"

echo "# session-start: operating checklist"
WANT=$(awk '/<!-- operating-checklist:end -->/ { f = 0 } f { print } /<!-- operating-checklist:begin -->/ { f = 1 }' "$ROOT/docs/ux/coordinator-format.md")
[ -n "$WANT" ] && ok "the doc has the checklist block" || bad "the doc has the checklist block"
OUT=$("$JQ" -n --arg c "$P" '{session_id: "a1", cwd: $c, source: "compact"}' | CLAUDE_PLUGIN_ROOT="$ROOT" bash "$H/session-start" 2>/dev/null)
C=$(ctx .hookSpecificOutput.additionalContext)
has "coordinate session: the checklist, as in the doc" "$C" "$WANT"
hasnt "coordinate session: no minimal-code line" "$C" "Minimal-code guard is on"
if [ "${#C}" -le 9500 ]; then ok "fits the guard (${#C})"; else bad "fits the guard" "${#C}"; fi
OUT=$("$JQ" -n --arg c "$P" '{session_id: "other", cwd: $c, source: "compact"}' | CLAUDE_PLUGIN_ROOT="$ROOT" bash "$H/session-start" 2>/dev/null)
hasnt "other session: no checklist" "$(ctx .hookSpecificOutput.additionalContext)" "Coordinator operating checklist"
P2=$(grep -c 'operating-checklist:begin' "$ROOT/skills/coordinate/SKILL.md")
eq "the coordinate preamble reads the same block" 1 "$P2"

echo "# stop: coordinate lints"
marker s1
printf '| a |\n' > "$P/.ytstack/LANES.md"; touch -t 202001010000 "$P/.ytstack/LANES.md"
printf '%s\n' "$(date +%s)" > "$SH/s1/dispatches"
stop s1
has "LANES.md behind the dispatches: warned" "$(ctx .systemMessage)" "lanes file last changed"
eq "a first session: no block" "" "$(ctx .decision)"
stop s1
hasnt "said once per session" "$(ctx .systemMessage)" "lanes file last changed"
touch "$P/.ytstack/LANES.md"; stop s1
eq "LANES.md current: silent" "" "$OUT"
# Once the lanes file is out of tree (issue #79) the check reads that one, not the repo copy.
KEY=$(. "$ROOT/hooks/lib/git-ctx.sh"; yt_git_ctx "$P"; printf '%s' "$YT_REPO_KEY")
OOT="$XDG_STATE_HOME/ytstack/repos/$KEY/LANES.md"
mkdir -p "${OOT%/*}"; printf '| a |\n' > "$OOT"; touch -t 202001010000 "$OOT"
marker s1b; printf '%s\n' "$(date +%s)" > "$SH/s1b/dispatches"; stop s1b
has "an old out-of-tree lanes file beside a current repo copy: warned" "$(ctx .systemMessage)" "lanes file last changed"
rm -f "$OOT"
printf -- '---\nmilestone: M003\n---\n' > "$P/.ytstack/M003-ROADMAP.md"
marker s2; stop s2
has "STATE pointer behind: warned" "$(ctx .systemMessage)" "current_milestone M001 is behind the newest milestone on disk (M003)"
eq "session 1 of the state streak: no block" "" "$(ctx .decision)"
marker s3; stop s3; eq "session 2: no block" "" "$(ctx .decision)"
marker s4; stop s4
eq "session 3 in a row: block" block "$(ctx .decision)"
has "the block names the streak" "$(ctx .reason)" "3 sessions in a row"
stop s4; eq "the block comes once per session" "" "$(ctx .decision)"
rm -f "$P/.ytstack/M003-ROADMAP.md"
marker s5; stop s5; eq "cleared: silent" "" "$OUT"
printf -- '---\nmilestone: M003\n---\n' > "$P/.ytstack/M003-ROADMAP.md"
marker s6; stop s6
eq "a clean session broke the row: the next one counts 1" 1 "$(awk -F '\t' '$1 == "state" { print $2 }' "$XDG_STATE_HOME"/ytstack/repos/*/coordinate-lints)"
eq "and does not block" "" "$(ctx .decision)"
rm -f "$P/.ytstack/M003-ROADMAP.md"

echo "# stop: the first stop of a session comes before its first dispatch (a status question)"
rm -rf "$XDG_STATE_HOME/ytstack/repos"
touch -t 202001010000 "$P/.ytstack/LANES.md"
for s in q1 q2 q3; do
  marker "$s"; stop "$s"
  [ "$s" != q1 ] || eq "q1: the first stop, no dispatch yet: silent" "" "$OUT"
  date +%s >> "$SH/$s/dispatches"; stop "$s"
done
eq "the third such session blocks" block "$(ctx .decision)"

echo "# stop: overlapping sessions count once each (A, B, A)"
rm -rf "$XDG_STATE_HOME/ytstack/repos"
for s in ov-a ov-b; do marker "$s"; date +%s > "$SH/$s/dispatches"; done
stop ov-a; stop ov-b; stop ov-a
eq "A, B, A: two sessions, not three" 2 "$(awk -F '\t' '$1 == "lanes" { print $2 }' "$XDG_STATE_HOME"/ytstack/repos/*/coordinate-lints)"
eq "and no block" "" "$(ctx .decision)"

echo "# stop: the streak is kept per repository key from the marker (user scope)"
rm -rf "$XDG_STATE_HOME/ytstack/repos"
mkdir -p "$SH/u1"; printf '%s\nkeyone\n' "$P/.ytstack" > "$SH/u1/coordinate"; date +%s > "$SH/u1/dispatches"; stop u1
mkdir -p "$SH/u2"; printf '%s\nkeytwo\n' "$P/.ytstack" > "$SH/u2/coordinate"; date +%s > "$SH/u2/dispatches"; stop u2
eq "two keys, two counters" "1|1" "$(awk -F '\t' '$1 == "lanes" { print $2 }' "$XDG_STATE_HOME/ytstack/repos/keyone/coordinate-lints" 2>/dev/null)|$(awk -F '\t' '$1 == "lanes" { print $2 }' "$XDG_STATE_HOME/ytstack/repos/keytwo/coordinate-lints" 2>/dev/null)"
eq "nothing written into the project" "?? .ytstack/LANES.md" "$(git -C "$P" status --porcelain)"

echo "# compactions of a coordinator: rotate (issue #83)"
rm -rf "$XDG_STATE_HOME/ytstack/repos"; touch "$P/.ytstack/LANES.md"
compact() { "$JQ" -n --arg s "$1" --arg c "$P" '{session_id: $s, cwd: $c, hook_event_name: "PreCompact", trigger: "auto"}' | bash "$H/pre-compact" >/dev/null 2>&1; }
ss() { OUT=$("$JQ" -n --arg s "$1" --arg c "$P" --arg src "$2" '{session_id: $s, cwd: $c, source: $src}' | CLAUDE_PLUGIN_ROOT="$ROOT" bash "$H/session-start" 2>/dev/null); C=$(ctx .hookSpecificOutput.additionalContext); }
marker r1
compact r1; ss r1 compact
has "first compaction: SessionStart says rotate now" "$C" "Compaction 1 of this coordinator: ytstack:coordinate Step 12, rotate now"
stop r1; case "$(ctx .systemMessage)" in *"Rotate now"*) bad "first compaction: no Stop reminder yet";; *) ok "first compaction: no Stop reminder yet";; esac
compact r1; ss r1 compact
has "second compaction: counted" "$C" "Compaction 2 of this coordinator"
if [ "${#C}" -le 9500 ]; then ok "fits the guard (${#C})"; else bad "fits the guard" "${#C}"; fi
stop r1; has "second compaction: the Stop reminder" "$(ctx .systemMessage)" "compacted 2 times. Rotate now (ytstack:coordinate Step 12)"
stop r1; case "$(ctx .systemMessage)" in *"Rotate now"*) bad "once per compaction";; *) ok "once per compaction";; esac
ss r1 startup; case "$C" in *"Compaction "*) bad "a startup source: no compaction line";; *) ok "a startup source: no compaction line";; esac
compact plain1; ss plain1 compact; case "$C" in *"of this coordinator"*) bad "no marker: no compaction line";; *) ok "no marker: no compaction line";; esac
eq "no marker: nothing counted" no "$([ -e "$SH/plain1/compactions" ] && echo yes || echo no)"
mkdir -p "$TMP/noyt"; "$JQ" -n --arg c "$TMP/noyt" '{session_id: "r1", cwd: $c, hook_event_name: "PreCompact"}' | bash "$H/pre-compact" >/dev/null 2>&1
eq "a compaction in a directory without .ytstack still counts (PR #94 review)" 3 "$(grep -c . "$SH/r1/compactions")"

echo "# post-tool-use-bash: a red default branch read with gh run list (issue #83)"
DEF=$(git -C "$P" symbolic-ref --short HEAD)
runs() { OUT=$("$JQ" -n --arg s "$1" --arg c "$P" --arg cmd "$2" --arg o "$3" '{session_id: $s, cwd: $c, hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $cmd}, tool_response: {stdout: $o, stderr: "", interrupted: false}}' | bash "$H/post-tool-use-bash" 2>&1); }
# gh run list prints the newest run first
RED=$(printf 'completed\tfailure\tfeat: b\tci\t%s\tpush\t102\t3m\t1h\ncompleted\tsuccess\tfix: a\tci\t%s\tpush\t101\t1m\t2h\n' "$DEF" "$DEF")
GREEN=$(printf 'completed\tsuccess\tfix: a\tci\t%s\tpush\t101\t1m\t2h\n' "$DEF")
runs a1 "gh run list --branch $DEF --limit 5" "$RED"
has "a failed run on the default branch: run ytstack:lesson" "$(ctx .hookSpecificOutput.additionalContext)" "ytstack:lesson"
eq "as PostToolUse context" PostToolUse "$(ctx .hookSpecificOutput.hookEventName)"
runs a1 "gh run list --branch $DEF --limit 5" "$RED"; eq "the same failure: said once" "" "$OUT"
runs a1 "gh run list -b $DEF --json conclusion,workflowName" '[{"conclusion":"failure","workflowName":"ci","databaseId":103},{"conclusion":"success","workflowName":"ci"}]'
has "JSON output, -b: said" "$(ctx .hookSpecificOutput.additionalContext)" "ytstack:lesson"
# PR #94 review: only the newest run of each workflow counts; another repository is not this one
runs a1 "gh run list --branch $DEF --limit 10" "$(printf 'completed\tsuccess\tfix: repair\tci\t%s\tpush\t3\t9m\t1h\ncompleted\tfailure\tfeat: broke\tci\t%s\tpush\t2\t9m\t2h\n' "$DEF" "$DEF")"
eq "a failure the newer run of its workflow repaired: silent" "" "$OUT"
runs a1 "gh run list --branch $DEF" "$(printf 'in_progress\t\tfix\tci\t%s\tpush\t4\t1m\t1m\ncompleted\tfailure\tx\tci\t%s\tpush\t5\t1m\t1h\n' "$DEF" "$DEF")"
eq "a running newest run: silent" "" "$OUT"
runs a1 "gh run list --branch $DEF" "$(printf 'completed\tsuccess\ta\tci\t%s\tpush\t6\t1m\t1h\ncompleted\tfailure\tb\tdeploy\t%s\tpush\t7\t1m\t2h\n' "$DEF" "$DEF")"
has "another workflow's newest run failed: said" "$(ctx .hookSpecificOutput.additionalContext)" "ytstack:lesson"
runs a1 "gh run list -R other/repo --branch $DEF" "$(printf 'completed\tfailure\tz\tci\t%s\tpush\t8\t1m\t1h\n' "$DEF")"
eq "--repo of another repository: silent" "" "$OUT"
git -C "$P" remote add origin git@github.com:Acme/P.git
runs a1 "gh run list --repo acme/p --branch $DEF" "$(printf 'completed\tfailure\tz\tci\t%s\tpush\t9\t1m\t1h\n' "$DEF")"
has "--repo naming origin: said" "$(ctx .hookSpecificOutput.additionalContext)" "ytstack:lesson"
git -C "$P" remote remove origin
runs a1 "gh run list --json conclusion,workflowName --branch $DEF" '[{"conclusion":"success","workflowName":"ci"},{"conclusion":"failure","workflowName":"ci"}]'
eq "JSON: a failure behind a newer success of its workflow: silent" "" "$OUT"
runs a1 "gh run list --branch $DEF" "$GREEN"; eq "all green: silent" "" "$OUT"
runs a1 "gh run list --branch feature-x" "$(printf 'completed\tfailure\tx\tci\tfeature-x\tpush\t104\t1m\t1h\n')"; eq "another branch: silent" "" "$OUT"
runs a1 "gh run list" "$(printf 'completed\tfailure\tx\tci\t%s\tpush\t105\t1m\t1h\n' "$DEF")"; eq "no --branch: silent" "" "$OUT"
runs nomark "gh run list --branch $DEF" "$RED"; eq "no marker: silent" "" "$OUT"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
