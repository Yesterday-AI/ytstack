#!/usr/bin/env bash
# Tests for bin/ytstack-spec (M022, issue #36). Format: docs/ux/spec-format.md.
#
# Contract:
#   lint    a well-formed spec passes; each format rule fails on its own;
#           oversize files warn (exit 2); no spec is a failure
#   drift   an area is listed when its paths changed after the description (or
#           its source) was last touched, and only then; a re-stamped
#           verified_at quiets it; planned areas are skipped; exit 0 unless
#           --exit-code
#   impact  "none" closes; a named area is satisfied by a change to the area
#           file OR to one of its sources, committed or not; nothing changed
#           fails; a plan without the section exits 3
#   areas   names the area whose paths cover a path
#
# Run: /bin/bash tests/ytstack-spec.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-spec"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-spec exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytspec.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

# run <dir> <args...>: sets OUT and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
commit() { ( cd "$1" && git add -A && git commit -qm "$2" ) >/dev/null 2>&1; }
head_of() { git -C "$1" rev-parse --short HEAD; }

# area <dir> <name> <status> <verified_at> <paths, space separated> [sources] [extra body]
area() {
  local d="$1" name="$2" status="$3" ver="$4" paths="$5" sources="${6:-}" extra="${7:-}" p
  {
    printf -- '---\narea: %s\nstatus: %s\npaths:\n' "$name" "$status"
    for p in $paths; do printf -- '  - %s\n' "$p"; done
    if [ -n "$sources" ]; then printf 'sources:\n'; for p in $sources; do printf -- '  - %s\n' "$p"; done; fi
    printf -- 'verified_at: %s\n---\n\n# %s\n\n## Purpose\n\nx\n\n%b## Where implemented\n\nx\n\n## How to verify\n\nx\n\n## Decisions that apply now\n\nnone\n' "$ver" "$name" "$extra"
  } > "$d/.ytstack/spec/$name.md"
}
# spec <dir> <area names...>
spec() {
  local d="$1" a; shift
  {
    printf -- '---\nproject: fx\nupdated: 2026-01-01\n---\n\n# fx -- technical spec\n\n## What this is\n\nx\n\n## Areas\n\n| Area | Covers | Status | File |\n|---|---|---|---|\n'
    for a in "$@"; do printf '| %s | x | implemented | [%s.md](%s.md) |\n' "$a" "$a" "$a"; done
    printf '\n## Keeping this true\n\n- x\n'
  } > "$d/.ytstack/spec/SPEC.md"
}
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack/spec" "$d/src/auth" "$d/src/billing" "$d/docs"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
  echo a > "$d/src/auth/login.sh"; echo b > "$d/src/billing/invoice.sh"; echo doc > "$d/docs/auth.md"
  commit "$d" "base"
  echo "$d"
}

# ---- 1. lint ------------------------------------------------------------------
echo "# lint"
R=$(new_repo lint); V=$(head_of "$R")
area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"
area "$R" billing planned none ""
spec "$R" auth billing
run "$R" lint;                eq "well-formed spec passes" 0 "$EC"
has "counts the area files" "2 area file(s), 0 failure(s), 0 warning(s)" "$OUT"

lint_fails() { # <label> <expected text>; the fixture was broken by the caller
  run "$R" lint
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC, output: $OUT"; fi
  area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"; area "$R" billing planned none ""; spec "$R" auth billing
}
sed -i.bak 's/^area: auth/area: login/' "$R/.ytstack/spec/auth.md"; rm -f "$R/.ytstack/spec/auth.md.bak"
lint_fails "area differs from file name" "differs from the file name"
area "$R" auth shipped "$V" "src/auth/**";                   lint_fails "unknown status" "is not planned, partial or implemented"
area "$R" auth implemented none "src/auth/**";               lint_fails "implemented without verified_at" "needs verified_at"
area "$R" auth partial deadbeefdeadbeef "src/auth/**"
run "$R" lint;                eq "verified_at that is not a commit warns (a squash merge can orphan it)" 2 "$EC"
has "says what to do" "is not a commit in this repository" "$OUT"
area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"
area "$R" auth implemented "$V" "";                          lint_fails "implemented without paths" "needs paths"
area "$R" auth implemented "$V" "src/nowhere/**";            lint_fails "paths match nothing" "matches no file in the repository"
mkdir -p "$R/src/new"; echo n > "$R/src/new/n.sh"
area "$R" auth implemented "$V" "src/new/**"
run "$R" lint;                eq "paths may name a new file that is not committed yet" 0 "$EC"
rm -rf "$R/src/new"; area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"
area "$R" auth implemented "$V" "src/auth/**" "docs/gone.md"; lint_fails "source missing" "does not exist"
area "$R" auth implemented "$V" "src/auth/**" "" '## History\n\nx\n\n'; lint_fails "section outside the fixed list" "not one of the fixed sections"
area "$R" auth implemented "$V" "src/auth/**"
printf '\n## Behavior\n\nlate\n' >> "$R/.ytstack/spec/auth.md";  lint_fails "section out of order" "out of order"
area "$R" auth implemented "$V" "src/auth/**"
grep -v -e '^## How to verify' "$R/.ytstack/spec/auth.md" > "$R/.ytstack/spec/auth.tmp"; mv "$R/.ytstack/spec/auth.tmp" "$R/.ytstack/spec/auth.md"
lint_fails "required section missing" "required section '## How to verify' is missing"
spec "$R" auth;                                              lint_fails "area file not listed in SPEC.md" "billing.md: not listed"
spec "$R" auth billing ghost;                                lint_fails "SPEC.md links a missing file" "links ghost.md"
printf -- '# no frontmatter\n\n## Purpose\n' > "$R/.ytstack/spec/auth.md"; lint_fails "no frontmatter" "no frontmatter"
grep -v '^## Keeping this true' "$R/.ytstack/spec/SPEC.md" > "$R/.ytstack/spec/SPEC.tmp"; mv "$R/.ytstack/spec/SPEC.tmp" "$R/.ytstack/spec/SPEC.md"
lint_fails "SPEC.md without the maintenance section" "'## Keeping this true' is missing"

