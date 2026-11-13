#!/usr/bin/env bash
# Tests for bin/ytstack-risk (M025). Format: docs/ux/review-policy-format.md.
#
# Contract:
#   floor   the lowest class a change can have, from the tree difference of
#           two commits. "person" for a rule document, an instruction file,
#           the checks, the frontmatter and the rule sections of an area file,
#           a spec file that was added or deleted, a path no area covers and
#           the project's own list; process records are exempt from coverage.
#           "normal" for the built-in never-low patterns, the project's list
#           and a change over the size limit. The ceiling is the lowest
#           auto_merge of the touched areas. The policy is read at the base.
#   check   a well-formed REVIEW.md passes; each format rule fails on its own
#   route   "unattended" (exit 0) only with a floor that is not person, a
#           newest round line that approves, states risk and "invariants:
#           none", is by somebody other than --author and is valid for the
#           head, and a class within the ceiling. Each condition fails on its
#           own with one reason (exit 10). A round stays valid when only
#           process records changed after it.
#
# Run: /bin/bash tests/ytstack-risk.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-risk"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-risk exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytrisk-test.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

# run <dir> <args...>: sets OUT and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
# line <label>: the first output line with that label
line() { printf '%s\n' "$OUT" | grep "^$1: " | head -1; }

# area <dir> <name> <auto_merge or -> <paths...>
area() {
  local d="$1" name="$2" am="$3" p; shift 3
  {
    printf -- '---\narea: %s\nstatus: implemented\npaths:\n' "$name"
    for p in "$@"; do printf -- '  - %s\n' "$p"; done
    printf 'verified_at: none\n'
    [ "$am" = - ] || printf 'auto_merge: %s\n' "$am"
    printf -- '---\n\n# %s\n\n## Purpose\n\nx\n\n## Behavior\n\nold behaviour\n\n## Invariants and security boundaries\n\n- tokens expire\n\n## Where implemented\n\nx\n\n## How to verify\n\nx\n\n## Decisions that apply now\n\n- none\n' "$name"
  } > "$d/.ytstack/spec/$name.md"
}

# new_repo <name> [nospec]: four areas (auth low, billing normal, web normal,
# pkg without auto_merge), a REVIEW.md, the base commit tagged "base".
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/src/auth" "$d/src/billing/ledger" "$d/src/ui" "$d/pkg" "$d/docs" "$d/.ytstack" || exit 1
  ( cd "$d" || exit 1
    git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false || exit 1
    echo a > src/auth/login.sh; echo b > src/billing/invoice.sh; echo c > src/billing/ledger/book.sh
    echo d > src/ui/button.css; echo e > pkg/readme.txt; echo design > docs/design.md; echo api > docs/api.md
    echo rules > AGENTS.md; ln -s AGENTS.md CLAUDE.md
    echo d > .ytstack/DECISIONS.md; echo p > .ytstack/PREFERENCES.md; echo s > .ytstack/STATE.md
    if [ "${2:-}" != nospec ]; then
      mkdir -p .ytstack/spec
      printf -- '---\nproject: fx\nupdated: 2026-01-01\n---\n\n# fx -- technical spec\n\n## Areas\n\nx\n\n## Invariants that hold everywhere\n\n- nothing is deleted\n\n## Keeping this true\n\n- x\n' > .ytstack/spec/SPEC.md
      area . auth low "src/auth/**"; area . billing normal "src/billing/**"
      area . web normal "src/ui/**"; area . pkg - "pkg/**"
      printf '# Review policy\n\n## Always a person\n\n- src/billing/ledger/**\n\n## Never low\n\n- src/auth/token/**\n\n## Lenses\n\n- ui | applies: src/ui/**, **/*.css | reads: docs/design.md | evidence: visual\n- api | applies: src/billing/api/** | reads: docs/api.md, .ytstack/spec/billing.md | evidence: none\n' > .ytstack/spec/REVIEW.md
    fi
    git add -A && git commit -qm base && git tag base ) >/dev/null 2>&1 || exit 1
  echo "$d"
}

