#!/usr/bin/env bash
# Tests for bin/ytstack-questions: the queue of what only the human can decide
# (.ytstack/questions/Q###-<slug>.md, format in docs/ux/coordinator-format.md).
#
# Contract:
#   new     the next id after the highest one, a slug from the question, the
#           frontmatter and the four sections of the format (Context with
#           empty Source: and Purpose: lines); --decides needs --because, one
#           item of PREFERENCES escalate or "reserved" (class escalation);
#           --info WHO writes class info (issue #78)
#   list    one tab separated line per file; open and asked by default,
#           one state with --state
#   next    the oldest open question; exit 1 when none is open
#   ask     state asked with its time, once, and only with a Context that
#           names its source and purpose
#   answer  state answered with its time, only with text under "## Answer"
#   check   well-formed files pass; each defect is named, exit 1; without the
#           directory "no questions", exit 0
#
# Run: /bin/bash tests/ytstack-questions.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-questions"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-questions exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytquestions.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
TAB=$(printf '\t')
UTC='20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'

# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
# project <name>: a directory with an empty .ytstack. Sets D and Q (its questions directory).
project() { D="$TMP/$1"; Q="$D/.ytstack/questions"; mkdir -p "$D/.ytstack"; }
# edit <file> <sed expression>
edit() { sed "$2" "$1" > "$1.tmp" && cat "$1.tmp" > "$1" && rm -f "$1.tmp"; }
# fill <file>: give the Context its source and purpose, so that ask accepts it
fill() { edit "$1" 's/^Source:$/Source: plan line 12/; s/^Purpose:$/Purpose: unblocks the export lane/'; }
# field <file> <key>: a frontmatter value, read without the tool
field() { sed -n "s/^$2: //p" "$1" | sed -n 1p; }
# is_utc <text>
# shellcheck disable=SC2254
is_utc() { case "$1" in $UTC) return 0 ;; *) return 1 ;; esac; }

# ---- 1. nothing there ---------------------------------------------------------
echo "# no questions directory"
project empty
run "$D" check; eq "check without the directory: exit 0" 0 "$EC"; eq "and says so" "no questions" "$OUT"
run "$D" list;  eq "list without the directory: exit 0" 0 "$EC"; eq "and prints nothing" "" "$OUT"
run "$D" next;  eq "next without a question: exit 1" 1 "$EC"
run "$D" ask Q001; eq "ask for an unknown id: exit 1" 1 "$EC"
mkdir -p "$TMP/bare"
run "$TMP/bare" new --question "Anything?" --decides "the operator" --because reserved
eq "new without a .ytstack directory: exit 1" 1 "$EC"
if [ ! -e "$TMP/bare/.ytstack" ]; then ok "and creates none"; else bad "and creates none"; fi
run "$TMP/nowhere" list; eq "-C to a missing directory: exit 64" 64 "$EC"
run "$D" publish;        eq "unknown command: exit 64" 64 "$EC"

# ---- 2. new -------------------------------------------------------------------
echo "# new"
project new
run "$D" new --question "Does the export include archived rows?" --decides "the operator" --because deviation --blocks "M004-S03, G02"
eq "new writes a question" 0 "$EC"
F1="$Q/Q001-does-the-export-include-archived-rows.md"
eq "the first id is Q001, the slug comes from the question" "$F1" "$OUT"
eq "frontmatter and empty sections follow the format" "---
id: Q001
state: open
class: escalation
decides: the operator
because: deviation
opened: T
asked: none
answered: none
blocks: M004-S03, G02
---

# Q001 -- Does the export include archived rows?

## Context

Source:
Purpose:

## Options

## Recommendation

## Answer" "$(sed 's/^opened: .*/opened: T/' "$F1")"
if is_utc "$(field "$F1" opened)"; then ok "opened is a UTC time"; else bad "opened is a UTC time" "$(field "$F1" opened)"; fi

run "$D" new --decides "Kim (legal)" --because reserved --question "Is the old
 retention period   still binding?"
eq "the second question is Q002" "$Q/Q002-is-the-old-retention-period-still-binding.md" "$OUT"
F2="$OUT"
eq "without --blocks nothing is blocked" "none" "$(field "$F2" blocks)"
eq "a question over several lines becomes one heading" "# Q002 -- Is the old retention period still binding?" "$(grep '^# ' "$F2")"

