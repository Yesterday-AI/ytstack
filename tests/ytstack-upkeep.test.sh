#!/usr/bin/env bash
# Tests for bin/ytstack-upkeep: one run that collects what needs a look in a
# project's .ytstack/ and prints one report.
#
# Contract:
#   clean     seven sections with the count 0, "nothing needs a look", exit 0;
#             nothing is written
#   spec      the failures of `ytstack-spec lint` and the areas of `drift`
#   state     the findings of the STATE.md lint
#   gates     open gate lines of the plans; one whose `lapses:` date has passed
#             is marked as lapsed, a closed gate is not listed
#   questions open for more than --open-days days (default 3), asked more than
#             --asked-days days ago (default 7); answered ones never
#   lanes     held rows of LANES.md claimed more than --lane-hours hours ago
#             (default 24), also lanes that are no slice; a table that fails
#             `ytstack-frontier check` is reported and not read
#   runtime   the problems of `ytstack-runtime check`
#   review policy  the problems of `ytstack-risk check` when the script exists
#             beside ytstack-upkeep, a note when it does not
#   review checks  with own reviewers in REVIEW.md: merged pull requests
#             without a line in signals/review-checks, from one `gh pr list`
#             (a stand-in gh), merged at or after the earliest check time (the
#             last 14 days without one), an old number merged late included; a failed
#             read is an item; without own reviewers no host call
#   exit     10 when a count is not 0; 1 without a .ytstack directory; 64 usage
#   --question  one question file through `ytstack-questions new`, the report
#             under "## Context"; none while an earlier one is open or asked,
#             none for a clean project
#
# The review policy cases run on a copy of the scripts in a stand-in directory
# (bin/ and hooks/lib/ in the fixture), once without and once with a stand-in
# ytstack-risk. The real bin/ is never written to.
#
# Run: /bin/bash tests/ytstack-upkeep.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-upkeep"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }
# like <name> <ERE> <text>: one line of the text matches
like() { if printf '%s\n' "$3" | grep -E -- "$2" >/dev/null; then ok "$1"; else bad "$1" "no line matches /$2/ in: $3"; fi; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-upkeep exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytupkeep.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
STAMP='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
NOW=$(date -u +%s)

UP="$BIN"
# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$("$BASH" "$UP" -C "$d" "$@" 2>&1); EC=$?; }
# ago <seconds>: the UTC time that long ago (BSD date, then GNU and BusyBox)
ago() {
  local e=$((NOW - $1))
  date -u -r "$e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$e" +%Y-%m-%dT%H:%M:%SZ
}
HOUR=3600; DAY=86400
# project <name>: a directory with a .ytstack that holds a clean STATE.md. Sets D and Y.
project() {
  D="$TMP/$1"; Y="$D/.ytstack"; mkdir -p "$Y"
  printf -- '---\ncurrent_milestone: none\nactive_slice: none\nactive_task: none\nlast_updated: %s\n---\n\n# State\n' "$(ago 0)" > "$Y/STATE.md"
}
# count <section>: the number the report gives for a section
count() { printf '%s\n' "$OUT" | sed -n "s/^$1: \([0-9][0-9]*\).*/\1/p" | sed -n 1p; }
# snap: every file of the project with its checksum
snap() { ( cd "$D" && find . -type f -exec cksum {} + | sort ); }
# question <id> <slug> <state> <opened> <asked> <answered> <title>
question() {
  mkdir -p "$Y/questions"
  printf -- '---\nid: %s\nstate: %s\ndecides: the operator\nopened: %s\nasked: %s\nanswered: %s\nblocks: none\n---\n\n# %s -- %s\n\n## Context\n\n## Options\n\n## Recommendation\n\n## Answer\n' \
    "$1" "$3" "$4" "$5" "$6" "$1" "$7" > "$Y/questions/$1-$2.md"
  [ "$3" != answered ] || echo "Yes, said the operator." >> "$Y/questions/$1-$2.md"
}

# ---- 1. a clean project -----------------------------------------------------------
echo "# clean"
project clean
BEFORE=$(snap)
run "$D"
eq "a clean project: exit 0" 0 "$EC"
eq "the last line says so" "nothing needs a look" "$(printf '%s\n' "$OUT" | tail -1)"
like "the first line names the directory and the time of the read" "^ytstack upkeep: $Y, read $STAMP" "$(printf '%s\n' "$OUT" | sed -n 1p)"
for s in spec state gates questions lanes runtime "review policy" "review checks"; do
  eq "section $s: 0" 0 "$(count "$s")"
done
eq "eight sections, the first and the last line" 10 "$(printf '%s\n' "$OUT" | awk 'NF { n++ } END { print n + 0 }')"
has "a project without own reviewers says so" "review checks: 0 (no own reviewers)" "$OUT"
has "a project without a technical spec says so" "spec: 0 (no technical spec)" "$OUT"
eq "nothing was written" "$BEFORE" "$(snap)"
run "$D" --question
eq "--question on a clean project: exit 0" 0 "$EC"
eq "and still nothing was written" "$BEFORE" "$(snap)"

# ---- 2. spec ----------------------------------------------------------------------
echo "# spec"
project spec
mkdir -p "$Y/spec" "$D/src/auth"
( cd "$D" && git init -q && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false \
  && echo a > src/auth/login.sh && git add -A && git commit -qm base ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }
V=$(git -C "$D" rev-parse --short HEAD)
AREA_BODY='# %s\n\n## Purpose\n\nx\n\n## Where implemented\n\nx\n\n## How to verify\n\nx\n\n## Decisions that apply now\n\nnone\n'
# shellcheck disable=SC2059
{ printf -- '---\narea: auth\nstatus: implemented\npaths:\n  - src/auth/**\nverified_at: %s\n---\n\n' "$V"; printf "$AREA_BODY" auth; } > "$Y/spec/auth.md"
# shellcheck disable=SC2059
{ printf -- '---\narea: billing\nstatus: planned\nverified_at: none\n---\n\n'; printf "$AREA_BODY" billing; } > "$Y/spec/billing.md"
printf -- '---\nproject: fx\nupdated: 2026-01-01\n---\n\n# fx -- technical spec\n\n## What this is\n\nx\n\n## Areas\n\n| Area | Covers | Status | File |\n|---|---|---|---|\n| auth | x | implemented | [auth.md](auth.md) |\n| billing | x | planned | [billing.md](billing.md) |\n\n## Keeping this true\n\n- x\n' > "$Y/spec/SPEC.md"
( cd "$D" && git add -A && git commit -qm spec ) >/dev/null 2>&1
run "$D"
eq "a well-formed spec without drift: exit 0" 0 "$EC"
eq "spec: 0, without a note" "spec: 0" "$(printf '%s\n' "$OUT" | grep '^spec:')"
( cd "$D" && echo b >> src/auth/login.sh && git add -A && git commit -qm "change the login" ) >/dev/null 2>&1
sed 's/^status: planned/status: shipped/' "$Y/spec/billing.md" > "$Y/spec/billing.tmp" && mv "$Y/spec/billing.tmp" "$Y/spec/billing.md"
run "$D"
eq "a lint failure and a drifted area: exit 10" 10 "$EC"
eq "spec: 2" 2 "$(count spec)"
has "the lint failure is an item" "  - lint: billing.md: status 'shipped' is not planned, partial or implemented" "$OUT"
like "the drifted area is an item" "^  - drift: auth: possible documentation impact -- 1 commit" "$OUT"
hasnt "the summary lines of the two commands are no items" "spec drift:" "$OUT"
eq "the last line counts" "2 things need a look" "$(printf '%s\n' "$OUT" | tail -1)"

# ---- 3. state ---------------------------------------------------------------------
echo "# state"
project state
sed 's/^current_milestone: none/current_milestone: banana/' "$Y/STATE.md" > "$Y/STATE.tmp" && mv "$Y/STATE.tmp" "$Y/STATE.md"
run "$D"
eq "a STATE.md with a malformed pointer: exit 10" 10 "$EC"
eq "state: 1" 1 "$(count state)"
has "the finding of the lint is the item" "  - current_milestone 'banana' is not M### or none" "$OUT"
eq "one thing, in the singular" "1 thing needs a look" "$(printf '%s\n' "$OUT" | tail -1)"

# ---- 4. gates ---------------------------------------------------------------------
echo "# gates"
project gates
cat > "$Y/M004-S02-PLAN.md" <<EOF
# M004-S02 -- Slice Plan

## Tasks

- [x] T01 -- export
- [ ] T02 -- import

## Gates

- [ ] G01 -- the operator saw the export | decides: the operator | how: opens the file | lapses: 2000-01-01
- [ ] G02 -- the load test passed | decides: the operator | how: reads the report | lapses: 2999-12-31
- [x] G03 -- a closed gate | decides: the operator | how: asked | lapses: 2000-01-01
- [ ] G05 -- due today | decides: the operator | how: asked | lapses: $(date -u +%Y-%m-%d)
EOF
printf '# M004-S02-T01 -- Task Plan\n\n## Gates\n\n- [ ] G04 -- legal agreed | decides: legal | how: by mail | lapses: when S03 merges\n' > "$Y/M004-S02-T01-PLAN.md"
run "$D"
eq "open gates: exit 10" 10 "$EC"
eq "gates: 4" 4 "$(count gates)"
has "the section says how many lapsed" "gates: 4 (1 lapsed)" "$OUT"
like "a gate whose date has passed is marked" "^  - lapsed: M004-S02-PLAN\.md:[0-9]+: G01 -- the operator saw the export \| decides: the operator \| how: opens the file \| lapses: 2000-01-01\$" "$OUT"
like "a gate with a date ahead is open" "^  - open: M004-S02-PLAN\.md:[0-9]+: G02 -- " "$OUT"
like "a gate that lapses today is still open" "^  - open: M004-S02-PLAN\.md:[0-9]+: G05 -- " "$OUT"
like "a gate without a date, in a task plan, is open" "^  - open: M004-S02-T01-PLAN\.md:5: G04 -- legal agreed .* lapses: when S03 merges\$" "$OUT"
hasnt "a closed gate is not listed" "G03" "$OUT"
hasnt "an open task is no gate" "T02" "$OUT"

# ---- 5. questions -----------------------------------------------------------------
echo "# questions"
project questions
question Q001 archived-rows open     "$(ago $((5 * DAY)))"  none                   none                   "Does the export include archived rows?"
question Q002 new-one       open     "$(ago $HOUR)"         none                   none                   "Which region?"
question Q003 retention     asked    "$(ago $((20 * DAY)))" "$(ago $((9 * DAY)))"  none                   "How long are exports kept?"
question Q004 fresh-ask     asked    "$(ago $((6 * DAY)))"  "$(ago $((2 * DAY)))"  none                   "Is the name final?"
question Q005 done          answered "$(ago $((30 * DAY)))" "$(ago $((29 * DAY)))" "$(ago $((28 * DAY)))" "Old and answered?"
run "$D"
eq "questions that wait: exit 10" 10 "$EC"
eq "questions: 2" 2 "$(count questions)"
like "open for five days and never asked" "^  - Q001: open since $STAMP, never asked \(5 days\): Does the export include archived rows\?\$" "$OUT"
like "asked nine days ago and not answered" "^  - Q003: asked $STAMP, not answered \(9 days\): How long are exports kept\?\$" "$OUT"
hasnt "an open question under the limit is not listed" "Q002" "$OUT"
hasnt "an asked question under the limit is not listed" "Q004" "$OUT"
hasnt "an answered question is not listed" "Q005" "$OUT"
run "$D" --open-days 6 --asked-days 10
eq "higher limits: nothing needs a look" "0:0" "$EC:$(count questions)"
run "$D" --open-days 0 --asked-days 1
eq "lower limits list more" 4 "$(count questions)"

# ---- 6. lanes ---------------------------------------------------------------------
echo "# lanes"
project lanes
# claim <seconds ago>: a claim time as bin/ytstack-frontier writes it (no seconds)
claim() { local t; t=$(ago "$1"); printf '%sZ' "${t%:??Z}"; }
lanes() {
  { printf -- '---\nupdated: %s\n---\n\n# Lanes\n\n' "$(ago 0)"
    echo '| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |'
    echo '|---|---|---|---|---|---|---|---|---|---|'
    printf '%s\n' "$@"
  } > "$Y/LANES.md"
}
lanes \
  "| M004-S01 | implement | merged | impl-a $(claim $((40 * HOUR))) | ytstack/M004-S01 | - | 11 | a1b2c3d | 1 | - |" \
  "| M004-S02 | implement | running | impl-b $(claim $((30 * HOUR))) | ytstack/M004-S02 | - | - | - | 0 | wait for the report |" \
  "| M004-S03 | implement | claimed | impl-c $(claim $HOUR) | - | - | - | - | 0 | - |" \
  "| review-pr-12 | review | in-review | rev-a $(ago $((72 * HOUR))) | - | - | 12 | - | 1 | read the verdict |" \
  "| M004-S04 | implement | blocked | impl-d $(claim $((90 * HOUR))) | - | - | - | - | 0 | S02 |" \
  "| M004-S05 | implement | dropped | - | - | - | - | - | 0 | - |"
run "$D"
eq "lanes without movement: exit 10" 10 "$EC"
eq "lanes: 2" 2 "$(count lanes)"
like "a running lane claimed thirty hours ago" "^  - M004-S02: running, claimed by impl-b [0-9T:-]+Z \(30 hours ago\); next: wait for the report\$" "$OUT"
like "a lane that is no slice, with seconds in its claim time" "^  - review-pr-12: in-review, claimed by rev-a $STAMP \(72 hours ago\); next: read the verdict\$" "$OUT"
hasnt "a lane claimed an hour ago is not listed" "M004-S03" "$OUT"
hasnt "a merged lane is not listed" "M004-S01" "$OUT"
hasnt "a blocked lane is not held" "M004-S04" "$OUT"
run "$D" --lane-hours 100
eq "a higher limit: nothing needs a look" "0:0" "$EC:$(count lanes)"
lanes \
  "| M004-S02 | implement | running | impl-b $(claim $((30 * HOUR))) | ytstack/M004-S02 | - | - | - | 0 |" \
  "| M004-S03 | implement | sleeping | impl-c $(claim $((30 * HOUR))) | - | - | - | - | 0 | - |"
run "$D"
eq "a table that fails the check: lanes: 2" 2 "$(count lanes)"
like "the problems of the check are the items" "^  - check: line [0-9]+: 9 cells, expected 10\$" "$OUT"
has "each one" "  - check: M004-S03: status \"sleeping\" is not one of" "$OUT"
hasnt "and its rows are not read" "hours ago" "$OUT"

# ---- 7. runtime -------------------------------------------------------------------
echo "# runtime"
project runtime
printf '# Runtime\n\n## Release\n\n- target: staging\n- settle: soon\n' > "$Y/RUNTIME.md"
run "$D"
eq "a RUNTIME.md that fails its check: exit 10" 10 "$EC"
eq "runtime: 2" 2 "$(count runtime)"
has "one item per problem" "  - Release: no deployed" "$OUT"
like "with the line where there is one" "^  - line 6: Release: settle \"soon\" is not a number of seconds\$" "$OUT"
printf '# Runtime\n\n## Release\n\n- deployed: curl -fsS https://app.example.com/version\n' > "$Y/RUNTIME.md"
run "$D"
eq "a RUNTIME.md that passes: exit 0" "0:0" "$EC:$(count runtime)"

# ---- 8. review policy: with and without bin/ytstack-risk ---------------------------
echo "# review policy"
PL="$TMP/plugin"; mkdir -p "$PL/bin" "$PL/hooks/lib"
cp -p "$ROOT/bin/ytstack-upkeep" "$ROOT/bin/ytstack-spec" "$ROOT/bin/ytstack-questions" "$ROOT/bin/ytstack-frontier" "$ROOT/bin/ytstack-runtime" "$PL/bin/"
cp -p "$ROOT/hooks/lib/git-ctx.sh" "$PL/hooks/lib/"
UP="$PL/bin/ytstack-upkeep"
project policy
mkdir -p "$Y/spec"
echo "a broken lens" > "$Y/spec/REVIEW.md"
run "$D"
eq "an installation without ytstack-risk: exit 0" 0 "$EC"
has "the section says that it was not checked" "review policy: 0 (bin/ytstack-risk is not part of this installation)" "$OUT"
cat > "$PL/bin/ytstack-risk" <<'EOF'
#!/usr/bin/env bash
# Stand-in for bin/ytstack-risk in this fixture: `check` fails on a REVIEW.md
# that holds the word "broken".
[ "${1:-}" = -C ] && [ "${3:-}" = check ] || { echo "stand-in: expected -C DIR check, got: $*" >&2; exit 64; }
if grep broken "$2/.ytstack/spec/REVIEW.md" >/dev/null 2>&1; then
  echo 'REVIEW.md: lens visual has no evidence'
  echo 'REVIEW.md: the size line is not two numbers'
  exit 1
fi
echo "review policy ok"
EOF
run "$D"
eq "a ytstack-risk that is not executable counts as missing" "0:0" "$EC:$(count "review policy")"
chmod +x "$PL/bin/ytstack-risk"
run "$D"
eq "with ytstack-risk, a REVIEW.md that fails its check: exit 10" 10 "$EC"
eq "review policy: 2" 2 "$(count "review policy")"
has "one item per problem" "  - REVIEW.md: lens visual has no evidence" "$OUT"
# A spec lint that calls ytstack-risk repeats its lines as failures of its own.
# The stand-in for bin/ytstack-spec does that, and adds one failure of its own.
cp -p "$PL/bin/ytstack-spec" "$PL/bin/ytstack-spec.real"
cat > "$PL/bin/ytstack-spec" <<'EOF'
#!/usr/bin/env bash
# Stand-in for bin/ytstack-spec in this fixture: `lint` prints the lines of
# `ytstack-risk check` as failures, as the lint that calls it does.
case "${3:-}" in
  lint)
    echo "FAIL billing.md: no frontmatter"
    "$(dirname "$0")/ytstack-risk" -C "$2" check | sed -n 's/^REVIEW/FAIL REVIEW/p'
    echo "spec lint: 1 area file(s), 3 failure(s), 0 warning(s)"; exit 1 ;;
  drift) echo "spec drift: no area to look at" ;;
