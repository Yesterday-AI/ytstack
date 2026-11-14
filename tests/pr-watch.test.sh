#!/usr/bin/env bash
# Tests for the opt-in PR watch (DECISIONS 2026-11-14, docs/pr-watch.md):
#
#   engine    the unittest suite under tests/pr_watch (mocked gh and Codex)
#   wrapper   hooks/pr-watch: off = exit 0, no output, no python3 needed;
#             on = the engine runs; a prompt without watches prints nothing;
#             malformed stdin still exits 0 with nothing on stdout
#   CLI       bin/ytstack-pr-watch: --help, enable/disable round trip,
#             install-worker and uninstall-worker print a plan and write
#             nothing without --yes, a second LaunchAgent is refused,
#             migrate writes nothing without --yes and copies with --yes
#
# Everything runs under a temporary HOME; never the real one, never GitHub.
#
# Run: /bin/bash tests/pr-watch.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
HOOK="$ROOT/hooks/pr-watch"
CLI="$ROOT/bin/ytstack-pr-watch"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1";; *) bad "$1" "missing '$2' in: $(printf '%s' "$3" | head -3 | tr '\n' ' ')";; esac; }

T=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/ytpw.XXXXXX")" && pwd -P)
trap 'rm -rf "$T"' EXIT
unset PR_WATCH_HOME YTSTACK_PR_WATCH_HOME YTSTACK_PR_WATCH_CLI YTSTACK_PYTHON CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID
export PYTHONDONTWRITEBYTECODE=1
# The real interpreter, resolved before HOME changes: version-manager shims
# (asdf, pyenv) look up their config under HOME and fail under a temp HOME.
PYBIN=$(python3 -c 'import sys; print(sys.executable)') || { echo "python3 missing"; exit 1; }
PATH="$(dirname "$PYBIN"):$PATH"; export PATH
fresh() { H="$T/home$1"; mkdir -p "$H"; }
on()  { mkdir -p "$H/.ytstack"; printf 'pr_watch=on\n' >"$H/.ytstack/config"; }
count() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }

# ---- engine unit tests ----
if out=$(cd "$ROOT" && python3 -m unittest discover -s tests/pr_watch 2>&1); then
  ok "engine unittest suite ($(printf '%s\n' "$out" | grep -E '^Ran ' | head -1))"
else
  bad "engine unittest suite" "$(printf '%s\n' "$out" | tail -5 | tr '\n' ' ')"
fi

# ---- wrapper ----
fresh 1
mkdir "$T/greponly" && ln -s "$(command -v grep)" "$T/greponly/grep"
out=$(printf '{"session_id":"s","hook_event_name":"UserPromptSubmit"}' | HOME="$H" "$HOOK" claude 2>"$T/err"); ec=$?
eq "off: exit 0, empty stdout, empty stderr" "0::" "$ec:$out:$(cat "$T/err")"
out=$(HOME="$H" PATH="$T/greponly" /bin/bash "$HOOK" claude </dev/null 2>&1); ec=$?
eq "off: exit 0 and silent without python3 on PATH" "0:" "$ec:$out"
eq "off: no state directory" "no" "$([ -e "$H/.ytstack/pr-watch" ] && echo yes || echo no)"
on
out=$(HOME="$H" PATH="$T/greponly" /bin/bash "$HOOK" claude </dev/null 2>"$T/err"); ec=$?
eq "on without python3: exit 0, empty stdout" "0:" "$ec:$out"
has "on without python3: one line on stderr" "python3 not found" "$(cat "$T/err")"

mkdir "$T/proj"
payload() { printf '{"session_id":"abc","cwd":"%s","hook_event_name":"%s"}' "$T/proj" "$1"; }
out=$(payload UserPromptSubmit | HOME="$H" "$HOOK" claude 2>"$T/err"); ec=$?
eq "on: prompt in a session without watches, exit 0 and no output" "0::" "$ec:$out:$(cat "$T/err")"
out=$(payload SessionStart | HOME="$H" "$HOOK" claude 2>"$T/err"); ec=$?
eq "on: SessionStart exits 0" "0:" "$ec:$(cat "$T/err")"
ctx=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>&1)
has "on: SessionStart names the session host-qualified" "This session is claude:abc." "$ctx"
has "on: SessionStart names the CLI by its plugin path" "$CLI register" "$ctx"
eq "on: state lives under ~/.ytstack/pr-watch/state" "yes" "$([ -f "$H/.ytstack/pr-watch/state/watch.sqlite3" ] && echo yes || echo no)"
out=$(printf 'not json' | HOME="$H" "$HOOK" claude 2>"$T/err"); ec=$?
eq "on: malformed stdin, exit 0 and empty stdout" "0:" "$ec:$out"
eq "on: malformed stdin, one line on stderr" "1" "$(wc -l <"$T/err" | tr -d ' ')"
has "on: the line names the failure" "ytstack pr-watch: hook failed" "$(cat "$T/err")"
out=$(printf '{}' | HOME="$H" "$HOOK" codex 2>"$T/err"); ec=$?
eq "on: payload without session_id, exit 0 and empty stdout" "0:" "$ec:$out"
printf 'other=1\n  pr_watch = on \n' >"$H/.ytstack/config"
out=$(payload SessionStart | HOME="$H" "$HOOK" claude 2>/dev/null)
has "on: the switch tolerates spaces" "hookSpecificOutput" "$out"

