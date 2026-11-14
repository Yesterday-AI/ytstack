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
#                   has no Git section and asks for the class of the change
#                   (Risk, Severity, Reach, Invariants touched); prepare
#                   commits nothing
#   render --lens   a review brief with a section "Lens": the lens line of the
#                   REVIEW.md at --head, its reads documents, the rules of
#                   every lens; for "evidence: visual" the evidence rules, the
#                   evidence directory under the main checkout and the skill
#                   to load; no class is asked. A lens the policy does not
#                   define and a reads document that is not at --head: exit 1,
#                   no brief
#   failures        no plan, no Files section, no contract: exit 1, no brief;
#                   usage errors: exit 64
#   check           a complete report passes; a missing or empty label, a
#                   "Checks run:" without an exit code, a "Status:" outside the
#                   three values and one that contradicts "Blockers:" are
#                   named, exit 1; the four labels of a review stand together,
#                   and "Risk:" is low, normal or high; "Lens:" and "Evidence:"
#                   stand together and have their two forms
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
has "review: the reviewer is not the author and states the class" "You are not the author of this change, and you state its class; its author never does." "$K"
has "review: the four labels" 'four more labels, each at the start of a line: `Risk: <low | normal | high>`, `Severity: <' "$K"
has "review: the last of the four" '`Invariants touched: <none | area: the invariant or decision, in its own words>`' "$K"
has "review: what makes a change high" '`high`: the change touches an invariant or a decision that applies now' "$K"
has "review: the change is read against invariants and decisions" '"Invariants and security boundaries" and "Decisions that apply now" of every area file under "Read for context"' "$K"
has "review: a rule shifted in code alone is named" "also when the change edits only code and leaves the document alone" "$K"
hasnt "an implementer is not asked for the class" "Invariants touched" "$DEFAULT"
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

# ---- 4. render --lens ---------------------------------------------------------
echo "# render --lens"
# A policy with a visual lens, a lens without evidence that names a skill, and
# a lens whose document was never committed.
R=$(new_repo lens); plan "$R/.ytstack/M001-S01-T01-PLAN.md" "Login accepts a token"
mkdir -p "$R/.ytstack/spec" "$R/docs"
echo design > "$R/docs/design.md"; echo product > "$R/docs/product.md"; echo auth > "$R/docs/auth.md"
printf '# Review policy\n\n## Lenses\n\n- ui | applies: src/ui/**, **/*.css | reads: docs/design.md, docs/product.md | evidence: visual\n- security | applies: src/auth/** | reads: docs/auth.md | evidence: none | skill: acme:threat-model\n- ghost | applies: src/** | reads: docs/gone.md | evidence: none\n' > "$R/.ytstack/spec/REVIEW.md"
( cd "$R" && git add -A && git commit -qm "policy" ) >/dev/null 2>&1
H=$(git -C "$R" rev-parse HEAD); H7=${H:0:7}

run "$R" render --task M001-S01-T01 --kind review --lens ui --head "$H7"
eq "a lens brief renders" 0 "$EC"
eq "with the section Lens after Kind" "Outcome,Kind,Lens,Scope,Read for context,Verification,Spec impact,Work contract,Report," \
  "$(printf '%s\n' "$OUT" | sed -n 's/^## //p' | tr '\n' ',')"
