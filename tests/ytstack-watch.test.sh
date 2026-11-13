#!/usr/bin/env bash
# Tests for bin/ytstack-watch: pull request state read from the host by a
# process, so that no model turn is spent on polling.
#
# Contract:
#   --once    one line per pull request with state, head, checks, review,
#             merge and "read <UTC>"; exit 1 when a read failed
#   loop      the first poll prints every pull request; later a line only when
#             a value changed (head moved, checks turned green, a review
#             arrived); "unknown" mergeability after a known value is no
#             change; ends with 0 when all are merged or closed; a finished
#             pull request is not read again
#   errors    a failed read prints one line and the loop continues; three
#             failed polls in a row end it with 1
#   usage     no --pr, a value that is no number, --interval below 20: exit 64
#   no state  nothing is written into the repository
#
# No network and no real gh: a fake `gh` first in PATH answers `pr view N` from
# $FIX/now/N.json (or fails when $FIX/now/N.err exists) and applies the --jq
# expression with the local jq. The watcher's sleep is replaced through
# YTSTACK_WATCH_SLEEP by a script that copies the next step's fixtures into
# place, so a run of several polls takes no wall time.
#
# Run: /bin/bash tests/ytstack-watch.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-watch"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }
# like <name> <ERE> <text>: one line of the text matches
like() { if printf '%s\n' "$3" | grep -E -- "$2" >/dev/null; then ok "$1"; else bad "$1" "no line matches /$2/ in: $3"; fi; }
# lines <text>: the number of non-empty lines
lines() { printf '%s\n' "$1" | awk 'NF { n++ } END { print n + 0 }'; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-watch exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  bad "jq is available (the fake gh needs it for --jq)"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytwatch-t.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/fix"; FAKE="$TMP/fakebin"; REPO="$TMP/repo"
mkdir -p "$FAKE" "$REPO"
( cd "$REPO" && git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false \
  && echo seed > f.txt && git add -A && git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }

cat > "$FAKE/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh: `pr view N --json FIELDS --jq EXPR` from $FIX/now/N.json.
printf '%s\n' "$*" | head -1 >> "$FIX/calls"
pwd -P > "$FIX/cwd"
[ "${1:-}" = pr ] && [ "${2:-}" = view ] || { echo "fake gh: unexpected command: $1 $2" >&2; exit 2; }
n=$3; shift 3
expr=""
while [ $# -gt 0 ]; do
  case "$1" in --jq) expr=$2; shift 2 ;; --json) echo "$2" >> "$FIX/fields"; shift 2 ;; *) shift ;; esac