LONG=$(awk 'BEGIN { for (i = 0; i < 210; i++) printf "line\\n" }')
area "$R" auth implemented "$V" "src/auth/**" "" "## Behavior\n\n$LONG\n"
run "$R" lint;                eq "oversize area file warns (exit 2)" 2 "$EC"
has "names the size" "an area file stays under 200" "$OUT"
area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"

area "$R" billing planned none "src/future/**"
run "$R" lint;                eq "planned area may name paths that do not exist yet" 0 "$EC"

NOSPEC="$TMP/nospec"; mkdir -p "$NOSPEC/.ytstack"
run "$NOSPEC" lint;           eq "no spec is a failure" 1 "$EC"

# ---- 2. drift -----------------------------------------------------------------
echo "# drift"
R=$(new_repo drift); V=$(head_of "$R")
area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"
area "$R" billing implemented "$V" "src/billing/**"
area "$R" search planned none "src/search/**"
spec "$R" auth billing search
commit "$R" "add spec"
run "$R" drift;               eq "untouched areas: exit 0" 0 "$EC"
has "untouched areas: nothing listed" "no area to look at" "$OUT"

echo a2 > "$R/src/auth/login.sh"; commit "$R" "change auth code"
run "$R" drift
has "code changed after the description: listed" "auth: possible documentation impact" "$OUT"
hasnt "the other area stays quiet" "billing:" "$OUT"
hasnt "a planned area is skipped" "search:" "$OUT"
eq "advisory: exit 0 without --exit-code" 0 "$EC"
run "$R" drift --exit-code;   eq "--exit-code: exit 2 when an area is listed" 2 "$EC"

echo "doc v2" > "$R/docs/auth.md"; commit "$R" "update the authoritative source"
run "$R" drift
hasnt "a later change to the source quiets it (area file unchanged)" "auth:" "$OUT"

echo b2 > "$R/src/billing/invoice.sh"; printf '\nmore\n' >> "$R/.ytstack/spec/billing.md"; commit "$R" "code and description together"
run "$R" drift
hasnt "code and area file in one commit: quiet" "billing:" "$OUT"

echo b3 > "$R/src/billing/invoice.sh"; commit "$R" "refactor billing"
run "$R" drift
has "a refactoring is listed as possible impact" "billing: possible documentation impact -- 1 commit(s)" "$OUT"
N=$(head_of "$R")
sed -i.bak "s/^verified_at: .*/verified_at: $N/" "$R/.ytstack/spec/billing.md"; rm -f "$R/.ytstack/spec/billing.md.bak"
commit "$R" "billing: contract unchanged, re-stamp"
run "$R" drift
hasnt "re-stamped verified_at quiets it without a description edit" "billing:" "$OUT"

# a stamp that names a commit a squash merge dropped does not break the report
sed -i.bak "s/^verified_at: .*/verified_at: deadbeefdeadbeef/" "$R/.ytstack/spec/billing.md"; rm -f "$R/.ytstack/spec/billing.md.bak"
commit "$R" "billing: orphaned stamp"
echo b4 > "$R/src/billing/invoice.sh"; commit "$R" "change billing again"
run "$R" drift
has "an orphaned stamp still yields the report" "billing: possible documentation impact -- 1 commit(s)" "$OUT"

