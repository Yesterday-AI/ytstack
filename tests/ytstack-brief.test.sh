#!/usr/bin/env bash
# Tests for bin/ytstack-brief: the brief a dispatched worker gets and the check
# of the report it sends back.
#
# Contract:
#   render --task   every section in the fixed order, one "# " heading; the
#                   plan's parts verbatim; the work contract identical to the
#                   body of skills/minimal-code/SKILL.md; the area file when a
#                   technical spec covers the planned files; Gates only when
#                   the plan has some; Git only with --branch
#   render --slice  goal and task list; per planned task its parts; a task
#                   without a plan is named as not planned
#   render --kind   "## Kind" says what the worker may do: implement (the
#                   default) commits with the prefix; review is read only, pins
#                   the range from --head (a commit hash, required) and --base,
#                   and has no Git section; prepare commits nothing
#   failures        no plan, no Files section, no contract: exit 1, no brief;
#                   usage errors: exit 64
#   check           a complete report passes; a missing or empty label, a
#                   "Checks run:" without an exit code, a "Status:" outside the
#                   three values and one that contradicts "Blockers:" are
#                   named, exit 1
#
# Run: /bin/bash tests/ytstack-brief.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-brief"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-brief exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytbrief.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

# run <dir> <args...>: sets OUT (stdout + stderr) and EC
run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
# part <heading>: the body of one "## " section of the brief in OUT
part() { printf '%s\n' "$OUT" | awk -v h="## $1" '/^## / { on = ($0 == h); next } on'; }

