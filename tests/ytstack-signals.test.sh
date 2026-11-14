#!/usr/bin/env bash
# Tests for bin/ytstack-signals: what production reported, recorded once
# (.ytstack/signals/F###-<slug>.md, format in docs/ux/signal-format.md).
#
# Contract:
#   new     decides by the key. No finding has it: the next id after the highest
#           one, a slug from the title, the frontmatter and the three sections.
#           An open or planned finding has it: last_seen and count change, the
#           sighting is appended, the newest five stay. A dismissed one:
#           last_seen and count change. A fixed one: a new finding that reopens
#           it. The first word printed names the case, then the id and the path.
#           Two calls with one key at the same time give one file.
#   list    one tab separated line per finding; open and planned by default,
#           one state or all with --state
#   set     changes the state; planned needs a reference, dismissed a reason on
#           stdin; only the newest finding of a key leaves fixed
#   incident new   the skeleton of a record, incidents/<YYYY-MM-DD>-<slug>.md;
#           a record of that day with that title is never overwritten
#   incident list  one tab separated line per record; the ones that are not
#           closed by default
#   check   well-formed files pass; each defect of a finding and of an incident
#           record is named, exit 1; a mitigation that is not declined names a
#           script that exists and passes ytstack-handover check; without both
#           directories "no signals", exit 0
#
# Run: /bin/bash tests/ytstack-signals.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-signals"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-signals exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytsignals.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
TAB=$(printf '\t')
T1=2026-11-13T09:15:02Z