# change <dir> <name> <commands, run in the repository>: a branch off $FROM
# (default: base) with one commit. Sets H.
FROM=base
change() {
  local d="$1" name="$2"
  ( cd "$d" || exit 1
    git checkout -q -B "$name" "$FROM" && eval "$3" && git add -A && git commit -qm "$name" ) >/dev/null 2>&1 \
    || bad "fixture: change $name"
  H=$(git -C "$d" rev-parse HEAD)
}
edit() { sed -i.bak "$1" "$2" && rm -f "$2.bak"; }   # edit <sed expression> <file>
fl() { run "$R" floor --base "$FROM" --head "$H"; }
# person|normal <label> <text>: the floor is that class and the output has the text
person() { fl; if [ "$(line floor)" = "floor: person" ]; then has "$1" "$2" "$OUT"; else bad "$1" "$OUT"; fi; }
normal() { fl; if [ "$(line floor)" = "floor: normal" ]; then has "$1" "$2" "$OUT"; else bad "$1" "$OUT"; fi; }

# ---- 1. floor: areas and ceilings ----------------------------------------------
echo "# floor: areas and ceilings"
R=$(new_repo floor)
change "$R" ordinary 'echo b >> src/auth/login.sh'; fl
eq "a computed result exits 0" 0 "$EC"
eq "an ordinary change in one area: low, its area, its ceiling, no reason" "floor: low
areas: auth
ceiling: low" "$OUT"
change "$R" two 'echo b >> src/auth/login.sh; echo b >> src/billing/invoice.sh'; fl
eq "two areas are both named" "areas: auth,billing" "$(line areas)"
eq "two areas: the lowest ceiling" "ceiling: low" "$(line ceiling)"
change "$R" billing 'echo b >> src/billing/invoice.sh'; fl
eq "one area with auto_merge normal" "ceiling: normal" "$(line ceiling)"
change "$R" pkg 'echo b >> pkg/readme.txt'; fl
eq "an area without auto_merge: ceiling none" "ceiling: none" "$(line ceiling)"
eq "and the floor is still low" "floor: low" "$(line floor)"

# ---- 2. floor: always a person -------------------------------------------------
echo "# floor: always a person"
change "$R" review 'echo "- x/**" >> .ytstack/spec/REVIEW.md'
person "REVIEW.md" "reason: .ytstack/spec/REVIEW.md -- always a person: rule document"
change "$R" decisions 'echo x >> .ytstack/DECISIONS.md'
person "DECISIONS.md" "reason: .ytstack/DECISIONS.md -- always a person: rule document"
change "$R" standing 'echo x > .ytstack/STANDING.md'
person "STANDING.md" "reason: .ytstack/STANDING.md -- always a person: rule document"
change "$R" prefs 'echo x >> .ytstack/PREFERENCES.md'
person "PREFERENCES.md" "reason: .ytstack/PREFERENCES.md -- always a person: rule document"
change "$R" agents 'echo x >> AGENTS.md'
person "AGENTS.md, the target of the CLAUDE.md symlink" "reason: AGENTS.md -- always a person: instruction file"
change "$R" nested 'mkdir -p src/auth/sub && echo x > src/auth/sub/CLAUDE.md'
person "an instruction file at any depth, inside an area" "reason: src/auth/sub/CLAUDE.md -- always a person: instruction file"
change "$R" workflow 'mkdir -p .github/workflows && echo x > .github/workflows/ci.yml'
person "a workflow" "reason: .github/workflows/ci.yml -- always a person: the checks themselves"
change "$R" gitlab 'echo x > .gitlab-ci.yml'
person "the GitLab pipeline" "reason: .gitlab-ci.yml -- always a person: the checks themselves"

