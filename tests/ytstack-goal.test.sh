#!/usr/bin/env bash
# Tests for bin/ytstack-goal and the goal part of hooks/stop (issue #99).
#
# Contract:
#   set      writes <session home>/<id>/goal (out of tree); no session id:
#            exit 3 (on Codex: use /goal); a milestone needs its roadmap; a
#            sentence needs a --check or --file; --if-unset keeps a goal
#   hook     block while the goal is open, naming the open slices and the
#            exit criteria; pass for a blocker, an asked question, a running
#            lane; with --active true only after a tool call in the
#            transcript since the last block, never without a transcript;
#            the bound (--rounds, --until) and a reached goal are said once
#   status   runs the --check commands, records them for the hook; exit 0
#            reached, 1 open, 3 no goal
#   clear    removes the goal
#   stop     hooks/stop turns the decision into decision: block or a
#            systemMessage; stop_hook_active without a transcript passes
#
# Run: /bin/bash tests/ytstack-goal.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-goal"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

[ -x "$BIN" ] || { bad "bin/ytstack-goal exists and is executable"; echo "$PASS passed, $FAIL failed"; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytgoal.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/xdg" CLAUDE_PLUGIN_DATA="$TMP/data" HOME="$TMP/home"
unset CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID
mkdir -p "$HOME"
SH="$XDG_STATE_HOME/ytstack/sessions"

R="$TMP/repo"; Y="$R/.ytstack"; mkdir -p "$Y"
( cd "$R" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
printf -- '---\ncurrent_milestone: M004\nactive_slice: none\nactive_task: none\n---\n' > "$Y/STATE.md"
road() { { printf -- '---\nmilestone: M004\nstatus: %s\n---\n\n## Slices\n\n' "$1"; shift; printf '%s\n' "$@"; } > "$Y/M004-ROADMAP.md"; }
road in-progress "- [x] S01 -- one" "- [ ] S02 -- two" "- [ ] S03 -- three"
printf -- '---\nmilestone: M004\n---\n\n## Exit criteria\n\n- The export runs in CI.\n- Docs name the flag.\n\n## Size\n\nM\n' > "$Y/M004-CONTEXT.md"

g() { OUT=$(cd "$R" && bash "$BIN" "$@" 2>&1); EC=$?; }
hook() { OUT=$(bash "$BIN" --session s1 hook "$@" 2>&1); EC=$?; }

echo "# set"
g set M004
eq "no session id: exit 3" 3 "$EC"
has "and says why" "no session id" "$OUT"
OUT=$(cd "$R" && CODEX_THREAD_ID=t1 bash "$BIN" set M004 2>&1); EC=$?
has "on Codex: the host's own /goal" "Codex has its own /goal" "$OUT"
g --session s1 set M009
eq "a milestone without a roadmap: exit 1" 1 "$EC"
g --session s1 set "ship the export"
eq "a sentence without a criterion: exit 64" 64 "$EC"
g --session s1 set none
eq "no current milestone: exit 1" 1 "$EC"
OUT=$(cd "$R" && CLAUDE_CODE_SESSION_ID=s1 bash "$BIN" set M004 --rounds 3 2>&1); EC=$?
eq "set from CLAUDE_CODE_SESSION_ID: exit 0" 0 "$EC"
has "says what it set" "M004 set as the goal of this session" "$OUT"
[ -f "$SH/s1/goal" ] && ok "the marker lives in the session home, out of tree" || bad "the marker lives in the session home, out of tree"
eq "nothing in the repository" "" "$(find "$R" -name 'goal*')"
g --session s1 set M004 --if-unset
has "--if-unset keeps the goal" "M004 is the goal already" "$OUT"

echo "# hook"
hook
case "$OUT" in block*) ok "an open milestone holds the stop" ;; *) bad "an open milestone holds the stop" "$OUT" ;; esac
has "with the open slices" "M004: open slices S02, S03" "$OUT"
has "and the exit criteria" "exit criterion: The export runs in CI." "$OUT"
has "with the round" "(round 1 of 3)" "$OUT"
has "and the ways out" 'ytstack-goal block "<why>"' "$OUT"
hook --active true
eq "a continued turn without a transcript: pass" pass "$OUT"
TP="$TMP/transcript.jsonl"
printf '{"type":"user","message":{"content":"go"}}\n' > "$TP"
hook --active false --transcript "$TP"
case "$OUT" in block*) ok "round 2 blocks after a human prompt" ;; *) bad "round 2 blocks after a human prompt" "$OUT" ;; esac
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"done"}]}}\n' >> "$TP"
hook --active true --transcript "$TP"
eq "no tool call since the last block: pass (no loop)" pass "$OUT"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t","name":"Bash","input":{}}]}}\n' >> "$TP"
hook --active true --transcript "$TP"
case "$OUT" in block*) ok "a tool call since the last block: blocks again" ;; *) bad "a tool call since the last block: blocks again" "$OUT" ;; esac
hook --active true --transcript "$TP"
case "$OUT" in say*"reached its bound (3 rounds)"*) ok "three rounds used: the bound is said" ;; *) bad "three rounds used: the bound is said" "$OUT" ;; esac
hook
eq "and only once" pass "$OUT"