esac
EOF
echo "# fx" > "$Y/spec/SPEC.md"
run "$D"
eq "a problem that the lint repeats is counted once: spec 1, review policy 2" "1:2" "$(count spec):$(count "review policy")"
has "the lint keeps its own failure" "  - lint: billing.md: no frontmatter" "$OUT"
hasnt "and does not list the policy's" "lint: REVIEW.md" "$OUT"
eq "three things then" "3 things need a look" "$(printf '%s\n' "$OUT" | tail -1)"
mv "$PL/bin/ytstack-spec.real" "$PL/bin/ytstack-spec"; rm -f "$Y/spec/SPEC.md"
echo "fine" > "$Y/spec/REVIEW.md"
run "$D"
eq "a REVIEW.md that passes: exit 0" 0 "$EC"
eq "the section carries no note then" "review policy: 0" "$(printf '%s\n' "$OUT" | grep '^review policy:')"
UP="$BIN"
if [ -e "$ROOT/bin/ytstack-risk" ] && [ ! -x "$ROOT/bin/ytstack-risk" ]; then bad "the real bin/ytstack-risk, when present, is executable"; else ok "the real bin/ was not written to"; fi

# ---- 9. --question ----------------------------------------------------------------
echo "# --question"
project ask
QS="$ROOT/bin/ytstack-questions"
question Q001 region open "$(ago $HOUR)" none none "Which region?"
sed 's/^current_milestone: none/current_milestone: banana/' "$Y/STATE.md" > "$Y/STATE.tmp" && mv "$Y/STATE.tmp" "$Y/STATE.md"
BEFORE=$(snap)
run "$D"
eq "without --question nothing is written" "$BEFORE" "$(snap)"
run "$D" --question
eq "--question keeps the exit code: 10" 10 "$EC"
F="$Y/questions/Q002-upkeep-found-1-thing-that-needs-a-look.md"
eq "the last line names the question file" "question: $F" "$(printf '%s\n' "$OUT" | tail -1)"
if [ -f "$F" ]; then ok "the file exists, with the next id"; else bad "the file exists, with the next id" "$(ls "$Y/questions")"; fi
eq "its title" "# Q002 -- Upkeep found 1 thing that needs a look" "$(grep '^# ' "$F")"
eq "it is open and for the operator" "open|the operator" "$(sed -n 's/^state: //p' "$F")|$(sed -n 's/^decides: //p' "$F")"
CONTEXT=$(awk '/^## / { on = ($0 == "## Context"); next } on' "$F")
has "the report stands under Context: the section" "state: 1" "$CONTEXT"
has "the report stands under Context: the item" "current_milestone 'banana' is not M### or none" "$CONTEXT"
like "Context says who wrote it and when" "bin/ytstack-upkeep.* $STAMP" "$CONTEXT"
eq "the other sections are still there, in order" "## Context|## Options|## Recommendation|## Answer" "$(grep '^## ' "$F" | tr '\n' '|' | sed 's/|$//')"
OUT2=$("$BASH" "$QS" -C "$D" check 2>&1); eq "ytstack-questions check passes" "0:questions ok: 2 file(s)" "$?:$OUT2"
run "$D" --question
eq "a second run: exit 10" 10 "$EC"
eq "writes no second question" 2 "$(ls "$Y/questions" | awk 'END { print NR }')"
eq "and says which one waits" "question: none written, Q002 (open) already carries an upkeep report" "$(printf '%s\n' "$OUT" | tail -1)"
"$BASH" "$QS" -C "$D" ask Q002 >/dev/null 2>&1
run "$D" --question
eq "nor while it is asked" "2|question: none written, Q002 (asked) already carries an upkeep report" "$(ls "$Y/questions" | awk 'END { print NR }')|$(printf '%s\n' "$OUT" | tail -1)"
echo "Looked at it, said the operator." >> "$F"
"$BASH" "$QS" -C "$D" answer Q002 >/dev/null 2>&1
run "$D" --question
eq "after the answer a new run writes a new question" "question: $Y/questions/Q003-upkeep-found-1-thing-that-needs-a-look.md" "$(printf '%s\n' "$OUT" | tail -1)"
eq "three files then" 3 "$(ls "$Y/questions" | awk 'END { print NR }')"