# ---- CLI ----
fresh 2
out=$(HOME="$H" "$CLI" --help 2>&1); ec=$?
eq "--help exits 0" "0" "$ec"
for c in status register create inspect pause resume tick hook enable disable install-worker uninstall-worker migrate; do
  case "$out" in *"$c"*) ok "--help lists $c";; *) bad "--help lists $c";; esac
done

mkdir -p "$H/.ytstack" && printf 'statusline=on\n' >"$H/.ytstack/config"
HOME="$H" "$CLI" enable >/dev/null 2>&1
eq "enable adds pr_watch=on and keeps other keys" "statusline=on|pr_watch=on" "$(paste -sd'|' "$H/.ytstack/config")"
HOME="$H" "$CLI" enable >/dev/null 2>&1
eq "enable twice keeps one line" "1" "$(grep -c pr_watch "$H/.ytstack/config")"
HOME="$H" "$CLI" disable >/dev/null 2>&1
eq "disable removes only the switch" "statusline=on" "$(cat "$H/.ytstack/config")"
fresh 3
HOME="$H" "$CLI" enable >/dev/null 2>&1
eq "enable creates a missing config" "pr_watch=on" "$(cat "$H/.ytstack/config" 2>/dev/null)"

# install-worker / uninstall-worker: a fake gh so the plan does not depend on the machine.
mkdir "$T/fakebin" && printf '#!/bin/sh\nexit 0\n' >"$T/fakebin/gh" && chmod +x "$T/fakebin/gh"
fresh 4
before=$(count "$H")
out=$(HOME="$H" PATH="$T/fakebin:$PATH" "$CLI" install-worker 2>&1); ec=$?
eq "install-worker without --yes exits 0" "0" "$ec"
eq "install-worker without --yes writes nothing" "$before" "$(count "$H")"
if [ "$(uname -s)" = Darwin ]; then
  has "install-worker plan names the LaunchAgent" "com.ytstack.pr-watch" "$out"
  has "install-worker plan names the launcher" "$H/.ytstack/pr-watch/bin/pr-watch" "$out"
  mkdir -p "$H/Library/LaunchAgents" && printf 'x' >"$H/Library/LaunchAgents/old.pr-watch.plist"
  before=$(count "$H")
  out=$(HOME="$H" PATH="$T/fakebin:$PATH" "$CLI" install-worker --yes 2>&1); ec=$?
  eq "install-worker refuses next to another pr-watch LaunchAgent (exit 2)" "2" "$ec"
  has "refusal names the other plist" "old.pr-watch.plist" "$out"
  eq "refusal writes nothing" "$before" "$(count "$H")"
else
  has "install-worker off macOS prints a systemd recipe" "systemctl --user" "$out"