K=$(part Kind)
has "lens: Kind pins the commit, read only" "review exactly the commit \`$H7\`" "$K"
has "lens: Kind says what kind of review this is" 'This is a lens review: a second, independent review with one question' "$K"
has "lens: the verdict has three values" 'Its verdict is `pass`, `fail` or `not run` and stands under `Lens:`.' "$K"
hasnt "lens: no class is asked" "Invariants touched" "$K"
hasnt "lens: no approving verdict is asked" 'changes requested' "$K"
L=$(part Lens)
has "lens: the line of REVIEW.md" '    - ui | applies: src/ui/**, **/*.css | reads: docs/design.md, docs/product.md | evidence: visual' "$L"
has "lens: its documents as a list" '- `docs/design.md`
- `docs/product.md`' "$L"
has "lens: nothing else is reviewed against" "and against nothing else:" "$L"
has "lens: the reviewer is not the author" "You are not the author of this change and you start with a fresh context" "$L"
has "lens: not run is no pass" '`not run` never counts as `pass`, and a partial look is no pass.' "$L"
has "lens: a document that cannot be read" 'means the lens cannot run: `not run`.' "$L"
has "visual: the skill to load" 'Load the skill `ytstack:visual-review` and follow it' "$L"
has "visual: the file of that skill, for a host without a skill tool" "\`$ROOT/skills/visual-review/SKILL.md\`" "$L"
has "visual: the reviewer starts the product itself" 'through `bin/ytstack-runtime up`, and operate it in a browser' "$L"
has "visual: the author's images do not count" "Images from the author do not count. Reading code or the DOM does not count as this lens." "$L"
has "visual: where the images go" "under \`.ytstack/evidence/M001-S01-T01/$H7/ui\`" "$L"
has "visual: the path starts at the main checkout" "the root of the main checkout of the repository (\`$R\`), not at your worktree" "$L"
has "visual: the three ways to not run" 'no browser tool that renders the page and returns a screenshot you can look at: the verdict is `not run`.' "$L"
has "lens: the two labels of the report" '`Lens: ui -- <pass | fail | not run>` and `Evidence: <directory> (<n> images)`' "$L"
hasnt "lens: template markers are filled" "{{" "$L"
has "lens: the report shape and the contract stay" "## Work contract" "$OUT"

printf 'evidence_dir: review/shots/\n' > "$R/.ytstack/PREFERENCES.md"
git -C "$R" worktree add -q -b lens-wt "$TMP/lens-wt" >/dev/null 2>&1
cp "$R/.ytstack/PREFERENCES.md" "$TMP/lens-wt/.ytstack/PREFERENCES.md"
run "$TMP/lens-wt" render --task M001-S01-T01 --kind review --lens ui --head "$H" --base "$H7"
L=$(part Lens)
has "visual: evidence_dir from PREFERENCES, the short commit from a full one" "under \`review/shots/M001-S01-T01/$H7/ui\`" "$L"
has "visual: from a linked worktree the root is still the main checkout" "(\`$R\`), not at your worktree" "$L"
rm -f "$R/.ytstack/PREFERENCES.md"

run "$R" render --task M001-S01-T01 --kind review --lens security --head "$H7"
eq "a lens without evidence renders" 0 "$EC"
L=$(part Lens)
has "none: the report says so" 'This lens asks for no evidence: the report says `Evidence: none`.' "$L"
has "none: the project's skill for the lens" 'load `acme:threat-model` before you start' "$L"
hasnt "none: no visual rules" "visual-review" "$L"
run "$R" render --task M001-S01-T01 --kind review --head "$H7"
hasnt "a review without --lens has no Lens section" "## Lens" "$OUT"

run "$R" render --task M001-S01-T01 --kind review --lens motion --head "$H7"
eq "a lens the policy does not define: exit 1" 1 "$EC"
has "names the lens and the commit" "no lens 'motion' in .ytstack/spec/REVIEW.md at $H7" "$OUT"
eq "and prints no brief" "" "$(bash "$BIN" -C "$R" render --task M001-S01-T01 --kind review --lens motion --head "$H7" 2>/dev/null)"
echo later > "$R/docs/gone.md"
run "$R" render --task M001-S01-T01 --kind review --lens ghost --head "$H7"
eq "a reads document that is not at the reviewed commit: exit 1" 1 "$EC"
has "names the document" "lens ghost reads docs/gone.md, which does not exist at $H7: the lens cannot run" "$OUT"
eq "and prints no brief" "" "$(bash "$BIN" -C "$R" render --task M001-S01-T01 --kind review --lens ghost --head "$H7" 2>/dev/null)"
rm -f "$R/docs/gone.md"
run "$R" render --task M001-S01-T01 --kind review --lens ui --head abc1234
eq "a head that is no commit of the repository: exit 1" 1 "$EC"
R2=$(new_repo nolens); plan "$R2/.ytstack/M001-S01-T01-PLAN.md" "x"
( cd "$R2" && git add -A && git commit -qm plan ) >/dev/null 2>&1
run "$R2" render --task M001-S01-T01 --kind review --lens ui --head "$(git -C "$R2" rev-parse --short=7 HEAD)"
eq "a project without REVIEW.md has no lens: exit 1" 1 "$EC"
run "$R" render --task M001-S01-T01 --lens ui
eq "--lens without --kind review: exit 64" 64 "$EC"
run "$R" render --task M001-S01-T01 --kind review --lens 'UI kit' --head "$H7"
eq "a lens name that is no lowercase slug: exit 64" 64 "$EC"