change "$R" frontmatter 'edit "s/^auto_merge: low/auto_merge: normal/" .ytstack/spec/auth.md; echo b >> src/auth/login.sh'
person "the frontmatter of an area file" "reason: .ytstack/spec/auth.md -- always a person: frontmatter of an area file"
eq "the ceiling is the one the base has, not the raised one" "ceiling: low" "$(line ceiling)"
change "$R" invariant 'edit "s/tokens expire/tokens never expire/" .ytstack/spec/auth.md'
person "the invariants section of an area file" 'always a person: section "Invariants and security boundaries"'
change "$R" decision 'edit "s/^- none$/- D-12/" .ytstack/spec/auth.md'
person "the decisions section of an area file" 'always a person: section "Decisions that apply now"'
change "$R" behavior 'edit "s/old behaviour/new behaviour/" .ytstack/spec/auth.md'; fl
eq "another edit of an area file is ordinary and touches its area" "floor: low
areas: auth
ceiling: low" "$OUT"
change "$R" newarea 'mkdir -p src/search && echo x > src/search/s.sh && area . search normal "src/search/**"'
person "a new area file" "reason: .ytstack/spec/search.md -- always a person: a file of the technical spec was added or deleted"
has "paths only the new area names are not covered yet" "reason: src/search/s.sh -- always a person: no area covers this path" "$OUT"
change "$R" delarea 'git rm -q .ytstack/spec/pkg.md'
person "a deleted area file" "reason: .ytstack/spec/pkg.md -- always a person: a file of the technical spec was added or deleted"
change "$R" specinv 'edit "s/nothing is deleted/something is deleted/" .ytstack/spec/SPEC.md'
person "the invariants section of SPEC.md" 'reason: .ytstack/spec/SPEC.md -- always a person: section "Invariants that hold everywhere"'
change "$R" specother 'edit "s/^updated: .*/updated: 2026-02-02/" .ytstack/spec/SPEC.md'; fl
eq "another edit of SPEC.md is ordinary" "floor: low
areas: none
ceiling: none" "$OUT"

change "$R" uncovered 'mkdir -p tools && echo x > tools/x.sh'
person "a path no area covers" "reason: tools/x.sh -- always a person: no area covers this path"
change "$R" notes 'echo x > .ytstack/notes.md'
person "a file under .ytstack/ that is no process record" "reason: .ytstack/notes.md -- always a person: no area covers this path"
change "$R" records 'echo b >> src/auth/login.sh
  for f in M001-CONTEXT.md M001-ROADMAP.md M001-S01-PLAN.md M001-S01-T01-PLAN.md M001-S01-T01-SUMMARY.md STATE.md LANES.md KNOWLEDGE.md ROADMAP.md; do echo x >> .ytstack/$f; done
  mkdir -p .ytstack/quick .ytstack/questions .ytstack/evidence/lane/abc1234/ui
  echo x > .ytstack/quick/Q001-PLAN.md; echo x > .ytstack/questions/Q001-x.md; echo x > .ytstack/evidence/lane/abc1234/ui/a.png'; fl
eq "process records are exempt from the coverage rule" "floor: low
areas: auth
ceiling: low" "$OUT"
change "$R" listed 'echo x >> src/billing/ledger/book.sh'
person "the project's own list" "reason: src/billing/ledger/book.sh -- always a person: listed in REVIEW.md (src/billing/ledger/**)"
change "$R" listed-del 'git rm -q src/billing/ledger/book.sh'
person "a deleted file counts with its path" "reason: src/billing/ledger/book.sh -- always a person: listed in REVIEW.md"
change "$R" rename 'mkdir -p tools && git mv src/auth/login.sh tools/login.sh'
person "a renamed file counts with its new path" "reason: tools/login.sh -- always a person: no area covers this path"
eq "and with its old one" "areas: auth" "$(line areas)"
change "$R" many 'mkdir -p tools && for i in 1 2 3 4 5 6 7 8; do echo x > tools/$i.sh; done'; fl
eq "a rule names five paths" 5 "$(printf '%s\n' "$OUT" | grep -c '^reason: tools/.* -- always a person: no area covers this path')"
has "and counts the rest" "reason: 3 more path(s) -- always a person: no area covers this path" "$OUT"