fi
# The launcher the worker runs: the engine Claude Code has installed
# (installed_plugins.json), else the newest non-orphaned cached version across
# both plugin caches, else the recorded fallback.
L="$T/launcher"; mkdir -p "$L/bin"
(cd "$ROOT/tools/pr-watch" && "$PYBIN" -c '
import shlex, sys
from prwatch import admin
print(admin.LAUNCHER % {"home": shlex.quote(sys.argv[1]), "python": shlex.quote(sys.argv[2])}, end="")' "$L/state" "$PYBIN") >"$L/bin/pr-watch"
stub() { mkdir -p "$(dirname "$1")"; printf 'import os, sys\nprint(sys.argv[0], os.environ["YTSTACK_PR_WATCH_HOME"], *sys.argv[1:])\n' >"$1"; }
stub "$L/fallback/tools/pr-watch/pr-watch.py"; echo "$L/fallback/tools/pr-watch/pr-watch.py" >"$L/bin/engine-path"
eq "launcher without cached plugins runs the fallback engine" "$L/fallback/tools/pr-watch/pr-watch.py $L/state tick" \
  "$(HOME="$L/h" sh "$L/bin/pr-watch" tick 2>&1)"
stub "$L/h/.claude/plugins/cache/mp/ytstack/0.9.0/tools/pr-watch/pr-watch.py"
stub "$L/h/.claude/plugins/cache/mp/ytstack/0.10.0/tools/pr-watch/pr-watch.py"
stub "$L/h/.codex/plugins/cache/ytstack/ytstack/0.9.5/tools/pr-watch/pr-watch.py"
eq "launcher picks the highest version across both caches" "$L/h/.claude/plugins/cache/mp/ytstack/0.10.0/tools/pr-watch/pr-watch.py $L/state tick" \
  "$(HOME="$L/h" sh "$L/bin/pr-watch" tick 2>&1)"
touch "$L/h/.claude/plugins/cache/mp/ytstack/0.10.0/.orphaned_at"
eq "launcher skips a version marked .orphaned_at (rolled back)" "$L/h/.codex/plugins/cache/ytstack/ytstack/0.9.5/tools/pr-watch/pr-watch.py $L/state tick" \
  "$(HOME="$L/h" sh "$L/bin/pr-watch" tick 2>&1)"
mkdir -p "$L/h/.claude/plugins"
printf '{"version":2,"plugins":{"ytstack@mp":[{"scope":"user","installPath":"%s","version":"0.9.0"}]}}' \
  "$L/h/.claude/plugins/cache/mp/ytstack/0.9.0" >"$L/h/.claude/plugins/installed_plugins.json"
eq "launcher prefers the version Claude Code has installed" "$L/h/.claude/plugins/cache/mp/ytstack/0.9.0/tools/pr-watch/pr-watch.py $L/state tick" \
  "$(HOME="$L/h" sh "$L/bin/pr-watch" tick 2>&1)"

out=$(HOME="$H" "$CLI" uninstall-worker 2>&1); ec=$?
eq "uninstall-worker without --yes exits 0" "0" "$ec"
eq "uninstall-worker without --yes writes nothing" "$before" "$(count "$H")"

# migrate: a fixture DB in an old local install layout (<dir>/state/watch.sqlite3).
fresh 5
OLD="$T/old-install"
mkdir -p "$OLD/state"
(cd "$ROOT/tools/pr-watch" && PR_WATCH_HOME="$OLD/state" python3 -c '
from prwatch.state import connect, register
db = connect()
with db:
    register(db, "owner/repo", 12, "claude:fixture", "/tmp")
db.close()')
printf '{"defaults": {}}\n' >"$OLD/state/policy.json"
# The database, its WAL and the policy stay byte-identical. The -shm file is
# SQLite's shared-memory index: every reader, read-only ones included, updates
# its read marks there, so it is left out of the comparison.
srcsum() { (cd "$OLD/state" && cksum watch.sqlite3 policy.json $(ls watch.sqlite3-wal 2>/dev/null) | sort | paste -sd' ' -); }
src_sum=$(srcsum)
out=$(HOME="$H" "$CLI" migrate --from "$OLD" 2>&1); ec=$?
eq "migrate without --yes exits 0" "0" "$ec"
has "migrate plan counts the watches" "1 watches" "$out"
eq "migrate without --yes writes nothing" "no" "$([ -e "$H/.ytstack" ] && echo yes || echo no)"
out=$(HOME="$H" "$CLI" migrate --from "$OLD" --yes 2>&1); ec=$?
eq "migrate --yes exits 0" "0" "$ec"
eq "migrate --yes copies the watch" "claude:fixture" \
  "$(python3 -c 'import sqlite3,sys; print(sqlite3.connect(sys.argv[1]).execute("SELECT session FROM watches").fetchone()[0])' "$H/.ytstack/pr-watch/state/watch.sqlite3" 2>&1)"
eq "migrate --yes copies the policy" "yes" "$([ -f "$H/.ytstack/pr-watch/state/policy.json" ] && echo yes || echo no)"
has "migrate lists the manual steps" "pr-watch@local-pr-watch" "$out"
eq "migrate leaves the source files as they were" "$src_sum" "$(srcsum)"
out=$(HOME="$H" "$CLI" migrate --from "$OLD" --yes 2>&1); ec=$?
eq "migrate refuses an existing target DB (exit 2)" "2" "$ec"
out=$(HOME="$H" "$CLI" migrate --from "$T/nowhere" 2>&1); ec=$?
eq "migrate without a source DB exits 2" "2" "$ec"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