echo "# let through"
g --session s1 set M004
hook; case "$OUT" in block*) ok "a new set starts the rounds again" ;; *) bad "a new set starts the rounds again" "$OUT" ;; esac
g --session s1 block "waiting for the vendor's API key"
has "block records a blocker" "blocker recorded" "$OUT"
hook; eq "a recorded blocker: pass" pass "$OUT"
g --session s1 status
has "status names the blocker" "blocker: waiting for the vendor's API key" "$OUT"
eq "status of an open goal: exit 1" 1 "$EC"
g --session s1 block --clear
mkdir -p "$Y/questions"
printf -- '---\nid: Q001\nstate: asked\n---\n# Q001\n' > "$Y/questions/Q001-x.md"
hook; eq "an asked question: pass" pass "$OUT"
printf -- '---\nid: Q001\nstate: open\n---\n# Q001\n' > "$Y/questions/Q001-x.md"
hook; case "$OUT" in block*) ok "an open question that was not asked does not let it through" ;; *) bad "an open question that was not asked does not let it through" "$OUT" ;; esac
LF=$(bash "$ROOT/bin/ytstack-frontier" -C "$R" where 2>/dev/null | cut -f1)
bash "$ROOT/bin/ytstack-frontier" -C "$R" claim M004-S02 --by w1 >/dev/null 2>&1
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S02 --status running >/dev/null 2>&1
hook; eq "a running lane in the background: pass" pass "$OUT"
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S02 --worktree "$TMP/gone-wt" >/dev/null 2>&1
hook; case "$OUT" in block*) ok "a running lane whose worktree is gone (stale) is no background work" ;; *) bad "a running lane whose worktree is gone (stale) is no background work" "$OUT" ;; esac
# every open slice waits for a person: said once, then the stop goes through
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S02 --status ready >/dev/null 2>&1
bash "$ROOT/bin/ytstack-frontier" -C "$R" claim M004-S03 --by w2 >/dev/null 2>&1
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S03 --status parked >/dev/null 2>&1
hook
case "$OUT" in say*"waits for a person: S02 (ready), S03 (parked)"*) ok "every open slice waits for a person: said" ;; *) bad "every open slice waits for a person: said" "$OUT" ;; esac
hook; eq "and then passed silently" pass "$OUT"
printf 'merge_by: coordinator\n' > "$Y/PREFERENCES.md"
hook; case "$OUT" in block*) ok "merge_by coordinator: a ready lane is the coordinator's to merge" ;; *) bad "merge_by coordinator: a ready lane is the coordinator's to merge" "$OUT" ;; esac
rm -f "$Y/PREFERENCES.md"
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S03 --status running >/dev/null 2>&1
# a call of ytstack-goal is no tool call that re-arms the goal
TP2="$TMP/t2.jsonl"; : > "$TP2"
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S03 --status blocked >/dev/null 2>&1
hook --transcript "$TP2"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"g","name":"Bash","input":{"command":"ytstack-goal status"}}]}}\n' >> "$TP2"
hook --active true --transcript "$TP2"
eq "only ytstack-goal was called since the block: pass" pass "$OUT"
# a block of another part of the stop hook counts as the last block too
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b","name":"Bash","input":{"command":"ls"}}]}}\n' >> "$TP2"
wc -c < "$TP2" | tr -d ' ' > "$SH/s1/stop-block-offset"
hook --active true --transcript "$TP2"
eq "no tool call after a standing or lint block: pass" pass "$OUT"
rm -f "$SH/s1/stop-block-offset"
bash "$ROOT/bin/ytstack-frontier" -C "$R" set M004-S02 --status merged >/dev/null 2>&1
hook; has "a merged lane counts as done" "open slices S03" "$OUT"
road in-progress "- [x] S01 -- one" "- [ ] S02 -- two" "- [x] S03 -- three"
hook
case "$OUT" in say*"holds"*) ok "every slice done: the goal holds, said once" ;; *) bad "every slice done: the goal holds, said once" "$OUT" ;; esac
hook; eq "then pass" pass "$OUT"
g --session s1 status
eq "status of a reached goal: exit 0" 0 "$EC"
g --session s1 set M004 --if-unset
has "--if-unset replaces a reached goal" "M004 set as the goal of this session" "$OUT"
rm -f "$LF"