# ---- 10. review checks: merged pull requests without an escape check --------------
echo "# review checks"
project reviews
mkdir -p "$Y/spec" "$Y/signals" "$D/.github/reviewers" "$TMP/fakebin"
echo "# code reviewer" > "$D/.github/reviewers/code.md"
printf '# Review policy\n\n## Own reviewers\n\n- code | marker: (`code`) | lessons: .github/reviewers/code.md\n' > "$Y/spec/REVIEW.md"
( cd "$D" && git init -q && git remote add origin https://github.com/acme/shop.git ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }
GHLOG="$TMP/gh.log"
# A stand-in for gh: `pr list` prints the merged pull requests of $GHJSON
# (it does not apply the search; upkeep filters by mergedAt itself), `repo
# view` the repository; every call is logged. GH_FAIL makes `pr list` fail.
cat > "$TMP/fakebin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GHLOG"
case "$1 $2" in
  "pr list")
    [ -z "${GH_FAIL:-}" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }
    cat "$GHJSON" ;;
  "repo view") echo "acme/other" ;;
  *) echo "stand-in gh: unexpected $*" >&2; exit 64 ;;
esac
EOF
chmod +x "$TMP/fakebin/gh"
GHJSON="$TMP/merged.json"; export GHLOG GHJSON
M15=$(ago $DAY); M13=$(ago $((2 * DAY))); M8=$(ago $((5 * DAY / 2))); M12=$(ago $((3 * DAY))); M10=$(ago $((20 * DAY)))
CHECKED=$(ago $((3 * DAY - HOUR)))
# #8 is old by number but merged late: a window by number would miss it.
printf '[{"number":15,"mergedAt":"%s","mergeCommit":{"oid":"ffff000011112222333344445555666677778888"},"title":"Add the export"},
 {"number":13,"mergedAt":"%s","mergeCommit":{"oid":"dddd000011112222333344445555666677778888"},"title":"Fix the\\tcart"},
 {"number":12,"mergedAt":"%s","mergeCommit":{"oid":"cccc000011112222333344445555666677778888"},"title":"Checked already"},
 {"number":10,"mergedAt":"%s","mergeCommit":{"oid":"aaaa000011112222333344445555666677778888"},"title":"Before the loop"},
 {"number":8,"mergedAt":"%s","mergeCommit":{"oid":"8888000011112222333344445555666677778888"},"title":"A long-lived branch"}]\n' \
  "$M15" "$M13" "$M12" "$M10" "$M8" > "$GHJSON"