# ---- 3. floor: never low -------------------------------------------------------
echo "# floor: never low"
for f in package.json sub/pnpm-lock.yaml api/pyproject.toml api/requirements-dev.txt Cargo.lock go.mod Gemfile \
  composer.json pom.xml db/migrations/001.txt db/migrate/002.rb prisma/client.txt drizzle/meta.json q.sql \
  db/schema.rb Dockerfile.dev docker-compose.yml infra/main.tf chart/Chart.yaml k8s/deploy.yaml; do
  change "$R" neverlow "mkdir -p pkg/$(dirname "$f") && echo x > pkg/$f"; fl
  eq "built-in pattern: $f" "floor: normal" "$(line floor)"
done
change "$R" manifest 'echo x > pkg/package.json'
normal "the reason names the group" "reason: pkg/package.json -- never low: dependency manifest or lock file (npm, pnpm, yarn, bun)"
change "$R" rootmanifest 'echo x > package.json'; fl
has "a pattern matches at the root as well" "reason: package.json -- never low: dependency manifest" "$OUT"
change "$R" token 'mkdir -p src/auth/token && echo x > src/auth/token/t.sh'
normal "the project's own list" "reason: src/auth/token/t.sh -- never low: listed in REVIEW.md (src/auth/token/**)"
change "$R" lines400 'awk "BEGIN { for (i = 0; i < 400; i++) print \"l\" }" > src/auth/big.sh'; fl
eq "400 changed lines are within the limit" "floor: low" "$(line floor)"
change "$R" lines401 'awk "BEGIN { for (i = 0; i < 401; i++) print \"l\" }" > src/auth/big.sh'
normal "401 changed lines are over it" "reason: size -- never low: 401 changed lines in 1 files, the limit is 400 lines and 20 files"
change "$R" files21 'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21; do echo x > src/auth/f$i.sh; done'
normal "21 changed files are over the limit" "reason: size -- never low: 21 changed lines in 21 files"
change "$R" bigrecord 'echo b >> src/auth/login.sh; awk "BEGIN { for (i = 0; i < 500; i++) print \"l\" }" > .ytstack/M001-S01-T01-PLAN.md'; fl
eq "process records do not count towards the size" "floor: low" "$(line floor)"
change "$R" binary 'printf "\0\1\2\3" > src/auth/blob.bin'; fl
eq "a binary file is one file and no lines" "floor: low" "$(line floor)"

# ---- 4. floor: the policy at the base ------------------------------------------
echo "# floor: the policy at the base"
change "$R" policy 'printf "\n## Size\n\n- size: 10 lines, 2 files\n" >> .ytstack/spec/REVIEW.md; echo "evidence_dir: shots/" >> .ytstack/PREFERENCES.md'
FROM=$H
change "$R" small11 'awk "BEGIN { for (i = 0; i < 11; i++) print \"l\" }" > src/auth/more.sh'
normal "size: in REVIEW.md changes the two limits" "reason: size -- never low: 11 changed lines in 1 files, the limit is 10 lines and 2 files"
change "$R" files3 'for i in 1 2 3; do echo x > src/auth/f$i.sh; done'
normal "and the file limit" "3 changed lines in 3 files, the limit is 10 lines and 2 files"
change "$R" shots 'echo b >> src/auth/login.sh; mkdir -p shots/lane && echo x > shots/lane/a.png'; fl
eq "evidence_dir names the exempt directory" "floor: low" "$(line floor)"
FROM=base
change "$R" broken 'printf "\n## Reviewers\n\n- somebody\n" >> .ytstack/spec/REVIEW.md'
FROM=$H
change "$R" afterbroken 'echo b >> src/auth/login.sh'
person "a policy that does not parse at the base sends every change to a person" "reason: .ytstack/spec/REVIEW.md -- always a person: the policy at the base does not parse (section '## Reviewers'"
FROM=base

N=$(new_repo nospec nospec)
( cd "$N" || exit 1; echo x >> src/auth/login.sh; echo x >> docs/design.md; echo x > new.txt; echo x >> .ytstack/STATE.md
  git add -A && git commit -qm change ) >/dev/null 2>&1
