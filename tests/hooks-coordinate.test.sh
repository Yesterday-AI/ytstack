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
    '{session_id: $s, cwd: $c, hook_event_name: "PreToolUse", tool_name: $t, tool_input: (if $t == "SendMessage" then {to: "w1", message: $x} else {prompt: $x, description: "d"} end)}' \
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
has "LANES.md behind the dispatches: warned" "$(ctx .systemMessage)" "LANES.md last changed"
eq "a first session: no block" "" "$(ctx .decision)"
stop s1
hasnt "said once per session" "$(ctx .systemMessage)" "LANES.md last changed"
touch "$P/.ytstack/LANES.md"; stop s1
eq "LANES.md current: silent" "" "$OUT"
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
eq "nothing written into the project" "?? .ytstack/LANES.md" "$(git -C "$P" status --porcelain)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