OLDPATH=$PATH; PATH="$TMP/fakebin:$PATH"
echo "acme/shop#12 cccc000011112222333344445555666677778888 $CHECKED code=1/0" > "$Y/signals/review-checks"
: > "$GHLOG"
BEFORE=$(snap)
run "$D"
eq "merged pull requests without a check: exit 10" 10 "$EC"
eq "review checks: 3" 3 "$(count "review checks")"
has "the newer unchecked one is an item" "  - acme/shop#15: merged $M15 at ffff00001111, no escape check: Add the export" "$OUT"
has "a tab in a title becomes a space" "  - acme/shop#13: merged $M13 at dddd00001111, no escape check: Fix the cart" "$OUT"
has "an old number merged after the first check is listed" "  - acme/shop#8: merged $M8 at 888800001111" "$OUT"
hasnt "a checked pull request is not listed" "acme/shop#12:" "$OUT"
hasnt "one merged more than 14 days before the earliest check is not listed" "acme/shop#10" "$OUT"
eq "one gh call, searched from 14 days before the earliest check, with the repository from origin" \
  "pr list -R acme/shop --state merged --search merged:>=$(ago $((3 * DAY - HOUR + 14 * DAY)) | cut -c1-10) --limit 500 --json number,mergedAt,mergeCommit,title" "$(cat "$GHLOG")"
