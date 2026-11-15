#!/usr/bin/env bash
# Tests for bin/ytstack-reconcile: the two migration classes of ytstack:reconcile
# (issue #76) that need more than a list.
#
# Contract:
#   skeletons          one line per open task of a slice that has no task plan
#                      at all, in an open milestone: ref, the plan to write
#                      (beside the slice plan), the number of paths found.
#                      Not listed: a slice with one task plan, a slice plan
#                      with its own "## Files", a done slice, a ticked task,
#                      a milestone that is done, dropped, shipped-informally
#                      or backlog. Writes nothing.
#   skeletons --write  writes each listed plan in the format of plan-task:
#                      Files from the task line's backticked paths, else from
#                      the slice plan's "Own:" / "Files:" lines, else a TODO;
#                      Spec impact per area of those paths (TODO lines that
#                      `ytstack-spec impact` does not accept); a TODO
#                      verification. Never overwrites a file.
#   pointer            "pointer: ok" or "pointer: behind" (exit 10) when
#                      current_milestone is older than, or not, the newest
#                      milestone in progress; names the first open slice.
#   pointer --fix      sets current_milestone, active_slice, active_task: none
#                      and last_updated in the frontmatter, nothing else.
#   usage              exit 64; no .ytstack: exit 1
#
# Run: /bin/bash tests/ytstack-reconcile.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-reconcile"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-reconcile exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytrec.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

run() { local d="$1"; shift; OUT=$(bash "$BIN" -C "$d" "$@" 2>&1); EC=$?; }

R="$TMP/proj"; Y="$R/.ytstack"; mkdir -p "$Y/spec" "$R/src/auth" "$R/web"
( cd "$R" || exit 1
  git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false
  echo a > src/auth/login.sh; echo w > web/app.ts
  git add -A && git commit -qm base ) >/dev/null 2>&1 || { echo "FATAL fixture"; exit 2; }
printf -- '---\nname: acme\n---\n' > "$Y/PROJECT.md"
printf -- '---\nlast_updated: 2026-11-01T10:00:00Z\ncurrent_milestone: M044\nactive_slice: S02\nactive_task: T03\n---\n\n# State\n\n**Status:** M044 / S02.\n' > "$Y/STATE.md"
# roadmap <M###> <status> <slice lines>
roadmap() { printf -- '---\nmilestone: %s\nstatus: %s\n---\n\n# %s\n\n%b\n' "$1" "$2" "$1" "$3" > "$Y/$1-ROADMAP.md"; }
# slice <ref> <status> <tasks> [extra]
slice() { printf -- '---\nstatus: %s\n---\n\n# %s -- Slice Plan\n\n**Goal:** g\n\n%b## Tasks\n\n%b\n' "$2" "$1" "${4:-}" "$3" > "$Y/$1-PLAN.md"; }

roadmap M044 done '- [x] S01 -- old\n- [x] S02 -- old'
slice M044-S02 done '- [ ] T04 -- left behind'
roadmap M045 in-progress '- [x] S01 -- a\n- [ ] S02 -- b'
slice M045-S01 done '- [x] T01 -- a'
slice M045-S02 planned '- [ ] T01 -- b'
printf -- '---\ntask: T01\n---\n' > "$Y/M045-S02-T01-PLAN.md"
roadmap M046 in-progress '- [x] S01 -- first\n- [ ] S02 -- login\n- [ ] S03 -- web'
slice M046-S01 done '- [x] T01 -- done'
slice M046-S02 in-progress '- [x] T01 -- token parser in `src/auth/token.sh`\n- [ ] T02 -- reject expired tokens in `src/auth/login.sh` and `tests/login.test.sh`\n- [ ] T03 -- document it'
slice M046-S03 planned '- [ ] T01 -- the page' '**Own:** `web/app.ts`, `web/page.ts`\n\n'
roadmap M047 backlog '- [ ] S01 -- later'
slice M047-S01 planned '- [ ] T01 -- later'
roadmap M048 in-progress '- [ ] S01 -- whole slice'
slice M048-S01 planned '- [ ] T01 -- all' '## Files\n\n- `src/x.sh`\n\n'

# ---- 1. skeletons -------------------------------------------------------------
echo "# skeletons"
run "$R" skeletons
eq "skeletons lists and exits 0" 0 "$EC"
eq "one line per open task of a slice without any task plan, in open milestones" \
"M046-S02-T02	.ytstack/M046-S02-T02-PLAN.md	2
M046-S02-T03	.ytstack/M046-S02-T03-PLAN.md	0
M046-S03-T01	.ytstack/M046-S03-T01-PLAN.md	2" "$OUT"
eq "and writes nothing" "" "$(ls "$Y" | grep -- '-T0[23]-PLAN.md\|M046-S03-T01-PLAN.md')"
run "$R" skeletons --slice M046-S03
eq "--slice keeps the named slice" "M046-S03-T01	.ytstack/M046-S03-T01-PLAN.md	2" "$OUT"
run "$R" skeletons --slice S03;  eq "--slice needs a slice reference" 64 "$EC"

