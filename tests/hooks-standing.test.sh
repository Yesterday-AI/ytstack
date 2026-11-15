#!/usr/bin/env bash
# Tests for the standing-instruction hooks of a coordinator session (issue #72).
#
#   hooks/standing-prompt (UserPromptSubmit)
#     - no coordinate marker -> silent, writes nothing
#     - marker: every human prompt is counted (<session dir>/prompts)
#     - a prompt that reads like a standing instruction (English and German)
#       is flagged and gets the record instruction as additionalContext
#     - a plain prompt is counted, not flagged; a "<task-notification>" is neither
#   hooks/stop
#     - flagged prompt, no entry since -> decision block once, with the list
#     - the next stop with the same flags -> no block (handled)
#     - an entry in the working tree since the prompt -> no block
#     - an entry only on a branch since the prompt -> no block
#     - stop_hook_active -> silent; a block with an active task pointer comes
#       without the task reminder (a coordinate session holds no task, #82)
#
# Run: /bin/bash tests/hooks-standing.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HP="$ROOT/hooks/standing-prompt"; HS="$ROOT/hooks/stop"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3' in: $2";; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'";; *) ok "$1";; esac; }

JQ=""; for c in /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do [ -x "$c" ] && { JQ="$c"; break; }; done
[ -n "$JQ" ] || JQ=$(command -v jq)
[ -n "$JQ" ] || { echo "FATAL: jq needed"; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytstdhook.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"
unset CLAUDE_PLUGIN_DATA PLUGIN_DATA 2>/dev/null
SD="$XDG_STATE_HOME/ytstack/sessions/s1"

P="$TMP/p"; mkdir -p "$P/.ytstack"
( cd "$P" || exit 2; git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  printf 'x\n' > .ytstack/STATE.md; git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }

prompt() { # prompt <text> -> OUT
  OUT=$("$JQ" -n --arg p "$1" --arg c "$P" '{session_id: "s1", cwd: $c, hook_event_name: "UserPromptSubmit", prompt: $p}' | bash "$HP" 2>&1)
}
stop() { # stop [extra jq object] -> OUT
  local extra="${1:-}"; [ -n "$extra" ] || extra='{}'
  OUT=$("$JQ" -n --arg c "$P" '{session_id: "s1", cwd: $c, hook_event_name: "Stop"}' | "$JQ" -c ". + $extra" | bash "$HS" 2>&1)
}
lines() { [ -f "$1" ] && grep -c . "$1" || echo 0; }

echo "# no coordinate marker"
prompt "From now on always merge green pull requests."
eq "silent without the marker" "" "$OUT"
[ -e "$SD" ] && bad "writes nothing without the marker" || ok "writes nothing without the marker"

echo "# coordinate marker"
mkdir -p "$SD"; printf '%s\n' "$P/.ytstack" > "$SD/coordinate"
prompt "What is the state of lane S02?"
eq "plain prompt: silent" "" "$OUT"
eq "plain prompt: counted" 1 "$(lines "$SD/prompts")"
eq "plain prompt: not flagged" 0 "$(lines "$SD/standing-flags")"
prompt "<task-notification>agent done, never mind</task-notification>"
eq "task notification: silent" "" "$OUT"
eq "task notification: not counted" 1 "$(lines "$SD/prompts")"
prompt "From now on merge green PRs promptly."
has "English standing phrase -> instruction injected" "$OUT" "reads like a standing instruction"
has "names the command" "$OUT" "bin/ytstack-standing\\\" add"
has "says memory is no substitute" "$OUT" "Agent memory is no substitute"
if printf '%s' "$OUT" | "$JQ" -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then ok "UserPromptSubmit JSON"; else bad "UserPromptSubmit JSON" "$OUT"; fi
for p in "Bitte priorisiere M004 vor M005." "Fass PR 1336 nicht an, solange der Plan laeuft." "Denk dran: immer erst den Review." "Never touch the release branch." "Don't touch PR 12 while the load test runs." "Bis auf weiteres keine Merges ohne mein OK."; do
  prompt "$p"; has "flagged: $p" "$OUT" "standing instruction"
done
eq "all seven flagged" 7 "$(lines "$SD/standing-flags")"
eq "eight prompts counted" 8 "$(lines "$SD/prompts")"
# more true positives, English and German (review of PR #87)
for p in "Ab jetzt merge grüne PRs sofort." "Von nun an Status nur an Slice-Grenzen." "Grundsätzlich keine Force-Pushes." "Immer wenn ein Release rausgeht, starte den Watch." "Nie wieder ohne Review mergen." "Merk dir: der Dev-Cluster bleibt unangetastet." "Going forward, report only at slice boundaries." "Until further notice the PR limit is 15." "OK. Always run the full suite before a merge." "Please prioritise lane 7 over lane 3." "Lass PR 9 in Ruhe -- fass ihn nicht an." "hold merges until 12:37" "bis 12:37 keine merges" "until the load test ends" "solange der Lasttest läuft" "No deploys while the load test runs." "Keine Merges bis der Lasttest durch ist."; do
  prompt "$p"; has "flagged: $p" "$OUT" "standing instruction"
done
# ordinary prompts that only contain a word such instructions use (false positives of 0.11)
for p in "bis wann ist das fertig?" "Danke, bis später" "never mind, wrong lane" "schau mal, ob CI noch läuft während ich esse" "what happened while I was away?" "ist das immer noch rot?" "Prüf bitte, warum der Test nie grün wird" "nie gehört, was ist das?" "wie ist der stand?" "ok, mach weiter" "merge #87" "Kein Problem, danke." "The pipeline is evergreen and nobody minds." "Can you always tell me what you changed?"; do
  prompt "$p"; eq "not flagged: $p" "" "$OUT"
done
eq "only the true positives were flagged" 24 "$(lines "$SD/standing-flags")"
# the stop cases below start from the first seven flags
head -7 "$SD/standing-flags" > "$SD/sf.tmp" && mv "$SD/sf.tmp" "$SD/standing-flags"

echo "# stop: block once"
stop
eq "block decision" block "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty' 2>/dev/null)"
R=$(printf '%s' "$OUT" | "$JQ" -r '.reason // empty' 2>/dev/null)
has "reason counts the prompts" "$R" "7 human prompt(s)"
has "reason lists a prompt" "$R" "Bitte priorisiere M004"
has "reason names the command" "$R" "bin/ytstack-standing\" add"
stop; eq "second stop, same flags: silent" "" "$OUT"
eq "git status of the project stays clean" "" "$(git -C "$P" status --porcelain)"

echo "# stop: an entry since the prompt counts"
# A flag in the same second as the last stop counts as handled: wait one.
sleep 1; prompt "Always ask before a production deploy."
mkdir -p "$P/.ytstack/standing"
printf -- '---\ngiven: x\nscope: y\nsupersedes:\n---\n\nAsk first.\n' > "$P/.ytstack/standing/$(date -u +%Y%m%dT%H%MZ)-ask-first.md"
stop; eq "entry in the working tree -> no block" "" "$OUT"
rm -rf "$P/.ytstack/standing"

sleep 1; prompt "Never merge on Fridays."
( cd "$P" || exit 2; git switch -q -c standing/x && mkdir -p .ytstack/standing \
  && printf 'e\n' > ".ytstack/standing/$(date -u +%Y%m%dT%H%MZ)-no-fridays.md" && git add -A && git commit -qm entry && git switch -q - ) >/dev/null 2>&1
[ ! -d "$P/.ytstack/standing" ] && ok "fixture: entry only on the branch" || bad "fixture: entry only on the branch"
stop; eq "entry on a local branch -> no block" "" "$OUT"

echo "# stop: guards and the task reminder"
sleep 1; prompt "Never deploy without a watch."
stop '{"stop_hook_active": true}'; eq "stop_hook_active -> silent" "" "$OUT"
printf 'current_milestone: M042\nactive_slice: S03\nactive_task: T07\n' > "$P/.ytstack/STATE.md"
stop
eq "block with an active task pointer: block" block "$(printf '%s' "$OUT" | "$JQ" -r '.decision // empty')"
eq "a coordinate session holds no task: no task reminder (issue #82)" "" "$(printf '%s' "$OUT" | "$JQ" -r '.systemMessage // empty')"
rm -f "$SD/coordinate"
prompt "Never again."; stop
hasnt "marker gone: no block" "$OUT" '"decision"'

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