# run <dir> <args...>: nothing on stdin. Sets OUT (stdout + stderr) and EC.
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1 < /dev/null); EC=$?; }
# feed <text> <dir> <args...>: <text> on stdin.
feed() { local in="$1" d="$2"; shift 2; OUT=$(printf '%s\n' "$in" | bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
# see <dir> <key> [<title>]: one sighting of a key from the source "errors".
see() { feed "line of $2" "$1" new --source errors --key "$2" --kind errors --title "${3:-Finding $2}"; }
# project <name>: a directory with an empty .ytstack. Sets D and S (its signals directory).
project() { D="$TMP/$1"; S="$D/.ytstack/signals"; mkdir -p "$D/.ytstack"; }
# edit <file> <sed expression>
edit() { sed "$2" "$1" > "$1.tmp" && cat "$1.tmp" > "$1" && rm -f "$1.tmp"; }
# field <file> <key>: a frontmatter value, read without the tool
field() { sed -n "s/^$2: //p" "$1" | sed -n 1p; }
# path: the path of the finding the last call printed (third word to the end of the line)
path() { printf '%s\n' "$OUT" | sed -n '1s/^[a-z-]* F[0-9]* //p'; }
# sightings <file>: how many sightings a finding keeps
sightings() { grep -c '^### read ' "$1"; }
is_utc() {
  case "$1" in 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) return 0 ;; esac
  return 1
}

# ---- 1. nothing there ---------------------------------------------------------
echo "# no signals directory"
project empty
run "$D" check; eq "check without the directory: exit 0" 0 "$EC"; eq "and says so" "no signals" "$OUT"
run "$D" list;  eq "list without the directory: exit 0" 0 "$EC"; eq "and prints nothing" "" "$OUT"
run "$D" set F001 --state fixed; eq "set for an unknown id: exit 1" 1 "$EC"
mkdir -p "$TMP/bare"
see "$TMP/bare" errors:1
eq "new without a .ytstack directory: exit 1" 1 "$EC"
if [ ! -e "$TMP/bare/.ytstack" ]; then ok "and creates none"; else bad "and creates none"; fi
run "$TMP/nowhere" list; eq "-C to a missing directory: exit 64" 64 "$EC"
run "$D" publish;        eq "unknown command: exit 64" 64 "$EC"
run "$D" help;           has "help lists the commands" "ytstack-signals [-C DIR] new --source NAME" "$OUT"

# ---- 2. new: a key nobody has -------------------------------------------------
echo "# new"
project new
printf '# Runtime\n\n## Signals\n\n- errors | read: true | kind: errors | scope: the web app\n- latency | read: true | kind: performance\n' > "$D/.ytstack/RUNTIME.md"
feed "4812${TAB}TypeError: cart is undefined (checkout.ts:88)${TAB}new${TAB}events=37" "$D" \
  new --source errors --key errors:4812 --title "TypeError in checkout: cart is undefined" --read-at "$T1"
eq "new writes a finding" 0 "$EC"
F1="$S/F001-typeerror-in-checkout-cart-is-undefined.md"
eq "the first word is the case, then the id and the path; the slug comes from the title" "new F001 $F1" "$OUT"
eq "frontmatter and sections follow the format" "---
id: F001
key: errors:4812
source: errors
kind: errors
state: open
first_seen: $T1
last_seen: $T1
count: 1
ref: none
reopens: none
---

# F001 -- TypeError in checkout: cart is undefined

## What was seen

### read $T1

    4812${TAB}TypeError: cart is undefined (checkout.ts:88)${TAB}new${TAB}events=37

## Assessment

## Next" "$(cat "$F1")"
run "$D" check; eq "the file new wrote passes the check" "signals ok: 1 finding(s), 0 incident(s)" "$OUT"

feed "/api/export p95=2400ms breach" "$D" new --source latency --key latency:/api/export --title "Export is
 slow   again"
eq "the second finding is F002" "new F002 $S/F002-export-is-slow-again.md" "$OUT"
F2=$(path)
eq "the kind comes from the declared source" "performance" "$(field "$F2" kind)"
eq "a title over several lines becomes one heading" "# F002 -- Export is slow again" "$(grep '^# ' "$F2")"
if is_utc "$(field "$F2" first_seen)"; then ok "without --read-at the time of the call counts, in UTC"; else bad "without --read-at the time of the call counts, in UTC" "$(field "$F2" first_seen)"; fi
eq "first_seen and last_seen start equal" "$(field "$F2" first_seen)" "$(field "$F2" last_seen)"

feed "x" "$D" new --source pager --key pager:1 --title "From nowhere"
eq "a source that Signals does not declare needs --kind: exit 1" 1 "$EC"
has "and says so" "pass --kind" "$OUT"
feed "x" "$D" new --source pager --key pager:1 --title "From a pager" --kind alerts
eq "with --kind it is recorded" "new F003 $S/F003-from-a-pager.md" "$OUT"
feed "x" "$D" new --source errors --key errors:9 --title "Kind given" --kind logs
eq "a given --kind wins over the declared one" "logs" "$(field "$(path)" kind)"

sed 's/^id: F001/id: F007/; s/^# F001/# F007/; s/^key: .*/key: errors:seven/' "$F1" > "$S/F007-a-later-one.md"
see "$D" errors:8 "What comes after seven"
eq "numbering continues after the highest id, gaps stay" "new F008 $S/F008-what-comes-after-seven.md" "$OUT"
see "$D" errors:long "The weekly digest for administrators of very large tenants lists members who never logged in"
SLUG=$(basename "$(path)" .md); SLUG=${SLUG#F009-}
if [ "${#SLUG}" -le 48 ] && [ "${SLUG%-}" = "$SLUG" ] && [ -f "$(path)" ]; then ok "a long title gives a slug of at most 48 characters"; else bad "a long title gives a slug of at most 48 characters" "$SLUG"; fi
see "$D" errors:q "???"
eq "a title without letters still gets a file name" "new F010 $S/F010-finding.md" "$OUT"

feed "$(i=0; while [ $i -lt 25 ]; do i=$((i + 1)); printf 'frame %s\r\n\n' "$i"; done)" "$D" new --source errors --key errors:trace --title "A long trace"
FT=$(path)
eq "of one sighting the first twenty lines are kept, without blank lines" 21 "$(grep -c '^    ' "$FT")"
has "and the cut is named" "    (5 more lines not recorded)" "$(cat "$FT")"
hasnt "carriage returns are dropped" "$(printf '\r')" "$(cat "$FT")"

N0=$(ls "$S" | grep -c .)
feed "" "$D" new --source errors --key errors:none --title "No sighting"
eq "an empty sighting: exit 1" 1 "$EC"
has "and says what is missing" "no sighting on stdin" "$OUT"
run "$D" new --source errors --key errors:none --title "No sighting"
eq "no stdin at all: exit 1" 1 "$EC"
feed "x" "$D" new --source errors --key "two words" --title "Bad key";       eq "a key with a space: exit 64" 64 "$EC"
feed "x" "$D" new --source Errors --key errors:x --title "Bad source";       eq "a source that is no lowercase slug: exit 64" 64 "$EC"
feed "x" "$D" new --source -errors --key errors:x --title "Bad source";      eq "a source that starts with a dash: exit 64" 64 "$EC"
feed "x" "$D" new --source errors --key errors:x --title "Bad kind" --kind crash;  eq "a kind outside the four: exit 64" 64 "$EC"
feed "x" "$D" new --source errors --key errors:x --title "Bad time" --read-at "2026-11-13 09:15"; eq "a read time that is no UTC time: exit 64" 64 "$EC"
feed "x" "$D" new --source errors --key errors:x;                            eq "no --title: exit 64" 64 "$EC"
feed "x" "$D" new --key errors:x --title "No source";                        eq "no --source: exit 64" 64 "$EC"
feed "x" "$D" new --source errors --title "No key";                          eq "no --key: exit 64" 64 "$EC"
feed "x" "$D" new --source errors --key errors:x --title;                    eq "an option without a value: exit 64" 64 "$EC"
eq "none of the refused calls wrote a file" "$N0" "$(ls "$S" | grep -c .)"
run "$D" check
eq "everything new wrote passes the check" "signals ok: $N0 finding(s), 0 incident(s)" "$OUT"

# ---- 3. new: the key of an open or planned finding ----------------------------
echo "# seen again"
project again
feed "first" "$D" new --source errors --key errors:4812 --kind errors --title "Cart is undefined" --read-at "$T1"
A=$(path)
printf '%s\n' "$(sed 's/^## Assessment$/&\
\
The source marks it as new./' "$A")" > "$A"
feed "second" "$D" new --source errors --key errors:4812 --kind errors --title "Another title" --read-at 2026-11-14T09:15:04Z
eq "a second sighting of the key: no new file, the case is seen-again" "seen-again F001 $A" "$OUT"
eq "one file" 1 "$(ls "$S" | grep -c .)"
eq "count rose" 2 "$(field "$A" count)"
eq "last_seen is the new read time" "2026-11-14T09:15:04Z" "$(field "$A" last_seen)"
eq "first_seen stays" "$T1" "$(field "$A" first_seen)"
eq "the sighting is appended under What was seen, in order" "## What was seen

### read $T1

    first

### read 2026-11-14T09:15:04Z

    second

## Assessment

The source marks it as new.

## Next" "$(sed -n '/^## What was seen/,$p' "$A")"
eq "the title stays" "# F001 -- Cart is undefined" "$(grep '^# ' "$A")"
feed "late" "$D" new --source errors --key errors:4812 --kind errors --title x --read-at 2026-11-12T00:00:00Z
eq "a sighting read earlier does not move last_seen back" "2026-11-14T09:15:04Z" "$(field "$A" last_seen)"
eq "but it counts" 3 "$(field "$A" count)"
for i in 4 5 6 7; do feed "sighting $i" "$D" new --source errors --key errors:4812 --kind errors --title x --read-at "2026-11-1${i}T10:00:00Z"; done
eq "seven sightings counted" 7 "$(field "$A" count)"
eq "the newest five are kept" 5 "$(sightings "$A")"
hasnt "the oldest one is gone" "    first" "$(cat "$A")"
has "the newest one is there" "    sighting 7" "$(cat "$A")"
has "the assessment survived every rewrite" "The source marks it as new." "$(cat "$A")"
run "$D" set F001 --state planned --ref M004-S02-T03
feed "while planned" "$D" new --source errors --key errors:4812 --kind errors --title x
eq "a planned finding is seen again as well" "seen-again F001 $A" "$OUT"
eq "and stays planned" "planned" "$(field "$A" state)"
run "$D" check; eq "the file still passes the check" "signals ok: 1 finding(s), 0 incident(s)" "$OUT"

# ---- 4. new: the key of a dismissed finding -----------------------------------
echo "# dismissed"
project dismissed
see "$D" errors:bot "Bot probes wp-login"; B=$(path)
run "$D" set F001 --state dismissed
eq "dismissed without a reason on stdin: exit 1" 1 "$EC"
has "and says what is missing" "dismissed needs a reason on stdin" "$OUT"
eq "the state stays" "open" "$(field "$B" state)"
feed "Scanner noise,
 there is no WordPress here." "$D" set F001 --state dismissed
eq "dismissed with a reason: exit 0" "0 F001 dismissed" "$EC $OUT"
eq "the state is dismissed" "dismissed" "$(field "$B" state)"
REASON=$(sed -n '/^## Assessment/,/^## Next/p' "$B" | grep '^- ')
has "the reason stands under Assessment, on one line" " -- dismissed: Scanner noise, there is no WordPress here." "$REASON"
if is_utc "$(printf '%s' "$REASON" | sed 's/^- \([^ ]*\) .*/\1/')"; then ok "with its time"; else bad "with its time" "$REASON"; fi
BEFORE=$(grep -v '^last_seen: \|^count: ' "$B")
feed "again" "$D" new --source errors --key errors:bot --kind errors --title x --read-at 2031-01-01T00:00:00Z
eq "a sighting of a dismissed key: the case is dismissed, no new file" "dismissed F001 $B" "$OUT"
eq "one file" 1 "$(ls "$S" | grep -c .)"
eq "it stays dismissed" "dismissed" "$(field "$B" state)"
eq "count rose" 2 "$(field "$B" count)"
eq "last_seen moved" "2031-01-01T00:00:00Z" "$(field "$B" last_seen)"
eq "nothing else changed: the sighting is not kept" "$BEFORE" "$(grep -v '^last_seen: \|^count: ' "$B")"
run "$D" check; eq "a dismissed finding with its reason passes the check" "signals ok: 1 finding(s), 0 incident(s)" "$OUT"

# ---- 5. new: the key of a fixed finding ---------------------------------------
echo "# regression"
project regression
see "$D" errors:4812 "Cart is undefined"; R1=$(path)
run "$D" set F001 --state fixed
eq "set fixed: exit 0" "0 F001 fixed" "$EC $OUT"
OLD=$(cat "$R1")
see "$D" errors:4812 "Cart is undefined again"
eq "a sighting of a fixed key: a new finding, the case is regression" "regression F002 $S/F002-cart-is-undefined-again.md" "$OUT"
R2=$(path)
eq "it names the finding it reopens" "F001" "$(field "$R2" reopens)"
eq "it is open with count 1" "open 1" "$(field "$R2" state) $(field "$R2" count)"
eq "the fixed finding is untouched" "$OLD" "$(cat "$R1")"
see "$D" errors:4812
eq "the newest finding of the key decides: the regression is seen again" "seen-again F002 $R2" "$OUT"
run "$D" set F001 --state open
eq "the older finding of a key cannot leave fixed: exit 1" 1 "$EC"
has "and names the newer one" "F002 (open) carries the same key" "$OUT"
eq "its state stays" "fixed" "$(field "$R1" state)"
run "$D" set F002 --state fixed
see "$D" errors:4812 "Third time"
eq "a regression of the regression reopens the newest fixed one" "regression F003 F002" "$(printf '%s' "$OUT" | cut -d' ' -f1,2) $(field "$(path)" reopens)"
run "$D" set F003 --state fixed
run "$D" set F002 --state open
eq "nor can it while the newer one is fixed as well" 1 "$EC"
has "and names it" "F003 (fixed) carries the same key" "$OUT"
run "$D" check; eq "the chain passes the check" "signals ok: 3 finding(s), 0 incident(s)" "$OUT"

# ---- 6. list and set ----------------------------------------------------------
echo "# list, set"
project flow
feed "a" "$D" new --source errors --key errors:a --kind errors --title "First" --read-at "$T1";       FA=$(path)
feed "b" "$D" new --source latency --key latency:b --kind performance --title "Second" --read-at "$T1"; FB=$(path)
feed "c" "$D" new --source errors --key errors:c --kind errors --title "Third" --read-at "$T1"
feed "d" "$D" new --source errors --key errors:d --kind errors --title "Fourth" --read-at "$T1"
run "$D" list
eq "list: id, state, source, kind, count, last_seen, ref, reopens, key, title, tab separated" "F001${TAB}open${TAB}errors${TAB}errors${TAB}1${TAB}$T1${TAB}none${TAB}none${TAB}errors:a${TAB}First
F002${TAB}open${TAB}latency${TAB}performance${TAB}1${TAB}$T1${TAB}none${TAB}none${TAB}latency:b${TAB}Second
F003${TAB}open${TAB}errors${TAB}errors${TAB}1${TAB}$T1${TAB}none${TAB}none${TAB}errors:c${TAB}Third
F004${TAB}open${TAB}errors${TAB}errors${TAB}1${TAB}$T1${TAB}none${TAB}none${TAB}errors:d${TAB}Fourth" "$OUT"

run "$D" set F002 --state planned
eq "planned without a reference: exit 1" 1 "$EC"
has "and says what is missing" "planned needs --ref" "$OUT"
BEFORE=$(grep -v '^state: \|^ref: ' "$FB")
run "$D" set F002 --state planned --ref quick/Q012
eq "planned with a reference: exit 0" "0 F002 planned" "$EC $OUT"
eq "state and ref are set" "planned quick/Q012" "$(field "$FB" state) $(field "$FB" ref)"
eq "set changes nothing else" "$BEFORE" "$(grep -v '^state: \|^ref: ' "$FB")"
run "$D" set F002 --state open
run "$D" set F002 --state planned
eq "a reference given earlier is enough" "0 planned quick/Q012" "$EC $(field "$FB" state) $(field "$FB" ref)"
run "$D" set F003 --state fixed --ref M004-S02-T03
eq "fixed takes a reference too" "fixed M004-S02-T03" "$(field "$S/F003-third.md" state) $(field "$S/F003-third.md" ref)"
feed "Not ours." "$D" set F004 --state dismissed
run "$D" set F004 --state open
eq "a dismissal can be taken back" "0 open" "$EC $(field "$S/F004-fourth.md" state)"
feed "Not ours after all." "$D" set F004 --state dismissed
run "$D" set F042 --state fixed;                    eq "set for an unknown id: exit 1" 1 "$EC"
run "$D" set seven --state fixed;                   eq "set for something that is no id: exit 64" 64 "$EC"
run "$D" set F001 --state closed;                   eq "a state outside the four: exit 64" 64 "$EC"
run "$D" set F001;                                  eq "set without --state: exit 64" 64 "$EC"
run "$D" set F001 --state planned --ref "two words"; eq "a reference with a space: exit 64" 64 "$EC"
eq "the refused calls changed nothing" "open none" "$(field "$FA" state) $(field "$FA" ref)"

run "$D" list
eq "list: open and planned by default" "F001${TAB}open${TAB}errors${TAB}errors${TAB}1${TAB}$T1${TAB}none${TAB}none${TAB}errors:a${TAB}First
F002${TAB}planned${TAB}latency${TAB}performance${TAB}1${TAB}$T1${TAB}quick/Q012${TAB}none${TAB}latency:b${TAB}Second" "$OUT"
run "$D" list --state fixed
eq "list --state fixed" "F003${TAB}fixed${TAB}errors${TAB}errors${TAB}1${TAB}$T1${TAB}M004-S02-T03${TAB}none${TAB}errors:c${TAB}Third" "$OUT"
run "$D" list --state dismissed; has "list --state dismissed" "F004${TAB}dismissed" "$OUT"
run "$D" list --state all;       eq "list --state all: every finding" 4 "$(printf '%s\n' "$OUT" | grep -c .)"
run "$D" list --state closed;    eq "list --state with an unknown state: exit 64" 64 "$EC"
run "$D" check
eq "open, planned, fixed and dismissed findings pass the check" "signals ok: 4 finding(s), 0 incident(s)" "$OUT"

# ---- 7. two writers at once ---------------------------------------------------
echo "# at the same time"
project parallel
for N in 1 2 3 4 5 6; do
  ( printf 'sighting %s\n' "$N" | bash "$BIN" -C "$D" new --source errors --key errors:same --kind errors --title "The same thing" > "$TMP/par-$N.out" 2>&1
    echo "exit $?" >> "$TMP/par-$N.out" ) &
done
wait
PFILES=$(ls "$S" | grep -c .)
PEXIT=$(cat "$TMP"/par-[1-6].out | grep -c '^exit 0$')
eq "six sightings of one key at the same time: exactly one file" 1 "$PFILES"
eq "all six calls succeeded" 6 "$PEXIT"
eq "one of them wrote the finding" 1 "$(cat "$TMP"/par-[1-6].out | grep -c '^new F001 ')"
eq "five saw it again" 5 "$(cat "$TMP"/par-[1-6].out | grep -c '^seen-again F001 ')"
eq "and the count is six" 6 "$(field "$S"/F001-*.md count)"
if [ "$PFILES" != 1 ] || [ "$PEXIT" != 6 ]; then
  for N in 1 2 3 4 5 6; do echo "  FAIL   call $N: $(tr '\n' ' ' < "$TMP/par-$N.out")"; done
  echo "  FAIL   files: $(ls "$S" | tr '\n' ' ') lock left: $([ -e "$D/.ytstack/signals.lock" ] && echo yes || echo no)"
fi
for N in 1 2 3 4 5 6; do
  ( printf 'other %s\n' "$N" | bash "$BIN" -C "$D" new --source errors --key "errors:other-$N" --kind errors --title "Other $N" > "$TMP/oth-$N.out" 2>&1 ) &
done
wait
eq "six different keys at the same time: six more files" 7 "$(ls "$S" | grep -c .)"
eq "with six different ids" 6 "$(cat "$TMP"/oth-[1-6].out | cut -d' ' -f2 | sort -u | grep -c '^F00[2-7]$')"
# a held lock is waited for, not written past
: > "$D/.ytstack/signals.lock"
( printf 'late\n' | bash "$BIN" -C "$D" new --source errors --key errors:late --kind errors --title "Late" > "$TMP/late.out" 2>&1 ) &
sleep 1
eq "while the lock is held, nothing is written" 7 "$(ls "$S" | grep -c .)"
rm -f "$D/.ytstack/signals.lock"
wait
eq "once it is free, the waiting call writes its finding" 8 "$(ls "$S" | grep -c .)"
if [ -e "$D/.ytstack/signals.lock" ] || ls "$S" | grep '\.tmp$' >/dev/null; then bad "no lock and no temporary file left behind"; else ok "no lock and no temporary file left behind"; fi
run "$D" check
eq "and the files pass the check" "signals ok: 8 finding(s), 0 incident(s)" "$OUT"

# ---- 8. check: each defect on its own -----------------------------------------
echo "# check: defects"
N=0
# fresh: a new project with one well-formed finding. Sets D, S and F.
fresh() {
  N=$((N + 1)); project "d$N"
  see "$D" errors:1 "Does it hold"; F=$(path)
}
# defect <case> <text>: check fails and names <text>
defect() {
  run "$D" check
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC: $OUT"; fi
}
NAME="F001-does-it-hold.md"

fresh; edit "$F" 's/^id: F001/id: F009/'
defect "an id that differs from the file name" "$NAME: id \"F009\" does not match the file name"
eq "one line per problem" 1 "$(printf '%s\n' "$OUT" | grep -c .)"
fresh; sed 's/^key: .*/key: errors:2/' "$F" > "$S/F001-a-second-file.md"
defect "an id used twice" "the id F001 is used by more than one file"
fresh; edit "$F" '1d'
defect "a file without frontmatter" "$NAME: no frontmatter"
fresh; edit "$F" '12d'
defect "a frontmatter that is not closed" "$NAME: the frontmatter is not closed"
fresh; : > "$S/F002-empty.md"
defect "an empty file" "F002-empty.md: no frontmatter"
fresh; cp "$F" "$S/notes.md"
defect "a file name outside F###-<slug>.md" "notes.md: the name is not F###-<slug>.md"
fresh; edit "$F" 's/^key: .*/key: two words/'
defect "a key that is not one word" "$NAME: key \"two words\" is not one word of"
fresh; edit "$F" 's/^source: .*/source: Errors/'
defect "a source that is no lowercase slug" "$NAME: source \"Errors\" is not a lowercase slug"
fresh; edit "$F" 's/^kind: .*/kind: crash/'
defect "a kind outside the four" "$NAME: kind \"crash\" is not one of errors|performance|alerts|logs"
fresh; edit "$F" 's/^state: .*/state: pending/'
defect "a state outside the four" "$NAME: state \"pending\" is not one of open|planned|fixed|dismissed"
fresh; edit "$F" 's/^first_seen: .*/first_seen: yesterday/'
defect "a first_seen that is no time" "$NAME: first_seen \"yesterday\" is not a UTC time"
fresh; edit "$F" 's/^last_seen: .*/last_seen: 2026-11-13T09:15Z/'
defect "a last_seen without seconds" "$NAME: last_seen \"2026-11-13T09:15Z\" is not a UTC time"
fresh; edit "$F" 's/^count: .*/count: 0/'
defect "a count below 1" "$NAME: count \"0\" is not a number from 1"
fresh; edit "$F" 's/^ref: .*/ref: the export task/'
defect "a ref that is not one word" "$NAME: ref \"the export task\" is not \"none\" or one word of"
fresh; edit "$F" 's/^state: .*/state: planned/'
defect "planned without a reference" "$NAME: state planned, but ref is \"none\""
fresh; edit "$F" 's/^state: .*/state: dismissed/'
defect "dismissed without a reason" "$NAME: state dismissed, but there is no reason under \"## Assessment\""
fresh; edit "$F" 's/^reopens: .*/reopens: the old one/'
defect "a reopens that is no id" "$NAME: reopens \"the old one\" is not \"none\" or an id"
fresh; edit "$F" '/^## Assessment$/d'
defect "a missing section" "$NAME: the sections are not \"What was seen\", \"Assessment\" and \"Next\", each once and in this order"
fresh; printf '\n## Assessment\n' >> "$F"
defect "a section that stands twice" "$NAME: the sections are not"
fresh; see "$D" errors:2 "Another one"; edit "$(path)" 's/^key: .*/key: errors:1/'
defect "two findings with one key that both reopen nothing" "F002-another-one.md: the key \"errors:1\" is the key of F001 already, and this finding reopens nothing"
fresh; edit "$F" 's/^reopens: .*/reopens: F005/'
defect "a reopens that names no finding" "$NAME: reopens F005, which does not exist"
fresh; edit "$F" 's/^state: .*/state: fixed/'; see "$D" errors:2 "Another one"; edit "$(path)" 's/^reopens: .*/reopens: F001/'
defect "a reopens that names a finding with another key" "F002-another-one.md: reopens F001, which has another key"
fresh; see "$D" errors:2 "Another one"; edit "$F" 's/^reopens: .*/reopens: F002/; s/^key: .*/key: errors:2/'
defect "a reopens that names a newer finding" "$NAME: reopens F002, which is not an older finding"
fresh; run "$D" set F001 --state fixed; see "$D" errors:1 "Back"; edit "$F" 's/^state: .*/state: open/'
defect "an older finding of a key that is not fixed" "$NAME: state open, but F002 is a newer finding with the same key; only the newest finding of a key is not fixed"

# ---- 9. incident new, incident list -------------------------------------------
echo "# incident"
HANDOVER="$ROOT/bin/ytstack-handover"
TODAY=$(date -u +%Y-%m-%d)
project incident; I="$D/.ytstack/incidents"
run "$D" incident list; eq "incident list without the directory: exit 0, nothing" "0 " "$EC $OUT"
run "$D" incident new --title "Checkout returns 502" --severity "all customers,
 no orders"
R="$I/$TODAY-checkout-returns-502.md"
eq "incident new prints the path: the day in UTC and a slug from the title" "0 $R" "$EC $OUT"
OPENED=$(field "$R" opened)
if is_utc "$OPENED"; then ok "opened is a UTC time"; else bad "opened is a UTC time" "$OPENED"; fi
eq "the skeleton: frontmatter, the six sections in order, the first timeline line" "---
id: $TODAY-checkout-returns-502
state: open
opened: $OPENED
mitigated: none
closed: none
severity: all customers, no orders
root_cause: none
---

# Incident -- Checkout returns 502

## What is seen

## Timeline

- $OPENED -- record opened

## Hypotheses

## Proposed mitigations

## Decisions

## After" "$(cat "$R")"
run "$D" check; eq "the skeleton passes the check" "signals ok: 0 finding(s), 1 incident(s)" "$OUT"
printf 'kept\n' >> "$R"
run "$D" incident new --title "Checkout returns 502"
eq "a record of that day with that title is not opened twice: exit 1" 1 "$EC"
has "and says to resume it" "exists: resume that record" "$OUT"
has "the record is not overwritten" "kept" "$(tail -1 "$R")"
run "$D" incident new --title "Search is slow"
eq "without --severity it is unstated" "unstated" "$(field "$OUT" severity)"
run "$D" incident new --title "???"
eq "a title without letters still gets a file name" "$I/$TODAY-incident.md" "$OUT"
run "$D" incident new;                         eq "incident new without --title: exit 64" 64 "$EC"
run "$D" incident new --title;                 eq "an option without a value: exit 64" 64 "$EC"
run "$D" incident;                             eq "incident without a command: exit 64" 64 "$EC"
run "$D" incident close x;                     eq "an unknown incident command: exit 64" 64 "$EC"
run "$TMP/bare" incident new --title "Nowhere"; eq "incident new without a .ytstack directory: exit 1" 1 "$EC"
if [ ! -e "$TMP/bare/.ytstack" ]; then ok "and creates none"; else bad "and creates none"; fi
edit "$I/$TODAY-search-is-slow.md" 's/^state: open/state: closed/; s/^closed: none/closed: 2026-11-13T12:00:00Z/; s/^root_cause: none/root_cause: M005-S01-T02/'
edit "$I/$TODAY-incident.md" 's/^state: open/state: mitigated/; s/^mitigated: none/mitigated: 2026-11-13T11:00:00Z/'
run "$D" incident list
eq "incident list: id, state, opened, severity, title; the closed one left out" "$TODAY-checkout-returns-502${TAB}open${TAB}$OPENED${TAB}all customers, no orders${TAB}Checkout returns 502
$TODAY-incident${TAB}mitigated${TAB}$(field "$I/$TODAY-incident.md" opened)${TAB}unstated${TAB}???" "$OUT"
run "$D" incident list --state closed; has "incident list --state closed" "$TODAY-search-is-slow${TAB}closed" "$OUT"
run "$D" incident list --state all;    eq "incident list --state all" 3 "$(printf '%s\n' "$OUT" | grep -c .)"
run "$D" incident list --state fixed;  eq "incident list --state with an unknown state: exit 64" 64 "$EC"
edit "$R" '$d'
run "$D" check; eq "open, mitigated and closed records pass the check" "signals ok: 0 finding(s), 3 incident(s)" "$OUT"
see "$D" errors:1
run "$D" check; eq "findings and incidents are counted side by side" "signals ok: 1 finding(s), 3 incident(s)" "$OUT"

# ---- 10. check: incident records, each defect on its own -----------------------
echo "# check: incident defects"
# inc: a new project with one well-formed open record. Sets D, I, R and INAME.
inc() {
  N=$((N + 1)); project "i$N"; I="$D/.ytstack/incidents"
  run "$D" incident new --title "Checkout returns 502"; R="$OUT"; INAME=${R##*/}
}
# passes <case>: check is clean
passes() {
  run "$D" check
  eq "$1" "0 signals ok: 0 finding(s), 1 incident(s)" "$EC $OUT"
}
# script <name> [bare]: a handover script under .ytstack/handover/ of the project;
# with "bare" it is the unfilled template, which does not pass its check.
script() {
  local p="$D/.ytstack/handover/$1.sh"
  bash "$HANDOVER" new "$p" --title "Restart the checkout" >/dev/null || return 1
  [ "${2:-}" != bare ] || return 0
  sed -e 's/^# Purpose:$/# Purpose: the checkout answers again/' \
      -e 's/^# Prepared by:$/# Prepared by: test agent, for the incident/' \
      -e 's/^# Changes:$/# Changes: the pods of one deployment/' \
      -e 's/^# Undo:$/# Undo: none needed/' "$p" > "$p.tmp" && cat "$p.tmp" > "$p" && rm -f "$p.tmp"
  printf 'stage "Prove the target" "Reads only."\ncheck "true holds" true\n' >> "$p"
}
# mitigation <status> [<script path>]: one mitigation line under "Proposed mitigations"
mitigation() {
  edit "$R" "s%^## Proposed mitigations\$%&\\
\\
- M1 -- Restart the checkout | changes: the pods of deployment checkout | effect: 502 stops | risk: requests in flight fail | undo: none needed | script: ${2:-.ytstack/handover/restart.sh} | status: $1%"
}

inc; edit "$R" "s/^id: .*/id: $TODAY-something-else/"
defect "an id that differs from the file name" "$INAME: id \"$TODAY-something-else\" does not match the file name"
eq "one line per problem" 1 "$(printf '%s\n' "$OUT" | grep -c .)"
inc; cp "$R" "$I/notes.md"
defect "a file name outside <YYYY-MM-DD>-<slug>.md" "notes.md: the name is not <YYYY-MM-DD>-<slug>.md"
inc; edit "$R" '1d'
defect "a record without frontmatter" "$INAME: no frontmatter"
inc; edit "$R" 's/^state: .*/state: resolved/'
defect "a state outside the three" "$INAME: state \"resolved\" is not one of open|mitigated|closed"
inc; edit "$R" 's/^opened: .*/opened: this morning/'
defect "an opened that is no time" "$INAME: opened \"this morning\" is not a UTC time"
inc; edit "$R" 's/^mitigated: .*/mitigated: 2026-11-13T11:00:00Z/'
defect "open with a mitigated time" "$INAME: state open, but mitigated is \"2026-11-13T11:00:00Z\""
inc; edit "$R" 's/^closed: .*/closed: 2026-11-13T11:00:00Z/'
defect "open with a closed time" "$INAME: state open, but closed is \"2026-11-13T11:00:00Z\""
inc; edit "$R" 's/^state: .*/state: mitigated/'
defect "mitigated without its time" "$INAME: state mitigated, but mitigated is not set"
inc; edit "$R" 's/^state: .*/state: mitigated/; s/^mitigated: .*/mitigated: soon/'
defect "a mitigated that is neither none nor a time" "$INAME: mitigated \"soon\" is not \"none\" or a UTC time"
inc; edit "$R" 's/^state: .*/state: mitigated/; s/^mitigated: .*/mitigated: 2026-11-13T11:00:00Z/; s/^closed: .*/closed: 2026-11-13T12:00:00Z/'
defect "mitigated with a closed time" "$INAME: state mitigated, but closed is \"2026-11-13T12:00:00Z\""
inc; edit "$R" 's/^state: .*/state: closed/; s/^root_cause: .*/root_cause: M005-S01-T02/'
defect "closed without its time" "$INAME: state closed, but closed is not set"
inc; edit "$R" 's/^state: .*/state: closed/; s/^closed: .*/closed: 2026-11-13T12:00:00Z/'
defect "closed without a root cause" "$INAME: state closed, but root_cause is \"none\""
inc; edit "$R" 's/^state: .*/state: closed/; s/^closed: .*/closed: 2026-11-13T12:00:00Z/; s/^root_cause: .*/root_cause: not pursued/'
defect "not pursued without a reason" "$INAME: root_cause \"not pursued\" gives no reason"
inc; edit "$R" 's/^state: .*/state: closed/; s/^closed: .*/closed: 2026-11-13T12:00:00Z/; s/^root_cause: .*/root_cause: not pursued -- the provider confirmed an outage on their side/'
passes "closed without a mitigation, the cause not pursued with a reason"
inc; edit "$R" 's/^severity: .*/severity:/'
defect "a record without severity" "$INAME: no severity"
inc; edit "$R" '/^## Hypotheses$/d'
defect "a missing section" "$INAME: the sections are not \"What is seen\", \"Timeline\", \"Hypotheses\", \"Proposed mitigations\", \"Decisions\" and \"After\", each once and in this order"
inc; edit "$R" 's/^## Decisions$/## After/; $s/^## After$/## Decisions/'
defect "sections out of order" "$INAME: the sections are not"

inc; script restart; mitigation proposed
passes "a proposed mitigation whose script exists and passes ytstack-handover check"
inc; script restart; mitigation proposed '`.ytstack/handover/restart.sh`'
passes "a script path written as code"
inc; mitigation proposed
defect "a mitigation whose script does not exist" "$INAME: M1: the script .ytstack/handover/restart.sh does not exist"
inc; script restart bare; mitigation proposed
defect "a mitigation whose script does not pass ytstack-handover check" "$INAME: M1: .ytstack/handover/restart.sh does not pass ytstack-handover check: no stage: a handover script has at least one"
inc; mitigation declined
passes "a declined mitigation needs no script on disk"
inc; script restart; mitigation "ordered by Kim at 2026-11-13T09:31:00Z"
passes "an ordered mitigation with who and when"
inc; script restart; mitigation "ordered by Kim"
defect "an ordered mitigation without its time" "$INAME: M1: status \"ordered by Kim\" is not \"proposed\""
inc; script restart; mitigation "done"
defect "a status outside the four forms" "$INAME: M1: status \"done\" is not \"proposed\""
inc; script restart; mitigation "carried out, receipt .ytstack/handover/restart.sh.receipt-20261113T094712Z.txt"
defect "carried out without the receipt on disk" "$INAME: M1: the receipt .ytstack/handover/restart.sh.receipt-20261113T094712Z.txt does not exist"
printf 'Handover receipt\nResult:  completed\n' > "$D/.ytstack/handover/restart.sh.receipt-20261113T094712Z.txt"
passes "carried out with its receipt"
inc; script restart; mitigation proposed; edit "$R" 's/ | risk: requests in flight fail//'
defect "a mitigation without one of its fields" "$INAME: M1: no risk"
inc; script restart; mitigation proposed; edit "$R" 's/ | undo: none needed/ | undo: kubectl get pods | grep checkout, then nothing/'
passes "a bar inside a value stays part of the value"
inc; script restart; mitigation proposed; edit "$R" 's/^- M1 -- /- /'
defect "a mitigation line without its id" "$INAME: line 23: a mitigation line starts with \"- M<n> -- <what it is>\""
inc; script restart; mitigation proposed; mitigation proposed
defect "a mitigation id used twice" "$INAME: M1 stands twice"
inc; script restart; mitigation proposed; edit "$R" 's/^## Proposed mitigations$/&\
\
Smallest reversible one first./'
passes "free text beside the mitigation lines"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