eq "nothing was written" "$BEFORE" "$(snap)"
# A run that checks only the newest pull request writes a later check time;
# the window stays anchored, so the older unchecked ones are still listed.
echo "acme/shop#15 ffff000011112222333344445555666677778888 $(ago 60) code=0/0" >> "$Y/signals/review-checks"
run "$D"
has "after checking the newest: #13 still listed" "acme/shop#13: merged" "$OUT"
has "after checking the newest: #8 still listed" "acme/shop#8: merged" "$OUT"
hasnt "and #15 is gone" "acme/shop#15:" "$OUT"
# At MERGED_LIMIT the list is cut, and the report says so.
jq '[range(500) as $i | .[0] + {number: (1000 + $i)}]' "$GHJSON" > "$TMP/many.json"
GHJSON="$TMP/many.json" run "$D"
has "a list cut at the limit is named" "500 merged pull requests since" "$OUT"
rm -f "$Y/signals/review-checks"
: > "$GHLOG"
run "$D"
eq "without any check line: the last 14 days" 4 "$(count "review checks")"
hasnt "and not what merged before them" "acme/shop#10" "$OUT"
eq "searched from 14 days ago" "merged:>=$(ago $((14 * DAY)) | cut -c1-10)" "$(sed -n 's/.*--search \([^ ]*\) .*/\1/p' "$GHLOG")"
git -C "$D" remote set-url origin git@gitlab.example.com:acme/shop.git
: > "$GHLOG"
run "$D"
eq "origin on another host: gh names the repository, two calls" "2|repo view --json nameWithOwner -q .nameWithOwner" "$(awk 'END { print NR }' "$GHLOG")|$(sed -n 1p "$GHLOG")"
has "and the items carry its name" "  - acme/other#15: " "$OUT"
GH_FAIL=1; export GH_FAIL
run "$D"
unset GH_FAIL
eq "a read that fails is one item" 1 "$(count "review checks")"
has "with gh's message" "  - check: gh could not list the merged pull requests of acme/other: HTTP 502: bad gateway" "$OUT"
rm -f "$Y/spec/REVIEW.md"
: > "$GHLOG"
run "$D"
eq "without own reviewers: no host call" "0|0" "$(count "review checks")|$(awk 'END { print NR }' "$GHLOG")"
PATH=$OLDPATH

# ---- 11. usage and errors ---------------------------------------------------------
echo "# usage"
project usage
run "$D" --forever;            eq "an unknown flag: exit 64" 64 "$EC"
run "$D" --open-days soon;     eq "a limit that is no number: exit 64" 64 "$EC"
run "$D" --lane-hours;         eq "a limit without a value: exit 64" 64 "$EC"
run "$TMP/nowhere";            eq "-C to a missing directory: exit 64" 64 "$EC"
mkdir -p "$TMP/bare"
run "$TMP/bare" --question;    eq "no .ytstack directory: exit 1" 1 "$EC"
has "and says so" "no .ytstack directory" "$OUT"
if [ ! -e "$TMP/bare/.ytstack" ]; then ok "and creates none"; else bad "and creates none"; fi
run "$D" --help;               eq "--help: exit 0" 0 "$EC"
has "--help prints the usage line" "ytstack-upkeep [-C DIR] [--question]" "$OUT"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