echo "# sentence goals and status"
g --session s2 set "the export ships" --check "test -f done.txt" --file docs/flag.md --until 2099-01-01T00:00Z
eq "a sentence goal with criteria: exit 0" 0 "$EC"
OUT=$(bash "$BIN" --session s2 hook 2>&1)
has "a check that never ran is open" "check not run yet: test -f done.txt" "$OUT"
has "a missing file is open" "file missing: $R/docs/flag.md" "$OUT"
g --session s2 status
eq "status: exit 1" 1 "$EC"
has "status ran the check" "check failed (exit 1 at " "$OUT"
touch "$R/done.txt"; mkdir -p "$R/docs"; touch "$R/docs/flag.md"
OUT=$(bash "$BIN" --session s2 hook 2>&1)
case "$OUT" in block*"check failed"*) ok "the hook reads the recorded result, it runs nothing" ;; *) bad "the hook reads the recorded result, it runs nothing" "$OUT" ;; esac
g --session s2 status
eq "after the fix status: exit 0" 0 "$EC"
has "and says so" "reached" "$OUT"
g --session s3 set "late" --file nothing.txt --until 2000-01-01T00:00Z
OUT=$(bash "$BIN" --session s3 hook 2>&1)
case "$OUT" in say*"reached its bound (until 2000-01-01T00:00:00Z)"*) ok "an --until in the past: bound said" ;; *) bad "an --until in the past: bound said" "$OUT" ;; esac
g --session s2 clear
[ ! -f "$SH/s2/goal" ] && ok "clear removes the goal" || bad "clear removes the goal"
g --session s2 status
eq "status without a goal: exit 3" 3 "$EC"
OUT=$(bash "$BIN" --session nobody hook 2>&1)
eq "hook without a goal: pass" pass "$OUT"

echo "# hooks/stop"
# a real jq binary: a version-manager shim may not work under the test's HOME
JQ=$(. "$ROOT/hooks/lib/git-ctx.sh"; yt_jq)
if [ -z "$JQ" ]; then ok "jq missing: stop cases skipped"; else
  g --session s4 set M004
  road in-progress "- [ ] S01 -- one"
  stop() { OUT=$("$JQ" -n --arg s "$1" --arg c "$R" --argjson a "$2" --arg t "${3:-}" '{session_id: $s, cwd: $c, hook_event_name: "Stop", stop_hook_active: $a} + (if $t != "" then {transcript_path: $t} else {} end)' | bash "$ROOT/hooks/stop" 2>/dev/null); }
  stop s4 false
  eq "an open goal: decision block" block "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty')"
  has "the reason names the open slice" "M004: open slices S01" "$(printf '%s' "$OUT" | "$JQ" -r '.reason // empty')"
  stop s4 true
  eq "stop_hook_active without a transcript: no block" "" "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty')"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t"}]}}\n' > "$TMP/t4.jsonl"
  stop s4 true "$TMP/t4.jsonl"
  eq "stop_hook_active with a tool call since: blocks again" block "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty')"
  stop s4 true "$TMP/t4.jsonl"
  eq "no tool call since that block: no block" "" "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty')"
  stop nogoal false
  eq "a session without a goal: silent" "" "$OUT"
  # without jq the message is still printed (python), so "said once" is true
  g --session s5 set "late" --file nothing.txt --until 2000-01-01T00:00Z
  OUT=$(printf '{"session_id":"s5","cwd":"%s","hook_event_name":"Stop","stop_hook_active":true}' "$R" | YT_FORCE_NO_JQ=1 bash "$ROOT/hooks/stop" 2>/dev/null)
  has "no jq, a continued turn: the bound message is printed" "reached its bound" "$OUT"
fi

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