done
[ ! -f "$FIX/now/$n.err" ] || { cat "$FIX/now/$n.err" >&2; exit 1; }
[ -f "$FIX/now/$n.json" ] || { echo "GraphQL: Could not resolve to a PullRequest with the number of $n." >&2; exit 1; }
[ ! -f "$FIX/now/$n.warn" ] || cat "$FIX/now/$n.warn" >&2
jq -r "$expr" "$FIX/now/$n.json"
EOF
# The stand-in for sleep: counts the polls, records the interval it was given,
# then moves step<k> into place. After 30 polls it ends the watcher (its parent
# process), so a loop that never ends fails the suite instead of hanging it.
cat > "$FAKE/next-step" <<'EOF'
#!/usr/bin/env bash
k=$(cat "$FIX/polls" 2>/dev/null || echo 1); k=$((k + 1)); echo "$k" > "$FIX/polls"
echo "$1" >> "$FIX/sleeps"
[ ! -f "$FIX/stdout" ] || awk 'END { print NR }' "$FIX/stdout" >> "$FIX/seen"
if [ -d "$FIX/step$k" ]; then
  for f in "$FIX/step$k"/*; do
    case "$f" in *.gone) rm -f "$FIX/now/$(basename "$f" .gone)" ;; *) cp "$f" "$FIX/now/" ;; esac
  done
fi
[ "$k" -lt 30 ] || kill "$PPID"
EOF
chmod +x "$FAKE/gh" "$FAKE/next-step"

A=a1b2c3d4e5f60718293a4b5c6d7e8f9012345678   # first head
B=b2c3d4e5f60718293a4b5c6d7e8f90123456789a   # head after a push
RUN_OK='{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"SUCCESS"}'
RUN_SKIP='{"__typename":"CheckRun","name":"docs","status":"COMPLETED","conclusion":"SKIPPED"}'
RUN_BUSY='{"__typename":"CheckRun","name":"test","status":"IN_PROGRESS","conclusion":""}'
RUN_BAD='{"__typename":"CheckRun","name":"lint","status":"COMPLETED","conclusion":"FAILURE"}'
CTX_OK='{"__typename":"StatusContext","context":"deploy/preview","state":"SUCCESS"}'
CTX_WAIT='{"__typename":"StatusContext","context":"deploy/preview","state":"PENDING"}'
# review <STATE> <sha> <submittedAt>
review() { printf '{"author":{"login":"rev"},"state":"%s","submittedAt":"%s","commit":{"oid":"%s"}}' "$1" "$3" "$2"; }
# pr <dir> <n> <STATE> <head> <checks, comma separated> <reviews, comma separated> <MERGEABLE>
pr() {
  mkdir -p "$1"
  printf '{"state":"%s","headRefOid":"%s","statusCheckRollup":[%s],"reviews":[%s],"mergeable":"%s"}\n' "$3" "$4" "$5" "$6" "$7" > "$1/$2.json"
}
fresh() { rm -rf "$FIX"; mkdir -p "$FIX/now"; : > "$FIX/calls"; : > "$FIX/sleeps"; : > "$FIX/fields"; }
# watch <args...>: runs in the fixture repository; sets OUT (stdout), ERRS (stderr) and EC
watch() {
  OUT=$(cd "$REPO" && FIX="$FIX" PATH="$FAKE:$PATH" YTSTACK_WATCH_SLEEP="$FAKE/next-step" bash "$BIN" "$@" 2>"$TMP/stderr"); EC=$?
  ERRS=$(cat "$TMP/stderr")
}
STAMP='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'

# ---- 1. --once ------------------------------------------------------------------
echo "# --once"
fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK,$RUN_SKIP,$CTX_OK" "$(review COMMENTED "$A" 2026-11-13T09:00:00Z),$(review APPROVED "$A" 2026-11-13T10:00:00Z)" MERGEABLE
DRAFT_REVIEW="{\"author\":{\"login\":\"me\"},\"state\":\"PENDING\",\"submittedAt\":null,\"commit\":{\"oid\":\"$A\"}}"
pr "$FIX/now" 15 OPEN "$B" "$RUN_OK,$RUN_BUSY" "$DRAFT_REVIEW" CONFLICTING
pr "$FIX/now" 16 MERGED "$A" "" "$(review CHANGES_REQUESTED "$B" 2026-11-13T08:00:00Z)" UNKNOWN
pr "$FIX/now" 17 OPEN "$A" "$RUN_BAD,$RUN_BUSY,$CTX_WAIT" "$(review APPROVED "$A" 2026-11-13T10:00:00Z)" MERGEABLE
watch --pr 12,15,16,17 --once
eq "--once exits 0" 0 "$EC"
eq "--once prints one line per pull request" 4 "$(lines "$OUT")"
like "green checks, the newest review and its commit, mergeable, the read stamp" \
  "^#12 state=open head=a1b2c3d checks=green review=approved@a1b2c3d merge=mergeable read $STAMP\$" "$OUT"
like "an unfinished check makes pending; a review that was not submitted is no review; a conflict" \
  "^#15 state=open head=b2c3d4e checks=pending review=none merge=conflict read $STAMP\$" "$OUT"
like "a merged pull request without checks" \
  "^#16 state=merged head=a1b2c3d checks=none review=changes_requested@b2c3d4e merge=unknown read $STAMP\$" "$OUT"
like "one failed check makes red, also beside unfinished ones" \
  "^#17 state=open head=a1b2c3d checks=red review=approved@a1b2c3d merge=mergeable read $STAMP\$" "$OUT"
eq "--once does not sleep" "" "$(cat "$FIX/sleeps")"
eq "one gh call per pull request" 4 "$(lines "$(cat "$FIX/calls")")"
eq "every call asks for the five fields" "state,headRefOid,statusCheckRollup,reviews,mergeable" "$(sort -u "$FIX/fields")"
printf 'A new release of gh is available\n' > "$FIX/now/12.warn"
watch --pr 12 --once
like "a notice of gh on stderr does not end up in the line" "^#12 state=open head=a1b2c3d checks=green " "$OUT"
eq "one line despite the notice" 1 "$(lines "$OUT")"

# ---- 2. the loop: a line only when a value changed -------------------------------
echo "# loop"
fresh
pr "$FIX/now"   12 OPEN "$A" "$RUN_BUSY" "" MERGEABLE          # poll 1: first poll prints everything
pr "$FIX/now"   15 OPEN "$A" "$RUN_OK"   "" MERGEABLE
                                                                # poll 2: nothing changed
pr "$FIX/step3" 12 OPEN "$B" "$RUN_BUSY" "" MERGEABLE          # poll 3: the head of #12 moved
pr "$FIX/step4" 12 OPEN "$B" "$RUN_OK"   "" UNKNOWN            # poll 4: checks green; unknown mergeability is no change
pr "$FIX/step5" 12 OPEN "$B" "$RUN_OK"   "" MERGEABLE          # poll 5: nothing changed (mergeable again)
pr "$FIX/step6" 12 OPEN "$B" "$RUN_OK"   "$(review APPROVED "$B" 2026-11-13T11:00:00Z)" MERGEABLE   # poll 6: a review arrived
pr "$FIX/step7" 15 MERGED "$A" "$RUN_OK" "" UNKNOWN            # poll 7: #15 merged, #12 unchanged
pr "$FIX/step8" 12 OPEN "$B" "$RUN_OK"   "$(review APPROVED "$B" 2026-11-13T11:00:00Z)" CONFLICTING # poll 8: #12 conflicts
pr "$FIX/step9" 12 CLOSED "$B" "$RUN_OK" "$(review APPROVED "$B" 2026-11-13T11:00:00Z)" CONFLICTING # poll 9: #12 closed -> end
watch --pr 12,15
eq "the loop ends with 0 when all are merged or closed" 0 "$EC"
eq "it took nine polls" 9 "$(cat "$FIX/polls")"
L() { printf '%s\n' "$OUT" | sed -n "${1}p"; }
eq "eight lines: two at the start, then one per change" 8 "$(lines "$OUT")"
like "poll 1 prints #12" "^$STAMP #12 state=open head=a1b2c3d checks=pending review=none merge=mergeable\$" "$(L 1)"
like "poll 1 prints #15" "^$STAMP #15 state=open head=a1b2c3d checks=green review=none merge=mergeable\$" "$(L 2)"
like "poll 2 printed nothing; poll 3: the head moved" "^$STAMP #12 state=open head=b2c3d4e checks=pending review=none merge=mergeable\$" "$(L 3)"
like "poll 4: checks turned green, mergeability kept" "^$STAMP #12 state=open head=b2c3d4e checks=green review=none merge=mergeable\$" "$(L 4)"
like "poll 5 printed nothing; poll 6: a review arrived" "^$STAMP #12 state=open head=b2c3d4e checks=green review=approved@b2c3d4e merge=mergeable\$" "$(L 5)"
like "poll 7: #15 merged" "^$STAMP #15 state=merged head=a1b2c3d checks=green review=none merge=mergeable\$" "$(L 6)"
like "poll 8: a conflict" "^$STAMP #12 state=open .* merge=conflict\$" "$(L 7)"
like "poll 9: #12 closed" "^$STAMP #12 state=closed " "$(L 8)"
eq "the default interval is 60 seconds, between polls only" "60 60 60 60 60 60 60 60" "$(tr '\n' ' ' < "$FIX/sleeps" | sed 's/ $//')"
eq "a finished pull request is not read again (9 + 7 calls)" 16 "$(lines "$(cat "$FIX/calls")")"
hasnt "no error line in a clean run" "error" "$OUT"

fresh
pr "$FIX/now" 12 MERGED "$A" "$RUN_OK" "" UNKNOWN
watch --pr 12 --interval 20
eq "a pull request that is already merged: exit 0" 0 "$EC"
eq "one line, no sleep" "1:" "$(lines "$OUT"):$(cat "$FIX/sleeps")"

fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK" "" MERGEABLE
pr "$FIX/step2" 12 MERGED "$A" "$RUN_OK" "" UNKNOWN
watch --pr 12 --interval 45
eq "--interval reaches the sleep" 45 "$(cat "$FIX/sleeps")"

# A line is written when it is known, not when the process ends: the stand-in
# for sleep counts the lines that are in the output file at that moment.
fresh
pr "$FIX/now"   12 OPEN "$A" "$RUN_BUSY" "" MERGEABLE
pr "$FIX/step2" 12 OPEN "$A" "$RUN_OK"   "" MERGEABLE
pr "$FIX/step3" 12 MERGED "$A" "$RUN_OK" "" UNKNOWN
( cd "$REPO" && FIX="$FIX" PATH="$FAKE:$PATH" YTSTACK_WATCH_SLEEP="$FAKE/next-step" bash "$BIN" --pr 12 > "$FIX/stdout" 2>/dev/null )
eq "each line is in the output before the next sleep" "1 2" "$(tr '\n' ' ' < "$FIX/seen" | sed 's/ $//')"

# ---- 3. errors ------------------------------------------------------------------
echo "# errors"
fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK" "" MERGEABLE
mkdir -p "$FIX/step2" "$FIX/step4" "$FIX/step5" "$FIX/step7"
printf 'HTTP 502: Bad Gateway (https://api.github.com/graphql)\nsecond line\n' > "$FIX/step2/12.err"   # polls 2 and 3 fail
: > "$FIX/step4/12.err.gone"                                                                          # poll 4 works
cp "$FIX/step2/12.err" "$FIX/step5/12.err"                                                            # polls 5 and 6 fail
: > "$FIX/step7/12.err.gone"
pr "$FIX/step7" 12 MERGED "$A" "$RUN_OK" "" UNKNOWN                                                   # poll 7: merged
watch --pr 12
eq "four failed polls, never three in a row, do not end the loop" 0 "$EC"
eq "one line per failed read, between the first line and the merge" 6 "$(lines "$OUT")"
like "the error line carries the time, the number and the first line of the message" "^$STAMP #12 error: HTTP 502: Bad Gateway \(https://api.github.com/graphql\)\$" "$(L 2)"
hasnt "only the first line of the message" "second line" "$OUT"
like "after the errors the loop reads again" "^$STAMP #12 state=merged " "$(L 6)"

fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK" "" MERGEABLE
pr "$FIX/now" 15 OPEN "$A" "$RUN_OK" "" MERGEABLE
mkdir -p "$FIX/step2"; echo "HTTP 401: Bad credentials" > "$FIX/step2/15.err"
watch --pr 12,15
eq "three failed polls in a row: exit 1" 1 "$EC"
eq "it stopped after the fourth poll" 4 "$(cat "$FIX/polls")"
eq "three error lines for #15" 3 "$(printf '%s\n' "$OUT" | grep -c '#15 error: HTTP 401: Bad credentials')"
like "the last line says why it stopped" "^$STAMP ytstack-watch: three polls in a row failed, stopping\$" "$(printf '%s\n' "$OUT" | tail -1)"

fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK" "" MERGEABLE
watch --pr 12,99 --once
eq "--once with a failed read: exit 1" 1 "$EC"
like "--once still prints what it could read" "^#12 state=open " "$OUT"
like "--once names the failed read" "^#99 error: GraphQL: Could not resolve to a PullRequest with the number of 99\. read $STAMP\$" "$OUT"

fresh
pr "$FIX/now" 12 LOCKED "$A" "$RUN_OK" "" MERGEABLE
watch --pr 12 --once
eq "a state that is none of open, merged, closed: exit 1" 1 "$EC"
has "it is reported as an error, not as a state" "#12 error: unexpected answer from gh" "$OUT"
echo '{"state":"OPEN"}' > "$FIX/now/12.json"
watch --pr 12 --once
eq "an answer without the other fields: exit 1" 1 "$EC"
has "also reported as an error" "#12 error: " "$OUT"

OUT=$(cd "$REPO" && PATH="/usr/bin:/bin" bash "$BIN" --pr 12 --once 2>&1); EC=$?
if PATH="/usr/bin:/bin" command -v gh >/dev/null 2>&1; then
  ok "no gh on PATH: skipped (this system has gh in /usr/bin or /bin)"
else
  eq "no gh on PATH: exit 1" 1 "$EC"
  has "no gh on PATH: says so" "gh is not on PATH" "$OUT"
fi

# ---- 4. usage -------------------------------------------------------------------
echo "# usage"
fresh
pr "$FIX/now" 12 OPEN "$A" "$RUN_OK" "" MERGEABLE
watch --pr 12 --interval 19
eq "--interval below the minimum is refused" 64 "$EC"
has "the refusal names the minimum" "below the minimum of 20 seconds" "$ERRS"
watch --pr 12 --interval 19 --once
eq "also with --once" 64 "$EC"
watch --pr 12 --interval soon;  eq "--interval that is no number" 64 "$EC"
watch --once;                   eq "no --pr" 64 "$EC"
has "usage on stderr" "ytstack-watch [-C DIR] --pr N[,N...] [--interval SECONDS] [--once]" "$ERRS"
watch --pr 12,x --once;         eq "--pr with a value that is no number" 64 "$EC"
watch --pr "12;id" --once;      eq "--pr with shell characters" 64 "$EC"
watch --pr 12, --once;          eq "--pr with an empty entry" 64 "$EC"
watch --pr;                     eq "--pr without a value" 64 "$EC"
watch --pr 12 --forever;        eq "an unknown flag" 64 "$EC"
watch -C "$TMP/nowhere" --pr 12 --once; eq "-C that is no directory" 64 "$EC"
eq "no gh call was made for a usage error" "" "$(cat "$FIX/calls")"
watch --help
eq "--help exits 0" 0 "$EC"
has "--help prints the usage line" "ytstack-watch [-C DIR] --pr N[,N...]" "$OUT"

# -C: gh runs in the directory that was named
( cd "$TMP" && FIX="$FIX" PATH="$FAKE:$PATH" bash "$BIN" -C "$REPO" --pr 12 --once ) > "$TMP/out" 2>&1; EC=$?
eq "-C DIR works from elsewhere" 0 "$EC"
eq "gh ran in that directory" "$REPO" "$(cat "$FIX/cwd")"

# ---- 5. nothing is written into the repository ----------------------------------
echo "# no state in the repository"
eq "the repository is clean after every run above" "" "$(git -C "$REPO" status --porcelain)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