run "$N" floor --base base --head HEAD
eq "no technical spec: person" "floor: person" "$(line floor)"
eq "with one reason for all paths" "reason: 3 path(s) -- always a person: no area covers them, .ytstack/spec/ has no area file at $(git -C "$N" rev-parse base | cut -c1-7)" "$(printf '%s\n' "$OUT" | grep '^reason: ')"
eq "and no area, no ceiling" "areas: none
ceiling: none" "$(printf '%s\n' "$OUT" | tail -2)"

# ---- 5. floor: usage and git errors --------------------------------------------
echo "# floor: usage and git errors"
run "$R" floor --base base;                  eq "no --head: usage" 64 "$EC"
run "$R" floor --base;                       eq "a flag without a value: usage" 64 "$EC"
run "$R" floor --base base --head base --x y; eq "an unknown flag: usage" 64 "$EC"
run "$R" floor --base nowhere --head base;   eq "a base that names no commit: 65" 65 "$EC"
has "says which" "--base 'nowhere' names no commit" "$OUT"
run "$R" floor --base base --head --all;     eq "a head that is an option, not a commit: 65" 65 "$EC"
mkdir -p "$TMP/plain"
run "$TMP/plain" floor --base a --head b;    eq "outside a repository: 65" 65 "$EC"
run "$R" sideways;                           eq "an unknown command: usage" 64 "$EC"
run "$TMP/gone" check;                       eq "-C to a missing directory: usage" 64 "$EC"

# ---- 6. check ------------------------------------------------------------------
echo "# check"
C=$(new_repo check)
run "$C" check;               eq "a well-formed policy passes" 0 "$EC"
has "and counts its lenses" "review policy ok: 2 lens(es)" "$OUT"
check_fails() { # <label> <REVIEW.md body> <expected text>
  printf '# Review policy\n\n%b' "$2" > "$C/.ytstack/spec/REVIEW.md"
  run "$C" check
  if [ "$EC" = 1 ]; then has "$1" "$3" "$OUT"; else bad "$1" "exit $EC, output: $OUT"; fi
}
check_fails "a section outside the four" '## Reviewers\n\n- somebody\n' "REVIEW.md: section '## Reviewers' is not one of Always a person, Never low, Lenses, Size"
check_fails "a lens without applies" '## Lenses\n\n- ui | reads: docs/design.md | evidence: visual\n' "REVIEW.md: lens ui has no applies"
check_fails "a lens without reads" '## Lenses\n\n- ui | applies: src/ui/** | evidence: visual\n' "REVIEW.md: lens ui has no reads"
check_fails "a lens without evidence" '## Lenses\n\n- ui | applies: src/ui/** | reads: docs/design.md\n' "REVIEW.md: lens ui has no evidence"
check_fails "an evidence outside the two values" '## Lenses\n\n- ui | applies: src/ui/** | reads: docs/design.md | evidence: screenshots\n' "REVIEW.md: lens ui: evidence 'screenshots' is not visual or none"
check_fails "a reads document that does not exist" '## Lenses\n\n- ui | applies: src/ui/** | reads: docs/design.md, docs/gone.md | evidence: none\n' "REVIEW.md: lens ui reads docs/gone.md, which does not exist"
check_fails "a lens name used twice" '## Lenses\n\n- ui | applies: a/** | reads: docs/design.md | evidence: none\n- ui | applies: b/** | reads: docs/design.md | evidence: none\n' "REVIEW.md: lens ui is defined twice"
check_fails "a size line that is not two numbers" '## Size\n\n- size: 400\n' "REVIEW.md: size line 'size: 400' is not 'size: <n> lines, <m> files'"
printf '# Review policy\n\n## Always a person\n\n- infra/**\n\n## Never low\n\n- **/*.sql\n\n## Lenses\n\n- ui | applies: src/ui/** | reads: docs/design.md | evidence: visual | skill: visual-review\n\n## Size\n\n- size: 300 lines, 10 files\n' > "$C/.ytstack/spec/REVIEW.md"
run "$C" check;               eq "all four sections and a lens with a skill pass" 0 "$EC"
rm -f "$C/.ytstack/spec/REVIEW.md"
run "$C" check;               eq "no REVIEW.md: exit 0" 0 "$EC"
eq "and says so" "no review policy" "$OUT"