# a technical spec: the area of the paths becomes a Spec impact line to fill
printf -- '---\nproject: acme\n---\n\n# spec\n' > "$Y/spec/SPEC.md"
printf -- '---\narea: auth\nstatus: planned\npaths:\n  - src/auth/**\n---\n' > "$Y/spec/auth.md"
run "$R" skeletons --write
eq "--write: exit 0" 0 "$EC"
has "--write names each file it wrote" "wrote .ytstack/M046-S02-T02-PLAN.md" "$OUT"
P=$(cat "$Y/M046-S02-T02-PLAN.md")
has "frontmatter of a task plan" "milestone: M046
slice: S02
task: T02
project: acme" "$P"
has "status planned" "status: planned" "$P"
has "marked as a skeleton" "skeleton: reconcile" "$P"
has "Summary is the task line" "**Summary:** reject expired tokens in \`src/auth/login.sh\` and \`tests/login.test.sh\`" "$P"
has "Files from the task line" "## Files

- \`src/auth/login.sh\`
- \`tests/login.test.sh\`" "$P"
has "Spec impact: one line per area of those paths, to fill" "- auth: TODO section -- TODO what changes" "$P"
has "Verification: a TODO block" "TODO: one or two commands that show this task done" "$P"
has "the sections plan-task writes" "## What this does" "$P"
P=$(cat "$Y/M046-S03-T01-PLAN.md")
has "Files from the slice plan's Own line when the task line names none" "- \`web/app.ts\`
- \`web/page.ts\`" "$P"
has "a path no area covers: the Spec impact says so, to confirm" "TODO: none -- not covered by an area" "$P"
P=$(cat "$Y/M046-S02-T03-PLAN.md")
has "no path anywhere: a TODO for the files" "- TODO: the exact paths" "$P"
OUTP=$(bash "$ROOT/bin/ytstack-spec" -C "$R" impact --plan "$Y/M046-S02-T02-PLAN.md" --base HEAD 2>&1); ECP=$?
eq "an unfilled Spec impact does not pass ytstack-spec impact" 1 "$ECP"
run "$R" skeletons
eq "after --write the slice has task plans and is not listed again" "" "$OUT"
echo mine > "$Y/M046-S03-T01-PLAN.md"; rm -f "$Y/M046-S02-T02-PLAN.md" "$Y/M046-S02-T03-PLAN.md"
run "$R" skeletons --write
eq "an existing plan is never overwritten" "mine" "$(cat "$Y/M046-S03-T01-PLAN.md")"
rm -f "$Y"/M046-S0[23]-T0[123]-PLAN.md

# a plan under milestones/M###/ (the nested layout) is found and written beside its slice plan
mkdir -p "$Y/milestones/M049"
roadmap M049 in-progress '- [ ] S01 -- nested'; mv "$Y/M049-ROADMAP.md" "$Y/milestones/M049/"
slice M049-S01 planned '- [ ] T01 -- nested in `src/n.sh`'; mv "$Y/M049-S01-PLAN.md" "$Y/milestones/M049/"
run "$R" skeletons
has "a nested slice is listed with its own directory" "M049-S01-T01	.ytstack/milestones/M049/M049-S01-T01-PLAN.md	1" "$OUT"
rm -rf "$Y/milestones"

# ---- 2. pointer ---------------------------------------------------------------
echo "# pointer"
run "$R" pointer
eq "a pointer behind the newest milestone in progress: exit 10" 10 "$EC"
eq "names both and the first open slice" "pointer: behind -- current_milestone M044, active_slice S02; newest milestone in progress: M048, first open slice S01" "$OUT"
roadmap M048 done '- [x] S01 -- whole slice'
run "$R" pointer
eq "the newest in progress is the target, not a backlog or done milestone" "pointer: behind -- current_milestone M044, active_slice S02; newest milestone in progress: M046, first open slice S02" "$OUT"
cp "$Y/STATE.md" "$TMP/state.before"
run "$R" pointer --fix
eq "--fix: exit 0" 0 "$EC"
eq "--fix says what it changed" "fixed: current_milestone M044 -> M046, active_slice S02 -> S02, active_task T03 -> none" "$OUT"
S=$(cat "$Y/STATE.md")
has "current_milestone set" "current_milestone: M046" "$S"
has "active_task reset" "active_task: none" "$S"
hasnt "last_updated moved" "last_updated: 2026-11-01T10:00:00Z" "$S"
eq "the body is untouched" "$(sed -n '/^# State/,$p' "$TMP/state.before")" "$(sed -n '/^# State/,$p' "$Y/STATE.md")"
run "$R" pointer
eq "afterwards the pointer is ok" "pointer: ok -- current_milestone M046" "$OUT"
eq "and exits 0" 0 "$EC"
run "$R" pointer --fix
eq "--fix on an ok pointer changes nothing" "pointer: ok -- current_milestone M046" "$OUT"
for m in M045 M046; do roadmap "$m" done '- [x] S01 -- x'; done
run "$R" pointer
eq "no milestone in progress: nothing to point at" "pointer: no milestone in progress" "$OUT"
eq "exit 0" 0 "$EC"

# ---- 3. usage -----------------------------------------------------------------
echo "# usage"
run "$R" sideways;               eq "unknown command: 64" 64 "$EC"
run "$R" skeletons --all;        eq "unknown option: 64" 64 "$EC"
run "$TMP/gone" skeletons;       eq "-C to a missing directory: 64" 64 "$EC"
mkdir -p "$TMP/bare"; ( cd "$TMP/bare" && git init -q ) >/dev/null 2>&1
run "$TMP/bare" skeletons;       eq "no .ytstack: exit 1" 1 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