# ---- 5. failures --------------------------------------------------------------
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
grep -v '^<!-- round-review: ' "$ROOT/skills/spawn-milestone-team/brief-template.md" > "$T/skills/spawn-milestone-team/brief-template.md"
OUT=$(bash "$T/bin/ytstack-brief" -C "$R" render --task M001-S01-T01 --kind review --head abc1234 2>&1); EC=$?
eq "a template that does not ask a reviewer for the class: exit 1" 1 "$EC"
has "names what is missing" "no 'round-review' sentences" "$OUT"

# ---- 6. check -----------------------------------------------------------------
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

# The class of a change: what a reviewer adds after the eleven labels.
REVIEW="$GOOD
Risk: high
Severity: archived rows reach a customer's export
Reach: one area, stored data
Invariants touched: export: archived rows are never exported"
chk "$REVIEW"
eq "a review report with the four labels passes" "report ok" "$OUT"
chk "$(printf '%s\n' "$REVIEW" | sed 's/^Risk:.*/Risk: medium/')"
eq "a Risk outside the three classes fails" 1 "$EC"
eq "and is quoted" 'Risk: "medium" is not low, normal or high' "$OUT"
chk "$(printf '%s\n' "$REVIEW" | grep -v '^Invariants touched:')"
eq "three of the four labels: the fourth is named" "missing: Invariants touched" "$OUT"
chk "$(printf '%s\n' "$REVIEW" | sed 's/^Reach:.*/Reach:/')"
eq "one of the four without a value is named" "empty: Reach" "$OUT"
chk "$GOOD
Severity: a wrong total on one invoice"
eq "one of the four alone: the other three are named" "missing: Risk
missing: Reach
missing: Invariants touched" "$OUT"

# The verdict of a lens and its evidence.
LENS="$GOOD
Lens: ui -- pass
Evidence: .ytstack/evidence/M001-S01/abc1234/ui (5 images)"
chk "$LENS"
eq "a lens report with its two labels passes" "report ok" "$OUT"
chk "$(printf '%s\n' "$LENS" | sed -e 's/^Lens:.*/Lens: ui -- not run/' -e 's/^Evidence:.*/Evidence: none/')"
eq "a lens that did not run, without evidence, passes the check" "report ok" "$OUT"
chk "$(printf '%s\n' "$LENS" | sed 's/^Lens:.*/Lens: ui -- looks fine/')"
eq "a verdict outside the three fails" 1 "$EC"
eq "and is quoted" 'Lens: "ui -- looks fine" is not "<name> -- pass", "<name> -- fail" or "<name> -- not run"' "$OUT"
chk "$(printf '%s\n' "$LENS" | grep -v '^Evidence:')"
eq "a verdict without the evidence label fails" "missing: Evidence" "$OUT"
chk "$(printf '%s\n' "$LENS" | sed 's/^Evidence:.*/Evidence: five screenshots, attached/')"
eq "evidence that is neither none nor a directory with a count fails" 'Evidence: "five screenshots, attached" is neither "none" nor "<directory> (<n> images)"' "$OUT"

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