# ---- 7. route ------------------------------------------------------------------
echo "# route"
P="$TMP/plan.md"
# plan_with <line...>: a plan with those lines under "## Review"
plan_with() {
  { printf -- '---\ntask: T01\n---\n\n# plan\n\n## Files\n\n- Round 9: not a record\n\n## Review\n\n'
    [ $# -eq 0 ] || printf '%s\n' "$@"
    printf '\n## Verification\n\nx\n'; } > "$P"
}
s7() { git -C "$R" rev-parse "$1" | cut -c1-7; }
# round <verdict and fields> [head]: one round line for base..H (or another head)
round() { printf -- '- Round 1: %s..%s -- %s' "$(s7 base)" "$(s7 "${2:-$H}")" "$1"; }
GOOD="approved; blocking: 0; follow-ups: 1; risk: low; invariants: none; by: review-1"
rt() { run "$R" route --plan "$P" --base "$FROM" --head "$H" "$@"; }
# only_reason <label> <text>: person, exit 10, exactly one reason, with the text
only_reason() {
  if [ "$EC" = 10 ] && [ "$(line route)" = "route: person" ] && [ "$(printf '%s\n' "$OUT" | grep -c '^reason: ')" = 1 ]; then
    has "$1" "$2" "$OUT"
  else bad "$1" "exit $EC: $OUT"; fi
}
unattended() { if [ "$EC" = 0 ] && [ "$(line route)" = "route: unattended" ]; then ok "$1"; else bad "$1" "exit $EC: $OUT"; fi; }

change "$R" ordinary 'echo b >> src/auth/login.sh'
plan_with "$(round "$GOOD")"; rt --author worker-1
eq "every condition holds: exit 0" 0 "$EC"
eq "and the whole output" "route: unattended
class: low
ceiling: low
floor: low
areas: auth" "$OUT"

# condition 1: the floor
change "$R" uncovered 'mkdir -p tools && echo x > tools/x.sh'
plan_with "$(round "$GOOD")"; rt --author worker-1
only_reason "a floor of person" "reason: tools/x.sh -- always a person: no area covers this path"
eq "the class is then person" "class: person" "$(line class)"

# condition 2: the review
change "$R" ordinary 'echo b >> src/auth/login.sh'
plan_with; rt --author worker-1
only_reason "no round line" 'reason: review -- the plan has no round line under "## Review"'
eq "the class is then unstated" "class: unstated" "$(line class)"
plan_with "$(round "changes requested; blocking: 2; follow-ups: 0; risk: low; invariants: none; by: review-1")"; rt --author worker-1
only_reason "a round that does not approve" "reason: review -- the newest round line says 'changes requested', not approved"
plan_with "$(round "approved; blocking: 0; follow-ups: 1")"; rt --author worker-1
only_reason "a round line without the three new fields" "reason: review -- the newest round line does not state: risk, invariants, by"
plan_with "$(round "approved; blocking: 0; follow-ups: 0; risk: tiny; invariants: none; by: review-1")"; rt --author worker-1
only_reason "a risk outside the three classes" "the risk 'tiny', which is not low, normal or high"
plan_with "$(round "approved; blocking: 0; follow-ups: 0; risk: low; invariants: auth: tokens expire; sessions too; by: review-1")"; rt --author worker-1
only_reason "a touched invariant" "reason: review -- the reviewer named an invariant or decision the change touches: auth: tokens expire; sessions too"
plan_with "$(round "$GOOD")"; rt --author review-1
only_reason "the reviewer is the author" "reason: review -- the reviewer 'review-1' is the author of the change"
rt
only_reason "no --author" "reason: review -- no --author given: that the reviewer is not the author cannot be checked"
plan_with "$(round "$GOOD" base | sed 's/\.\.[0-9a-f]*/..0000000/')"; rt --author worker-1
only_reason "a round that names no commit" "reason: review -- the newest round line names '0000000', which is no commit here"
plan_with "- Round 1: $(s7 base)..$(s7 "$H") -- changes requested; blocking: 1; follow-ups: 0; risk: low; invariants: none; by: review-1" \
  "- Round 2: $(s7 "$H")..$(s7 "$H") -- $GOOD"; rt --author worker-1
unattended "the newest round counts: changes requested, then approved"
plan_with "- Round 1: $(s7 base)..$(s7 "$H") -- $GOOD" \
  "- Round 2: $(s7 "$H")..$(s7 "$H") -- changes requested; blocking: 1; follow-ups: 0; risk: low; invariants: none; by: review-1"; rt --author worker-1
only_reason "the newest round counts: approved, then changes requested" "not approved"

# valid for a head
REVIEWED=$H
FROM=$REVIEWED
change "$R" records-after 'echo x > .ytstack/M001-S01-T01-SUMMARY.md; echo x >> .ytstack/STATE.md'
FROM=base
plan_with "$(round "$GOOD" "$REVIEWED")"; rt --author worker-1
unattended "a round stays valid when only process records changed since"
FROM=$REVIEWED
change "$R" code-after 'echo x > src/auth/later.sh'
FROM=base
plan_with "$(round "$GOOD" "$REVIEWED")"; rt --author worker-1
only_reason "a round is not valid when a file of the change came after it" "reason: review -- the newest round reviewed $(s7 "$REVIEWED") and 1 path(s) changed since, first src/auth/later.sh: it is not valid for $(s7 "$H")"

# condition 3: the class and the ceiling
change "$R" ordinary 'echo b >> src/auth/login.sh'
plan_with "$(round "approved; blocking: 0; follow-ups: 0; risk: normal; invariants: none; by: review-1")"; rt --author worker-1
only_reason "a stated risk above the ceiling" "reason: class -- normal is above the ceiling low of the touched areas (auth)"
change "$R" token 'mkdir -p src/auth/token && echo x > src/auth/token/t.sh'
plan_with "$(round "$GOOD")"; rt --author worker-1
only_reason "a floor above the ceiling, whatever the reviewer states" "reason: class -- normal is above the ceiling low of the touched areas (auth)"
eq "the class is the higher of floor and stated risk" "class: normal" "$(line class)"
change "$R" billing 'echo b >> src/billing/invoice.sh'
plan_with "$(round "approved; blocking: 0; follow-ups: 0; risk: high; invariants: none; by: review-1")"; rt --author worker-1
only_reason "high is above every ceiling" "reason: class -- high is above the ceiling normal of the touched areas (billing)"
change "$R" sql 'echo x > src/billing/q.sql'
plan_with "$(round "approved; blocking: 0; follow-ups: 0; risk: normal; invariants: none; by: review-1")"; rt --author worker-1
eq "a normal change within a normal ceiling: the whole output, without the never-low reason" "route: unattended
class: normal
ceiling: normal
floor: normal
areas: billing" "$OUT"
change "$R" pkg 'echo b >> pkg/readme.txt'
plan_with "$(round "$GOOD")"; rt --author worker-1
only_reason "an area that declares no auto_merge" "reason: class -- low is above the ceiling none of the touched areas (pkg)"
change "$R" recordsonly 'echo x >> .ytstack/STATE.md'
plan_with "$(round "$GOOD")"; rt --author worker-1
only_reason "a change that touches no area" "reason: class -- low is above the ceiling none of the touched areas (none)"

# usage
run "$R" route --base base --head "$H";                      eq "route without --plan: usage" 64 "$EC"
run "$R" route --plan "$TMP/none.md" --base base --head "$H"; eq "a plan file that does not exist: usage" 64 "$EC"
run "$R" route --plan "$P" --base nowhere --head "$H";       eq "route with a base that names no commit: 65" 65 "$EC"
run "$R" floor --plan "$P" --base base --head "$H";          eq "floor takes no --plan" 64 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