sed 's/^id: Q001/id: Q007/; s/^# Q001/# Q007/' "$F1" > "$Q/Q007-a-later-one.md"
run "$D" new --question "What comes after seven?" --decides "the operator" --because spend
eq "numbering continues after the highest id, gaps stay" "$Q/Q008-what-comes-after-seven.md" "$OUT"
run "$D" new --question "Should the weekly digest for administrators of very large tenants also list members who never logged in?" --decides "the operator" --because violation
SLUG=$(basename "$OUT" .md); SLUG=${SLUG#Q009-}
if [ "${#SLUG}" -le 48 ] && [ "${SLUG%-}" = "$SLUG" ] && [ -f "$OUT" ]; then ok "a long question gives a slug of at most 48 characters"; else bad "a long question gives a slug of at most 48 characters" "$SLUG"; fi
run "$D" new --question "???" --decides "the operator" --because secret
eq "a question without letters still gets a file name" "$Q/Q010-question.md" "$OUT"
run "$D" new --question "No one named";              eq "no --decides: exit 64" 64 "$EC"
run "$D" new --decides "the operator" --because reserved; eq "no --question: exit 64" 64 "$EC"
run "$D" new --question "x" --decides;               eq "an option without a value: exit 64" 64 "$EC"
run "$D" check
eq "the files new wrote pass the check" 0 "$EC"
eq "and are counted" "questions ok: 6 file(s)" "$OUT"

# ---- 2b. who decides (issue #78) ------------------------------------------------
echo "# who decides"
project who
run "$D" new --question "Rename the column?" --decides "the operator"
eq "--decides without --because: exit 64" 64 "$EC"
has "and names the list" "--because <violation|deviation|irreversible|secret|spend|reserved>" "$OUT"
has "and the default" "decide it yourself and record it in DECISIONS.md" "$OUT"
if [ ! -d "$Q" ]; then ok "and writes nothing"; else bad "and writes nothing" "$(ls "$Q")"; fi
run "$D" new --question "Rename the column?" --decides "the operator" --because taste
eq "--because outside the list: exit 64" 64 "$EC"
has "and names the value" "'taste' is not on the escalation list" "$OUT"
run "$D" new --question "Rename the column?" --decides "the operator" --because irreversible
eq "--because irreversible: exit 0" 0 "$EC"
eq "class escalation with the item" "escalation|irreversible|the operator" "$(field "$OUT" class)|$(field "$OUT" because)|$(field "$OUT" decides)"
run "$D" new --question "Where does the deploy token come from?" --info "the operator" --blocks lane-7
eq "--info: exit 0" 0 "$EC"
eq "class info, no item, the person asked" "info|none|the operator|lane-7" "$(field "$OUT" class)|$(field "$OUT" because)|$(field "$OUT" decides)|$(field "$OUT" blocks)"
run "$D" new --question "x" --info "the operator" --because secret;  eq "--info with --because: exit 64" 64 "$EC"
run "$D" new --question "x" --info "a" --decides "b" --because secret; eq "--info with --decides: exit 64" 64 "$EC"
printf 'escalate: violation, secret   # what goes to a person\n' > "$D/.ytstack/PREFERENCES.md"
run "$D" new --question "Buy the bigger runner?" --decides "the operator" --because spend
eq "an item the project does not escalate: exit 64" 64 "$EC"
has "and the list comes from PREFERENCES" "--because <violation|secret|reserved>" "$OUT"
run "$D" new --question "Rotate the key?" --decides "the operator" --because secret
eq "an item on the project's list: exit 0" 0 "$EC"
run "$D" new --question "Ship it?" --decides "the operator" --because reserved
eq "reserved is always on the list" 0 "$EC"
printf 'escalate: violation, everything\n' > "$D/.ytstack/PREFERENCES.md"
run "$D" new --question "Buy the bigger runner?" --decides "the operator" --because spend
eq "an invalid escalate reads as the full list" 0 "$EC"
rm -f "$D/.ytstack/PREFERENCES.md"
run "$D" check
eq "the files of both classes pass the check" "questions ok: 5 file(s)" "$OUT"

# ---- 3. list, next, ask, answer -----------------------------------------------
echo "# list, next, ask, answer"
project flow
run "$D" new --question "First one?" --decides "the operator" --because deviation --blocks "M001-S01";  A="$OUT"
run "$D" new --question "Second one?" --decides "Kim" --because reserved;                              B="$OUT"
run "$D" new --question "Third one?" --info "the operator";                                            C="$OUT"
run "$D" list
eq "list: id, state, decides, blocks, question, tab separated" "Q001${TAB}open${TAB}the operator${TAB}M001-S01${TAB}First one?
Q002${TAB}open${TAB}Kim${TAB}none${TAB}Second one?
Q003${TAB}open${TAB}the operator${TAB}none${TAB}Third one?" "$OUT"

run "$D" next
eq "next: the lowest id among equally old ones" "Q001${TAB}$A" "$OUT"
edit "$B" 's/^opened: .*/opened: 2020-01-01T00:00:00Z/'
run "$D" next
eq "next: the oldest open one, by its opened time" "Q002${TAB}$B" "$OUT"

# The Context gate (issue #78): a question names where it comes from and what it is for.
run "$D" ask Q002
eq "ask with an empty Context is refused" 1 "$EC"
has "and names what is missing" "its Context names no source and no purpose" "$OUT"
eq "the state stays open" "open" "$(field "$B" state)"
edit "$B" 's/^Source:$/Source: <where the need comes from>/; s/^Purpose:$/Purpose:   /'
run "$D" ask Q002
eq "a placeholder or blanks are no source and no purpose" "1|open" "$EC|$(field "$B" state)"
edit "$B" 's/^Source: .*/Source: plan line 12/'
run "$D" ask Q002
eq "a source without a purpose is refused" 1 "$EC"
has "and the purpose is named" "its Context names no purpose" "$OUT"
edit "$B" 's/^Purpose: .*/Purpose:/'
printf 'Purpose: unblocks the export lane\n' >> "$B"
run "$D" ask Q002
eq "a Purpose line outside Context does not count" 1 "$EC"
has "and the purpose is still missing" "its Context names no purpose" "$OUT"
edit "$B" '$d'; edit "$B" 's/^Source: .*/Source:/'
fill "$B"

BEFORE=$(grep -v '^state: \|^asked: ' "$B")
run "$D" ask Q002
eq "ask: exit 0" 0 "$EC"
eq "ask sets the state" "asked" "$(field "$B" state)"
if is_utc "$(field "$B" asked)"; then ok "ask sets the time"; else bad "ask sets the time" "$(field "$B" asked)"; fi
eq "ask changes nothing else" "$BEFORE" "$(grep -v '^state: \|^asked: ' "$B")"
edit "$B" 's/^asked: .*/asked: 2020-01-02T00:00:00Z/'
run "$D" ask Q002
eq "ask twice is refused" 1 "$EC"
has "and says why" "a question is asked once" "$OUT"
eq "the first time stays" "2020-01-02T00:00:00Z" "$(field "$B" asked)"
run "$D" next
eq "next skips the asked one" "Q001${TAB}$A" "$OUT"
run "$D" ask Q042;  eq "ask for an unknown id: exit 1" 1 "$EC"
run "$D" ask seven; eq "ask for something that is no id: exit 1" 1 "$EC"

run "$D" answer Q002
eq "answer without text under Answer is refused" 1 "$EC"
has "and says what is missing" "no text under '## Answer'" "$OUT"
eq "the state stays" "asked" "$(field "$B" state)"
printf '\n<Empty until answered.>\n' >> "$B"
run "$D" answer Q002
eq "a placeholder is not an answer" 1 "$EC"
edit "$B" '/^<Empty until answered.>$/d'
printf 'Yes, ten years. Kim, 2026-11-13, DECISIONS.md "Retention".\n' >> "$B"
run "$D" answer Q002
eq "answer with text: exit 0" 0 "$EC"
eq "answer sets the state" "answered" "$(field "$B" state)"
if is_utc "$(field "$B" answered)"; then ok "answer sets the time"; else bad "answer sets the time" "$(field "$B" answered)"; fi
eq "the asked time stays" "2020-01-02T00:00:00Z" "$(field "$B" asked)"
has "the answer text stays" 'Yes, ten years. Kim, 2026-11-13, DECISIONS.md "Retention".' "$(cat "$B")"
run "$D" answer Q002
eq "answer twice is refused" 1 "$EC"

printf 'No. The operator, 2026-11-13.\n' >> "$C"
run "$D" answer Q003
eq "a question answered before it was asked: exit 0" 0 "$EC"
eq "and no asking is invented" "none" "$(field "$C" asked)"
run "$D" ask Q003; eq "an answered question is not asked" 1 "$EC"

fill "$A"
run "$D" ask Q001
run "$D" list
eq "list: open and asked by default, answered left out" "Q001${TAB}asked${TAB}the operator${TAB}M001-S01${TAB}First one?" "$OUT"
run "$D" list --state answered
eq "list --state answered" "Q002${TAB}answered${TAB}Kim${TAB}none${TAB}Second one?
Q003${TAB}answered${TAB}the operator${TAB}none${TAB}Third one?" "$OUT"
eq "an asked question keeps its class" "escalation|deviation" "$(field "$A" class)|$(field "$A" because)"
run "$D" list --state open;    eq "list --state open: none left" "" "$OUT"
run "$D" list --state closed;  eq "list --state with an unknown state: exit 64" 64 "$EC"
run "$D" next;                 eq "next: exit 1 when none is open" 1 "$EC"
run "$D" check
eq "open, asked and answered files pass the check" "questions ok: 3 file(s)" "$OUT"

# ---- 4. check: each defect on its own -----------------------------------------
echo "# check: defects"
N=0
# fresh: a new project with one well-formed question. Sets D, Q and F.
fresh() {
  N=$((N + 1)); project "d$N"
  run "$D" new --question "Does it hold?" --decides "the operator" --because deviation; F="$OUT"
}
# defect <case> <text>: check fails and names <text>
defect() {
  run "$D" check
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC: $OUT"; fi
}
NAME="Q001-does-it-hold.md"

fresh; edit "$F" 's/^id: Q001/id: Q009/'
defect "an id that differs from the file name" "$NAME: id 'Q009' does not match the file name"
fresh; cp "$F" "$Q/Q001-a-second-file.md"
defect "an id used twice" "the id Q001 is used by more than one file"
fresh; edit "$F" 's/^state: open/state: pending/'
defect "a state outside the three" "$NAME: state 'pending' is not open, asked or answered"
fresh; edit "$F" 's/^asked: none/asked: 2026-11-13T09:00:00Z/'
defect "open with an asked time" "$NAME: state open, but asked is '2026-11-13T09:00:00Z'"
fresh; edit "$F" 's/^answered: none/answered: 2026-11-13T09:00:00Z/'
defect "open with an answered time" "$NAME: state open, but answered is '2026-11-13T09:00:00Z'"
fresh; edit "$F" 's/^state: open/state: asked/'
defect "asked without its time" "$NAME: state asked, but asked is not set"
fresh; edit "$F" 's/^state: open/state: asked/; s/^asked: none/asked: 2026-11-13T09:00:00Z/; s/^answered: none/answered: 2026-11-13T10:00:00Z/'
defect "asked with an answered time" "$NAME: state asked, but answered is '2026-11-13T10:00:00Z'"
fresh; printf 'Yes.\n' >> "$F"; edit "$F" 's/^state: open/state: answered/'
defect "answered without its time" "$NAME: state answered, but answered is not set"
fresh; edit "$F" 's/^state: open/state: answered/; s/^answered: none/answered: 2026-11-13T10:00:00Z/'
defect "answered without text under Answer" "$NAME: state answered, but there is no text under '## Answer'"
fresh; edit "$F" '1d'
defect "a file without frontmatter" "$NAME: no frontmatter"
fresh; cp "$F" "$Q/notes.md"
defect "a file name outside Q###-<slug>.md" "notes.md: the name is not Q###-<slug>.md"
eq "one line per problem" 1 "$(printf '%s\n' "$OUT" | grep -c .)"
fresh; edit "$F" 's/^class: escalation/class: urgent/'
defect "a class outside the two" "$NAME: class 'urgent' is not escalation or info"
fresh; edit "$F" 's/^because: deviation/because: none/'
defect "an escalation without its item" "$NAME: class escalation, but because is not set"
fresh; edit "$F" 's/^because: deviation/because: taste/'
defect "an item outside the list" "$NAME: because 'taste' is not violation|deviation|irreversible|secret|spend|reserved"

# Files from before issue #78 have no class and no because: they stay valid and
# read as escalation; ask still wants a source and a purpose.
fresh; edit "$F" '/^class: /d; /^because: /d'
run "$D" check
eq "a question without class and because passes the check" "0|questions ok: 1 file(s)" "$EC|$OUT"
edit "$F" '/^Source:$/d; /^Purpose:$/d'
edit "$F" 's/^## Context$/## Context\
\
The export job drops archived rows./'
run "$D" ask Q001
eq "an old file with a Context in prose only is not asked" "1|open" "$EC|$(field "$F" state)"
edit "$F" 's/^The export job drops archived rows.$/Source: plan line 12\
Purpose: unblocks the export lane/'
run "$D" ask Q001
eq "with the two lines it is asked" "0|asked" "$EC|$(field "$F" state)"
run "$D" check
eq "and still passes the check" 0 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