# an area file that is not committed yet has nothing to compare against,
# even when the source it names has a history
area "$R" fresh implemented "$N" "src/auth/**" "docs/auth.md"; spec "$R" auth billing search fresh
echo a9 > "$R/src/auth/login.sh"; ( cd "$R" && git add src/auth/login.sh && git commit -qm "auth again" ) >/dev/null 2>&1
run "$R" drift
hasnt "an uncommitted area file is skipped" "fresh:" "$OUT"
has "the committed area over the same paths is still listed" "auth: possible documentation impact" "$OUT"
# a description being edited in the working tree is not reported
printf '\nedit in progress\n' >> "$R/.ytstack/spec/auth.md"
run "$R" drift
hasnt "an area file with uncommitted edits is skipped" "auth:" "$OUT"

run "$NOSPEC" drift;          eq "no spec: exit 0" 0 "$EC"

# ---- 3. impact ----------------------------------------------------------------
echo "# impact"
R=$(new_repo impact); V=$(head_of "$R")
area "$R" auth implemented "$V" "src/auth/**" "docs/auth.md"
area "$R" billing implemented "$V" "src/billing/**"
spec "$R" auth billing
commit "$R" "add spec"
BASE=$(head_of "$R")
plan() { printf -- '---\ntask: T01\n---\n\n# plan\n\n## Files\n\n- x\n\n## Spec impact\n\n%b\n\n## Verification\n\nx\n' "$1" > "$R/.ytstack/M001-S01-T01-PLAN.md"; }
P="$R/.ytstack/M001-S01-T01-PLAN.md"

plan "none -- restores the documented behaviour"
run "$R" impact --plan "$P" --grep '^M001-S01-T01:'
eq "none closes" 0 "$EC"
has "none echoes the reason" "restores the documented behaviour" "$OUT"

printf -- '# plan\n\n## Files\n\n- x\n' > "$P"
run "$R" impact --plan "$P" --grep '^M001-S01-T01:'
eq "plan without the section: exit 3" 3 "$EC"

plan "- auth: Behavior -- login accepts a token"
echo a2 > "$R/src/auth/login.sh"; commit "$R" "M001-S01-T01: token login"
run "$R" impact --plan "$P" --grep '^M001-S01-T01:'
eq "named area, nothing documented: exit 1" 1 "$EC"
has "names what did not change" "neither .ytstack/spec/auth.md nor its sources (docs/auth.md)" "$OUT"

echo "doc v2" > "$R/docs/auth.md"; commit "$R" "M001-S01-T01: document token login"
run "$R" impact --plan "$P" --grep '^M001-S01-T01:'
eq "the authoritative source changed, the pointer did not: satisfied" 0 "$EC"
has "says which file satisfied it" "auth: docs/auth.md changed (committed)" "$OUT"

plan "- billing: Behavior -- invoices are rounded"
run "$R" impact --plan "$P" --grep '^M001-S01-T02:'
eq "another task's commits do not count" 1 "$EC"
printf '\nrounded\n' >> "$R/.ytstack/spec/billing.md"
run "$R" impact --plan "$P" --grep '^M001-S01-T02:'
eq "an uncommitted change to the area file counts" 0 "$EC"
has "and is labelled" "billing: .ytstack/spec/billing.md changed (uncommitted)" "$OUT"
commit "$R" "feat: round invoices"
run "$R" impact --plan "$P" --grep '^M001-S01-T02:' --base "$BASE"
eq "no task-ref commit: falls back to --base..HEAD" 0 "$EC"

plan "- reports: Behavior -- new area"
run "$R" impact --plan "$P" --base "$BASE"
eq "an area without a file fails" 1 "$EC"
has "names the missing file" ".ytstack/spec/reports.md does not exist" "$OUT"

run "$R" impact --plan
eq "a flag without a value is a usage error, not a hang" 64 "$EC"

plan "- auth: Behavior -- a\n- billing: Known limits -- b"
run "$R" impact --plan "$P" --base "$BASE"
eq "two areas, both satisfied" 0 "$EC"

# ---- 4. areas -----------------------------------------------------------------
echo "# areas"
run "$R" areas src/auth/login.sh;      has "names the area of a path" "src/auth/login.sh: auth" "$OUT"
eq "exit 0 when every path has an area" 0 "$EC"
run "$R" areas README.md;              has "says when no area covers a path" "README.md: no area" "$OUT"
eq "exit 1 when a path has no area" 1 "$EC"
run "$R" areas --names src/auth/login.sh src/auth/other.sh README.md src/billing/invoice.sh
eq "--names: unique area names, one per line" "auth
billing" "$OUT"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