new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/.ytstack" "$d/src/auth"
  ( cd "$d" && git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false )
  printf -- '---\nname: "acme"\nscope: project\n---\n\n# acme\n' > "$d/.ytstack/PROJECT.md"
  printf '# Knowledge\n' > "$d/.ytstack/KNOWLEDGE.md"
  echo a > "$d/src/auth/login.sh"
  ( cd "$d" && git add -A && git commit -qm base ) >/dev/null 2>&1
  echo "$d"
}
# plan <file> <summary> [gates: yes]
plan() {
  {
    printf -- '---\nstatus: planned\n---\n\n# Task Plan\n\n**Summary:** %s\n\n' "$2"
    printf '## Files\n\n- Modify: `src/auth/login.sh:10-20`\n- Create: `tests/login.test.sh`\n\n'
    printf '## What this does\n\nThe login reads the token and compares it.\n\n'
    printf '## Spec impact\n\n- auth: Behavior -- login accepts a token\n\n'
    printf '## Verification\n\n```bash\nbash tests/login.test.sh\n```\n\nRuns: 3. Environment: CI.\n\n'
    [ "${3:-}" != yes ] || printf '## Gates\n\n- [ ] G01 -- sign-off | decides: Sam | how: reads the diff | lapses: at release\n\n'
    printf '## Done signal\n\nRun summarize-task.\n'
  } > "$1"
}
# without <file> <heading>: drop one "## " section from a plan
without() { awk -v h="## $2" '/^## / { skip = ($0 == h) } !skip' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

# ---- 1. render --task ---------------------------------------------------------
echo "# render --task"
R=$(new_repo task); P="$R/.ytstack/M001-S01-T01-PLAN.md"
plan "$P" "Login accepts a token" yes
run "$R" render --task M001-S01-T01 --branch ytstack/M001-S01
eq "a planned task renders" 0 "$EC"
eq "title with ref and project name" "# Brief: M001-S01-T01 (acme)" "$(printf '%s\n' "$OUT" | head -1)"
eq "one first-level heading" 1 "$(printf '%s\n' "$OUT" | grep -c '^# ')"
eq "every section, in order" "Outcome,Kind,Scope,Read for context,Verification,Spec impact,Gates,Git,Work contract,Report," \
  "$(printf '%s\n' "$OUT" | sed -n 's/^## //p' | tr '\n' ',')"
K=$(part Kind)
has "Kind: implement unless --kind says otherwise" "Implement: change the files named under Scope and no others." "$K"
has "Kind: the commit prefix" 'Commit each task with the prefix `M001-S01-T01:`.' "$K"
eq "Outcome: summary and what the task does" "Login accepts a token

The login reads the token and compares it." "$(part Outcome | sed '1{/^$/d;}' | sed '$d')"
S=$(part Scope)
has "Scope: the plan's files" '- Create: `tests/login.test.sh`' "$S"
has "Scope: outside is a blocker" "Anything outside these files is reported as a blocker, not changed." "$S"
C=$(part "Read for context")
has "Context: the plan file" '- `.ytstack/M001-S01-T01-PLAN.md`' "$C"
has "Context: what is not needed" "are not needed for this task" "$C"
hasnt "Context: no spec named without a spec" "spec/SPEC.md" "$C"
has "Context: without a spec, KNOWLEDGE.md stands in" '- `.ytstack/KNOWLEDGE.md`' "$C"
V=$(part Verification)
has "Verification: the command block" '```bash
bash tests/login.test.sh
```' "$V"
has "Verification: runs and environment" "Runs: 3. Environment: CI." "$V"
has "Spec impact: from the plan" "- auth: Behavior -- login accepts a token" "$(part "Spec impact")"
G=$(part Gates)
has "Gates: the plan's gate" "- [ ] G01 -- sign-off | decides: Sam" "$G"
has "Gates: never given by the worker" "A gate is never recorded as given by the worker." "$G"
G=$(part Git)
has "Git: checkout, base defaults to the current branch" "git checkout -B ytstack/M001-S01 main" "$G"
has "Git: commit prefix" 'prefix `M001-S01-T01:`' "$G"
has "Git: no merge, no push" "Do not merge or push." "$G"
has "Report: the shape, down to its last label" "Next: <" "$(part Report)"
hasnt "template comments stay out" "<!--" "$OUT"

# The contract in the brief, headings moved back up, is the body of the real file.
WANT=$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm { if ($0 == "---") fm = 0; next } NF || body { print; body = 1 }' "$ROOT/skills/minimal-code/SKILL.md")
GOT=$(printf '%s\n' "$OUT" | awk '/^## Report$/ { on = 0 } on && (NF || body) { print; body = 1 } /^## Work contract$/ { on = 1 }' | sed 's/^##\(##* \)/\1/')
if [ -n "$WANT" ] && [ "$GOT" = "$WANT" ]; then ok "the contract is the body of skills/minimal-code/SKILL.md"; else bad "the contract is the body of skills/minimal-code/SKILL.md" "$(printf '%s\n' "$GOT" | head -3)"; fi

run "$R" render --task M001-S01-T01 --branch work --base dev
has "--base names the branch to fork from" "git checkout -B work dev" "$OUT"
plan "$P" "Login accepts a token"
run "$R" render --task M001-S01-T01
hasnt "no --branch: no Git section" "## Git" "$OUT"
hasnt "no gates in the plan: no Gates section" "## Gates" "$OUT"

without "$P" Verification
run "$R" render --task M001-S01-T01
eq "a plan without Verification still renders" 0 "$EC"
has "and tells the worker to stop" "No verification command in the plan. Stop and report this as a blocker." "$(part Verification)"
without "$P" "Spec impact"
run "$R" render --task M001-S01-T01
has "a plan without Spec impact says so" "not stated in the plan" "$(part "Spec impact")"

# shellcheck disable=SC2016
plan "$P" 'Fix a & b in `$HOME/x` s/a/b/ {{REF}} \1 100%'
run "$R" render --task M001-S01-T01
# shellcheck disable=SC2016
has "a value with &, backticks, \$, / and a marker survives" 'Fix a & b in `$HOME/x` s/a/b/ {{REF}} \1 100%' "$(part Outcome)"

# a technical spec: the entry point and the area that covers the planned files
mkdir -p "$R/.ytstack/spec"
printf -- '---\nproject: acme\n---\n\n# spec\n' > "$R/.ytstack/spec/SPEC.md"
printf -- '---\narea: auth\nstatus: planned\npaths:\n  - src/auth/**\n---\n' > "$R/.ytstack/spec/auth.md"
printf -- '---\narea: billing\nstatus: planned\npaths:\n  - src/billing/**\n---\n' > "$R/.ytstack/spec/billing.md"
run "$R" render --task M001-S01-T01
C=$(part "Read for context")
has "Context: the spec entry point" '- `.ytstack/spec/SPEC.md`' "$C"
has "Context: the area that covers the files (line range ignored)" '- `.ytstack/spec/auth.md`' "$C"
hasnt "Context: no other area" "billing.md" "$C"

# a planned path with a space inside the backticks still reaches the area lookup
printf -- '---\narea: pay\nstatus: planned\npaths:\n  - src/pay/**\n---\n' > "$R/.ytstack/spec/pay.md"
P2="$R/.ytstack/M001-S01-T02-PLAN.md"; plan "$P2" "Spaced file"
awk '{ sub(/`src\/auth\/login\.sh:10-20`/, "`src/pay/login page.sh:3-4`"); print }' "$P2" > "$P2.tmp" && mv "$P2.tmp" "$P2"
run "$R" render --task M001-S01-T02
C=$(part "Read for context")
has "Context: the area of a spaced filename (line range ignored)" '- `.ytstack/spec/pay.md`' "$C"
hasnt "Context: no unrelated area for the spaced filename" "auth.md" "$C"
rm -f "$P2" "$R/.ytstack/spec/pay.md"

mkdir -p "$R/.ytstack/milestones/M002"
plan "$R/.ytstack/milestones/M002/M002-S01-T01-PLAN.md" "Nested layout"
run "$R" render --task M002-S01-T01
has "a plan under milestones/M###/ is found" '- `.ytstack/milestones/M002/M002-S01-T01-PLAN.md`' "$OUT"

# ---- 2. render --slice --------------------------------------------------------
echo "# render --slice"
R=$(new_repo slice)
printf -- '---\nstatus: planned\n---\n\n# Slice Plan\n\n**Goal:** Token login works end to end\n\n## Tasks\n\n- [ ] T01 -- accept a token\n- [ ] T02 -- reject an expired token\n\n## Gates\n\n- [ ] G01 -- pilot customer agrees | decides: Kim | how: call | lapses: unknown\n\n## Done when\n\nAll tasks done.\n' > "$R/.ytstack/M001-S01-PLAN.md"
plan "$R/.ytstack/M001-S01-T01-PLAN.md" "Accept a token" yes
run "$R" render --slice M001-S01 --branch ytstack/M001-S01
eq "a slice with one planned and one unplanned task renders" 0 "$EC"
O=$(part Outcome)
has "Outcome: the goal" "Token login works end to end" "$O"
has "Outcome: the task list" "- [ ] T02 -- reject an expired token" "$O"
S=$(part Scope)
has "Scope: the planned task's files under its label" '**T01**

- Modify: `src/auth/login.sh:10-20`' "$S"
has "Scope: the unplanned task is named as such" "**T02** -- not planned yet: run ytstack:plan-task first, or plan it yourself with exact files and a verification command before you write code" "$S"
C=$(part "Read for context")
has "Context: the slice plan" '- `.ytstack/M001-S01-PLAN.md`' "$C"
has "Context: the task plan" '- `.ytstack/M001-S01-T01-PLAN.md`' "$C"
V=$(part Verification)
has "Verification: the planned task's command" "bash tests/login.test.sh" "$V"
has "Verification: the unplanned task points at its plan" "**T02** -- comes with its plan, see Scope" "$V"
hasnt "Verification: no blocker for a task that is only unplanned" "Stop and report" "$V"
G=$(part Gates)
has "Gates: the slice's gate" "G01 -- pilot customer agrees" "$G"
has "Gates: the task's gate" "G01 -- sign-off" "$G"
has "Git: one prefix per task" 'prefix `M001-S01-T##:`' "$(part Git)"

# granularity: slice -- the slice plan carries Files and Verification itself
plan "$R/.ytstack/M002-S01-PLAN.md" "unused"
printf '\n**Goal:** Whole slice in one plan\n\n## Tasks\n\n- [ ] T01 -- all of it\n' >> "$R/.ytstack/M002-S01-PLAN.md"
run "$R" render --slice M002-S01
hasnt "a slice plan with its own Files has no unplanned tasks" "not planned yet" "$OUT"
has "and its own files are the scope" '- Create: `tests/login.test.sh`' "$(part Scope)"

# ---- 3. render --kind ---------------------------------------------------------
echo "# render --kind"
R=$(new_repo kind); plan "$R/.ytstack/M001-S01-T01-PLAN.md" "Login accepts a token"
run "$R" render --task M001-S01-T01 --branch work; DEFAULT=$OUT
run "$R" render --task M001-S01-T01 --branch work --kind implement
eq "--kind implement renders" 0 "$EC"
eq "and is the brief without --kind" "$DEFAULT" "$OUT"

run "$R" render --task M001-S01-T01 --kind review --head abc1234 --base def5678 --branch work
eq "--kind review renders" 0 "$EC"
K=$(part Kind)
has "review: the pinned range" 'review exactly the range `def5678..abc1234`' "$K"
has "review: read only" "Change nothing: no file, no commit, no branch." "$K"
has "review: how findings are reported" "per finding a concrete case and what happens if it is skipped" "$K"
has "review: the verdict goes into Outcome" '`Outcome:` carries the verdict (`approved` or `changes requested`) and the reviewed commit.' "$K"
hasnt "review: no commit rule" "Commit each task" "$OUT"
hasnt "review: no Git section, even with --branch" "## Git" "$OUT"
has "review: the work contract is included" "## Work contract" "$OUT"
has "review: the report shape is included" "Status: <complete | partial | blocked>" "$(part Report)"
run "$R" render --task M001-S01-T01 --kind review --head abc1234
has "review without --base: the one commit" 'review exactly the commit `abc1234`' "$(part Kind)"
run "$R" render --task M001-S01-T01 --kind review
eq "review without --head: exit 64" 64 "$EC"
run "$R" render --task M001-S01-T01 --kind review --head main
eq "review with a branch name as --head: exit 64" 64 "$EC"
has "and says that a name pins nothing" "--head 'main' is not a commit hash" "$OUT"
run "$R" render --task M001-S01-T01 --kind review --head abc1234 --base main
eq "review with a branch name as --base: exit 64" 64 "$EC"
run "$R" render --task M001-S01-T01 --head abc1234
eq "--head without --kind review: exit 64" 64 "$EC"
run "$R" render --task M001-S01-T01 --kind audit
eq "an unknown kind: exit 64" 64 "$EC"

run "$R" render --task M001-S01-T01 --kind prepare
eq "--kind prepare renders" 0 "$EC"
K=$(part Kind)
has "prepare: writes inside Scope" "Prepare: write the files named under Scope and no others." "$K"
has "prepare: commits nothing" "Commit nothing." "$K"
has "prepare: every file goes under Uncommitted" 'List every file you wrote under `Uncommitted:` in the report.' "$K"
hasnt "prepare without --branch: no Git section" "## Git" "$OUT"
run "$R" render --task M001-S01-T01 --kind prepare --branch work
G=$(part Git)
has "prepare with --branch: the checkout stays" "git checkout -B work main" "$G"
has "prepare with --branch: the commit sentence is replaced" "Commit nothing. Do not merge or push." "$G"
hasnt "prepare: no commit prefix anywhere" "Commit each task" "$OUT"

# ---- 4. failures --------------------------------------------------------------
echo "# failures"
run "$R" render --task M001-S01-T09
eq "no plan: exit 1" 1 "$EC"
has "names the path it looked for" "$R/.ytstack/M001-S01-T09-PLAN.md" "$OUT"
eq "and prints no brief" "" "$(bash "$BIN" -C "$R" render --task M001-S01-T09 2>/dev/null)"
without "$R/.ytstack/M001-S01-T01-PLAN.md" Files
run "$R" render --task M001-S01-T01
eq "a plan without Files: exit 1" 1 "$EC"
has "names the plan" "no '## Files' section in .ytstack/M001-S01-T01-PLAN.md" "$OUT"
run "$R" render;                              eq "no ref: exit 64" 64 "$EC"
run "$R" render --task M1-S1-T1;              eq "malformed ref: exit 64" 64 "$EC"
run "$R" render --slice M001-S01 --branch;    eq "option without a value: exit 64" 64 "$EC"
run "$R" render --task M001-S01-T01 --force x; eq "unknown option: exit 64" 64 "$EC"
run "$R" publish;                             eq "unknown command: exit 64" 64 "$EC"
run "$TMP/nowhere" render --task M001-S01-T01; eq "-C to a missing directory: exit 64" 64 "$EC"

# A copy of the tool without the contract file refuses to render.
T="$TMP/tool"; mkdir -p "$T/bin" "$T/hooks/lib" "$T/skills/spawn-milestone-team"
cp "$BIN" "$T/bin/"; cp "$ROOT/hooks/lib/git-ctx.sh" "$T/hooks/lib/"
cp "$ROOT/skills/spawn-milestone-team/brief-template.md" "$T/skills/spawn-milestone-team/"
R=$(new_repo nocontract); plan "$R/.ytstack/M001-S01-T01-PLAN.md" "x"
OUT=$(bash "$T/bin/ytstack-brief" -C "$R" render --task M001-S01-T01 2>&1); EC=$?
eq "no contract file: exit 1" 1 "$EC"
has "says why" "a brief without it must not be produced" "$OUT"
eq "and prints no brief" "" "$(bash "$T/bin/ytstack-brief" -C "$R" render --task M001-S01-T01 2>/dev/null)"
# The same copy with the contract, and a template that lost the sentences of one kind.
mkdir -p "$T/skills/minimal-code"; cp "$ROOT/skills/minimal-code/SKILL.md" "$T/skills/minimal-code/"
grep -v '^<!-- kind-review: ' "$ROOT/skills/spawn-milestone-team/brief-template.md" > "$T/skills/spawn-milestone-team/brief-template.md"
OUT=$(bash "$T/bin/ytstack-brief" -C "$R" render --task M001-S01-T01 --kind review --head abc1234 2>&1); EC=$?
eq "a template without the kind's sentences: exit 1" 1 "$EC"
has "names the kind" "no 'kind-review' sentences" "$OUT"

# ---- 5. check -----------------------------------------------------------------
echo "# check"
GOOD='Task: M001-S01-T01
Status: complete
Outcome: Login accepted a token in the test.
Commits: abc1234 M001-S01-T01: accept a token
Uncommitted: none
Checks run: bash tests/login.test.sh -- exit 0 at abc1234 in local checkout
Spec: auth: .ytstack/spec/auth.md
Deviations: none
Blockers: none
Not checked: the CI run, it starts after the push
Next: dispatch the verifier on abc1234'
# chk <report text>: sets OUT and EC
chk() { OUT=$(printf '%s\n' "$1" | bash "$BIN" check 2>&1); EC=$?; }

chk "$GOOD"
eq "a complete report passes" 0 "$EC"
eq "and says so" "report ok" "$OUT"
printf '%s\n' "$GOOD" > "$TMP/report.txt"
OUT=$(bash "$BIN" check "$TMP/report.txt" 2>&1); eq "a report file is read like stdin" "report ok" "$OUT"

for L in "Task" "Status" "Outcome" "Commits" "Uncommitted" "Checks run" "Spec" "Deviations" "Blockers" "Not checked" "Next"; do
  chk "$(printf '%s\n' "$GOOD" | grep -v "^$L:")"
  if [ "$EC" = 1 ]; then eq "without '$L:' the label is named" "missing: $L" "$OUT"; else bad "without '$L:' the report fails" "exit $EC"; fi
done

chk "$(printf '%s\n' "$GOOD" | sed 's/^Status:.*/Status: mostly done/')"
eq "a Status outside the three values fails" 1 "$EC"
eq "and is quoted" 'Status: "mostly done" is not complete, partial or blocked' "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Status:.*/Status: blocked/')"
eq "Status: blocked with Blockers: none fails" 1 "$EC"
eq "and says what is missing" 'Status: blocked needs a Blockers: value other than "none"' "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Blockers:.*/Blockers: the staging database is down/')"
eq "Status: complete with a blocker fails" 1 "$EC"
eq "and says what it needs" 'Status: complete needs "Blockers: none"' "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed -e 's/^Status:.*/Status: blocked/' -e 's/^Blockers:.*/Blockers: none of the fixtures load/')"
eq "Status: blocked with a blocker passes, also one that starts with 'none'" "report ok" "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed -e 's/^Status:.*/Status: partial/' -e 's/^Blockers:.*/Blockers: None./')"
eq "Status: partial passes with or without a blocker" "report ok" "$OUT"

chk "$(printf '%s\n' "$GOOD" | sed 's/^Not checked:.*/Not checked:   /')"
eq "an empty Not checked fails" 1 "$EC"
eq "and is named" "empty: Not checked" "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Not checked:.*/Not checked:/')

Thanks, that was all."
eq "text after a blank line is not its value" "empty: Not checked" "$OUT"

chk "$(printf '%s\n' "$GOOD" | sed 's/^Checks run:.*/Checks run: the tests passed/')"
eq "Checks run without an exit code fails" 1 "$EC"
eq "and quotes the line" 'Checks run: no exit code in "the tests passed"' "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Checks run:.*/Checks run: none -- a text change, the plan names no command/')"
eq "Checks run: none -- reason passes" 0 "$EC"
chk "$GOOD
Checks run: looked at the page"
eq "a second Checks run line is checked on its own" 'Checks run: no exit code in "looked at the page"' "$OUT"

chk "Here is my report.

\`\`\`
$GOOD
\`\`\`"
eq "a report inside a code fence passes, text before it is ignored" "report ok" "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Commits:.*/Commits:\
abc1234 one\
def5678 two/')"
eq "a value on the lines after its label counts" "report ok" "$OUT"
chk "$(printf '%s\n' "$GOOD" | sed 's/^Task:/- **Task:**/')"
eq "a label that does not start its line is missing" "missing: Task" "$OUT"

# The report shape in the brief and the checker know the same eleven labels:
# the checker misses none in the shape, and the shape has no twelfth.
R=$(new_repo shape); plan "$R/.ytstack/M001-S01-T01-PLAN.md" "x"
run "$R" render --task M001-S01-T01
SHAPE=$(part Report)
eq "the shape names the eleven labels, in the order of the format document" \
  "Task,Status,Outcome,Commits,Uncommitted,Checks run,Spec,Deviations,Blockers,Not checked,Next," \
  "$(printf '%s\n' "$SHAPE" | sed -n 's/^\([A-Z][A-Za-z ]*\): <.*/\1/p' | tr '\n' ',')"
chk "$SHAPE"
eq "the unfilled report shape does not pass" 'Checks run: no exit code in "<command> -- exit <n> at <short sha> in <environment>"
Status: "<complete | partial | blocked>" is not complete, partial or blocked' "$OUT"
chk "$(printf '%s\n' "$SHAPE" | sed -e 's/exit <n>/exit 0/' -e 's/^Status:.*/Status: partial/')"
eq "with an exit code and a status filled in, its labels are complete" "report ok" "$OUT"
OUT=$(bash "$BIN" check "$TMP/none.txt" 2>&1); eq "an unreadable report file: exit 64" 64 "$?"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
