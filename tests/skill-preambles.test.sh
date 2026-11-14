#!/usr/bin/env bash
# Tests for the skill preambles (M016-S02-T01, issue #24).
#
# Every skill preamble resolves the checkout through hooks/lib/git-ctx.sh:
#   - IS_GIT via `git rev-parse --is-inside-work-tree` (a linked worktree,
#     whose .git is a FILE, reports yes)
#   - .ytstack resolution from where the shell runs (never CLAUDE_PROJECT_DIR)
#   - no basename slug for anything but display
#
# The test extracts the first fenced preamble (```bash or ```!) from each
# SKILL.md, substitutes ${CLAUDE_SKILL_DIR} like Claude Code does, and runs it
# inside a fixture main checkout and a linked worktree of it.
#
# Run: /bin/bash tests/skill-preambles.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytsp.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
ELSEWHERE="$TMP/elsewhere"; mkdir -p "$ELSEWHERE"

MAIN="$TMP/main"; mkdir -p "$MAIN/.ytstack"
( cd "$MAIN" || exit 2
  git init -q && git config user.email t@t.t && git config user.name t
  printf 'project: fixture\nlast_updated: %s\ncurrent_milestone: M999\nactive_slice: S01\nactive_task: T01\n\n# State\n\n## Next action\n\nx\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .ytstack/STATE.md
  printf 'name: fixture\n' > .ytstack/PROJECT.md
  printf -- '---\nmilestone: M999\n---\n- [ ] S01 -- (to be planned)\n' > .ytstack/M999-ROADMAP.md
  printf -- '---\nmilestone: M999\nslice: S01\n---\n- [ ] T01 -- x\n' > .ytstack/M999-S01-PLAN.md
  printf -- '---\ntask: T01\n---\n## Files\n\n- Modify: a.ts\n\n## Verification\n\n```bash\ntrue\n```\n' > .ytstack/M999-S01-T01-PLAN.md
  echo seed > f.txt; git add -A; git commit -qm "M999-S01-T01: seed" ) >/dev/null 2>&1 || { echo FATAL fixture; exit 2; }
WT="$TMP/wt"; git -C "$MAIN" worktree add -q -b wt-branch "$WT" >/dev/null 2>&1 || { echo FATAL worktree; exit 2; }

SKILLS="adopt-brownfield handoff-session init-project plan-milestone plan-task quick-task reassess-roadmap reconcile resume-session slice-milestone spawn-milestone-team summarize-task office-hours plan-ceo-review plan-eng-review retro ship document-release systematic-debugging test-driven-development verification-before-completion code-review finish-branch grill coordinate finish-lane handover-step lane-retro visual-review signal-intake incident"

# Brownfield fixture (M010, issue #18): existing docs, no .ytstack -> >= 2 signals
BF="$TMP/brown"; mkdir -p "$BF/docs/adr"
( cd "$BF" || exit 2
  git init -q && git config user.email t@t.t && git config user.name t
  printf '# Acme\n\nAcme turns invoices into forecasts.\n' > README.md
  i=0; while [ $i -lt 40 ]; do echo "line $i" >> README.md; i=$((i+1)); done
  printf '# Guide\n' > docs/guide.md; printf '# Setup\n' > docs/setup.md; printf '# Ops\n' > docs/ops.md
  printf '# ADR 1\n' > docs/adr/0001-x.md; printf '# Changelog\n' > CHANGELOG.md
  git add -A; git commit -qm seed ) >/dev/null 2>&1 || { echo FATAL brownfield fixture; exit 2; }
# bf_signals <preamble-output> -> the integer after "BROWNFIELD_SIGNALS: " (or empty)
bf_signals() { printf '%s\n' "$1" | sed -n 's/^BROWNFIELD_SIGNALS: *//p' | head -1; }

# extract <skill> -> path of a runnable script with ${CLAUDE_SKILL_DIR} substituted
extract() {
  local skill="$1" src="$ROOT/skills/$1/SKILL.md" out="$TMP/pre-$1.sh"
  awk 'BEGIN{p=0} /^```(bash|!)[[:space:]]*$/ && p==0 {p=1; next} /^```[[:space:]]*$/ && p==1 {exit} p==1 {print}' "$src" \
    | sed "s|\${CLAUDE_SKILL_DIR}|$ROOT/skills/$skill|g" > "$out"
  printf '%s' "$out"
}

PD="$TMP/plugin-data"
run_pre() { # run_pre <script> <cwd> -> sets OUT (stdout) and EC (exit code) in this shell
  ( cd "$2" || exit 2; env CLAUDE_PROJECT_DIR="$ELSEWHERE" CLAUDE_PLUGIN_DATA="$PD" HOME="$TMP/home" bash "$1" 2>"$TMP/err" >"$TMP/out" ); EC=$?
  OUT=$(cat "$TMP/out")
}
mkdir -p "$TMP/home"

# Seed one automatic handoff for the main fixture (what pre-compact does on compaction)
printf -- '---\nkind: handoff\nevent: user-triggered\ntimestamp: 2026-01-01T00:00:00Z\n---\n# manual\n' > "$MAIN/.ytstack/HANDOFF.md"
( cd "$MAIN" && git add -A && git commit -qm "add manual handoff" ) >/dev/null 2>&1
printf '{"session_id":"seed","cwd":%s}' "$(printf '%s' "$MAIN" | jq -Rs .)" | ( cd "$ELSEWHERE" && CLAUDE_PLUGIN_DATA="$PD" CLAUDE_PROJECT_DIR="$ELSEWHERE" bash "$ROOT/hooks/pre-compact" >/dev/null 2>&1 )

for s in $SKILLS; do
  echo "# $s"
  P=$(extract "$s")
  [ -s "$P" ] && ok "$s: preamble extracted ($(wc -l < "$P" | tr -d ' ') lines)" || { bad "$s: preamble extracted"; continue; }
  bash -n "$P" 2>/dev/null && ok "$s: parses" || bad "$s: parses" "$(bash -n "$P" 2>&1 | head -1)"
  grep -q 'hooks/lib/git-ctx.sh' "$P" && ok "$s: sources the lib" || bad "$s: sources the lib"
  grep -q 'CLAUDE_PROJECT_DIR' "$P" && bad "$s: no CLAUDE_PROJECT_DIR" || ok "$s: no CLAUDE_PROJECT_DIR"
  grep -q 'basename "$(git rev-parse --show-toplevel' "$P" && bad "$s: no basename slug" || ok "$s: no basename slug"
  grep -q -- '-d \.git ]' "$P" && bad "$s: no [ -d .git ]" || ok "$s: no [ -d .git ]"

  run_pre "$P" "$MAIN"
  [ "$EC" -eq 0 ] && ok "$s: runs in main (exit 0)" || bad "$s: runs in main (exit 0)" "exit $EC: $(head -2 "$TMP/err" | tr '\n' ' ')"
  has "$s: main -> HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
  case "$OUT" in *"$ELSEWHERE"*) bad "$s: main -> no CLAUDE_PROJECT_DIR leak";; *) ok "$s: main -> no CLAUDE_PROJECT_DIR leak";; esac

  run_pre "$P" "$WT"
  [ "$EC" -eq 0 ] && ok "$s: runs in worktree (exit 0)" || bad "$s: runs in worktree (exit 0)" "exit $EC"
  has "$s: worktree -> HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
  case "$OUT" in *"$MAIN/.ytstack"*) bad "$s: worktree -> resolves its own .ytstack, not main's";; *) ok "$s: worktree -> resolves its own .ytstack, not main's";; esac
  case "$s" in
    summarize-task)
      has "$s: worktree -> IS_GIT yes (#24)" "$OUT" "IS_GIT: yes" ;;
    init-project)
      has "$s: worktree -> IS_GIT yes (#24)" "$OUT" "IS_GIT: yes"
      has "$s: worktree -> signals echoed (0 in the bare fixture)" "$OUT" "BROWNFIELD_SIGNALS: 0"
      run_pre "$P" "$BF"
      [ "$EC" -eq 0 ] && ok "$s: runs in brownfield fixture (exit 0)" || bad "$s: runs in brownfield fixture (exit 0)" "exit $EC"
      N=$(bf_signals "$OUT")
      [ -n "$N" ] && [ "$N" -ge 2 ] 2>/dev/null && ok "$s: brownfield -> BROWNFIELD_SIGNALS >= 2 ($N), routes to adopt-brownfield" || bad "$s: brownfield -> BROWNFIELD_SIGNALS >= 2" "got '$N'"
      has "$s: brownfield -> PITCH none (route condition)" "$OUT" "PITCH: none"
      has "$s: brownfield -> candidates listed" "$OUT" "CANDIDATES:" ;;
    office-hours|plan-ceo-review|plan-eng-review|retro|ship|document-release)
      # Adapted from gstack and shipped in ytstack (DECISIONS 2026-11-14): the
      # preamble runs with an empty HOME (no gstack anywhere) and needs nothing
      # outside the plugin.
      [ "$EC" -eq 0 ] && ok "$s: runs with an empty HOME (no gstack install)" || bad "$s: runs with an empty HOME" "exit $EC"
      has "$s: reports HAS_YTSTACK" "$OUT" "HAS_YTSTACK: yes"
      case "$OUT" in *GSTACK*|*BUN_OK*) bad "$s: no gstack precheck flags" ;; *) ok "$s: no gstack precheck flags" ;; esac
      grep -rqE '\.claude/skills/gstack|vendor/gstack|gstack-skill-start|\bbun\b' "$ROOT/skills/$s" && bad "$s: no gstack runtime reference" || ok "$s: no gstack runtime reference"
      # Concept mode picks the newest pitch, also in a checkout path with a space (PR #39 review).
      case "$s" in plan-ceo-review|plan-eng-review)
        SP="$TMP/space dir/$s"; mkdir -p "$SP/.ytstack"
        ( cd "$SP" && git init -q && git config user.email t@t.t && git config user.name t \
          && printf 'name: x\n' > .ytstack/PROJECT.md \
          && printf -- '---\nname: a\n---\n' > .ytstack/OFFICE-HOURS-old.md && touch -t 202001010000 .ytstack/OFFICE-HOURS-old.md \
          && printf -- '---\nname: b\n---\n' > .ytstack/OFFICE-HOURS-new-v2.md \
          && echo x > f && git add -A && git commit -qm seed ) >/dev/null 2>&1
        run_pre "$P" "$SP"
        has "$s: path with a space -> concept mode" "$OUT" "MODE: concept"
        has "$s: newest pitch selected" "$OUT" "OFFICE-HOURS-new-v2.md" ;;
      esac ;;
    reconcile)
      has "$s: clean fixture -> no draft stubs" "$OUT" "DRAFT_STUBS: 0"
      has "$s: clean fixture -> STATE.md is a pointer" "$OUT" "STATE_HISTORY: no (0 earlier status paragraph(s)"
      has "$s: no spec -> closed milestones not offered" "$OUT" "CLOSED_MILESTONES: 0"
      cp "$WT/.ytstack/STATE.md" "$TMP/state.rec.bak"
      printf '\n**Status:** now.\n\n**Previous status:** then.\n\n**Status (2026-01-01):** before.\n' >> "$WT/.ytstack/STATE.md"
      mkdir -p "$WT/.ytstack/spec"; printf '# spec\n' > "$WT/.ytstack/spec/SPEC.md"
      printf -- '---\nmilestone: M555\nstatus: done\n---\n' > "$WT/.ytstack/M555-ROADMAP.md"; printf -- '---\nslice: S01\n---\n' > "$WT/.ytstack/M555-S01-PLAN.md"
      run_pre "$P" "$WT"
      has "$s: earlier status paragraphs -> history class" "$OUT" "STATE_HISTORY: yes (2 earlier status paragraph(s)"
      has "$s: done milestone with slice files and a spec -> offered" "$OUT" "M555 (1 slice and task files)"
      cp "$TMP/state.rec.bak" "$WT/.ytstack/STATE.md"
      rm -f "$WT/.ytstack/spec/SPEC.md" "$WT/.ytstack/M555-ROADMAP.md" "$WT/.ytstack/M555-S01-PLAN.md"; rmdir "$WT/.ytstack/spec"
      printf -- '---\nclosed: draft\n---\n' > "$WT/.ytstack/M999-S01-T09-SUMMARY.md"
      printf -- '---\nmilestone: M777\nstatus: planned\n---\n' > "$WT/.ytstack/M777-ROADMAP.md"
      echo junk > "$WT/.ytstack/stray.md"
      run_pre "$P" "$WT"
      has "$s: draft stub counted"            "$OUT" "DRAFT_STUBS: 1"
      has "$s: planned-never-sliced counted"  "$OUT" "PLANNED_NEVER_SLICED: 1"
      has "$s: untracked counted (3 new files)" "$OUT" "UNTRACKED: 3"
      rm -f "$WT/.ytstack/M999-S01-T09-SUMMARY.md" "$WT/.ytstack/M777-ROADMAP.md" "$WT/.ytstack/stray.md" ;;
    reassess-roadmap)
      # bounded work (M023): open gates, non-converging reviews, the two numbers
      has "$s: no gates in the bare fixture -> accepted follows work" "$OUT" "SLICES_ACCEPTED: 0"
      has "$s: an open task keeps the slice incomplete" "$OUT" "SLICE_COMPLETE: no"
      cp "$WT/.ytstack/M999-S01-PLAN.md" "$TMP/sp.bak"; cp "$WT/.ytstack/M999-S01-T01-PLAN.md" "$TMP/tp.bak"
      printf -- '---\nmilestone: M999\nslice: S01\n---\n- [x] T01 -- x\n\n## Gates\n\n- [ ] G01 -- owner accepts the format | decides: product owner | how: opens the sample | lapses: when S02 ships\n- [x] G02 -- legal review | decides: counsel | how: mail | lapses: never | given: 2026-01-02 counsel\n- [-] G03 -- latency before cutover | decides: measurement | how: load test | lapses: at cutover | lapsed: 2026-01-03 cutover made\n' > "$WT/.ytstack/M999-S01-PLAN.md"
      printf -- '\n## Review\n\n- Round 1: aaaaaaa..bbbbbbb -- changes requested; blocking: 1; follow-ups: 0\n- Round 2: bbbbbbb..ccccccc -- changes requested; blocking: 1; follow-ups: 0\n- Round 3: ccccccc..ddddddd -- changes requested; blocking: 1; follow-ups: 0\n' >> "$WT/.ytstack/M999-S01-T01-PLAN.md"
      run_pre "$P" "$WT"
      has "$s: all tasks done, gates open -> slice complete" "$OUT" "SLICE_COMPLETE: yes"
      has "$s: open gate listed with its file"       "$OUT" "M999-S01-PLAN.md:"
      has "$s: open gate listed by id"                "$OUT" "G01 -- owner accepts the format"
      case "$OUT" in *"G02 -- legal review"*|*"G03 -- latency"*) bad "$s: given and lapsed gates are not listed as open";; *) ok "$s: given and lapsed gates are not listed as open";; esac
      has "$s: three review rounds reported"          "$OUT" "M999-S01-T01: 3 review rounds"
      has "$s: slices total from the roadmap"         "$OUT" "SLICES_TOTAL: 1"
      has "$s: slice with all tasks done counts as closed by work" "$OUT" "SLICES_CLOSED_BY_WORK: 1"
      has "$s: an open gate keeps it out of accepted" "$OUT" "SLICES_ACCEPTED: 0"
      sed 's/^- \[ \] G01/- [x] G01/' "$WT/.ytstack/M999-S01-PLAN.md" > "$TMP/sp.given"; cp "$TMP/sp.given" "$WT/.ytstack/M999-S01-PLAN.md"
      run_pre "$P" "$WT"
      has "$s: all gates given or lapsed -> accepted" "$OUT" "SLICES_ACCEPTED: 1"
      cp "$TMP/sp.bak" "$WT/.ytstack/M999-S01-PLAN.md"; cp "$TMP/tp.bak" "$WT/.ytstack/M999-S01-T01-PLAN.md" ;;
    quick-task)
      has "$s: QUICK_LANE on by default" "$OUT" "QUICK_LANE: on"
      has "$s: NEXT_Q starts at Q001"    "$OUT" "NEXT_Q: Q001"
      mkdir -p "$WT/.ytstack/quick"; printf -- '---\nkind: quick\n---\n' > "$WT/.ytstack/quick/Q001-PLAN.md"
      run_pre "$P" "$WT"
      has "$s: NEXT_Q advances past existing Q001" "$OUT" "NEXT_Q: Q002"
      rm -rf "$WT/.ytstack/quick" ;;
    plan-task|slice-milestone|summarize-task)
      # ceremony dials (M018): defaults, then a PREFERENCES.md with slice/step
      has "$s: default GRANULARITY task" "$OUT" "GRANULARITY: task"
      has "$s: default AUTONOMY loop"    "$OUT" "AUTONOMY: loop"
      printf '## Ceremony\n\ngranularity: slice\nautonomy: step\n' > "$WT/.ytstack/PREFERENCES.md"
      run_pre "$P" "$WT"
      has "$s: PREFERENCES granularity slice" "$OUT" "GRANULARITY: slice"
      has "$s: PREFERENCES autonomy step"     "$OUT" "AUTONOMY: step"
      rm -f "$WT/.ytstack/PREFERENCES.md" ;;
    adopt-brownfield)
      has "$s: main (has .ytstack) -> IS_GIT yes" "$OUT" "IS_GIT: yes"
      has "$s: main -> signals echoed (0 in the bare fixture)" "$OUT" "BROWNFIELD_SIGNALS: 0"
      has "$s: main -> .ytstack present named as a candidate hint" "$OUT" ".ytstack/ present"
      run_pre "$P" "$BF"
      [ "$EC" -eq 0 ] && ok "$s: runs in brownfield fixture (exit 0)" || bad "$s: runs in brownfield fixture (exit 0)" "exit $EC"
      has "$s: brownfield -> HAS_YTSTACK no" "$OUT" "HAS_YTSTACK: no"
      N=$(bf_signals "$OUT")
      [ -n "$N" ] && [ "$N" -ge 2 ] 2>/dev/null && ok "$s: brownfield -> BROWNFIELD_SIGNALS >= 2 ($N)" || bad "$s: brownfield -> BROWNFIELD_SIGNALS >= 2" "got '$N'"
      has "$s: brownfield -> candidate README -> PROJECT.md" "$OUT" "README.md (4"
      has "$s: brownfield -> candidate adr -> DECISIONS.md" "$OUT" "docs/adr/ (1 files) -> DECISIONS.md"
      has "$s: brownfield -> README one-liner picked" "$OUT" "README_ONELINER: Acme turns invoices into forecasts."
      has "$s: brownfield -> no entry doc" "$OUT" "ENTRY_DOC: none" ;;
    plan-milestone|reassess-roadmap)
      has "$s: worktree -> TRACKER none when STATE.md has no field" "$OUT" "TRACKER: none"
      cp "$WT/.ytstack/STATE.md" "$TMP/state.bak"; printf 'tracker: linear\n' >> "$WT/.ytstack/STATE.md"
      run_pre "$P" "$WT"
      has "$s: worktree -> TRACKER read from STATE.md" "$OUT" "TRACKER: linear"
      cp "$TMP/state.bak" "$WT/.ytstack/STATE.md" ;;
    spawn-milestone-team)
      has "$s: worktree -> EXECUTION subagents by default" "$OUT" "EXECUTION: subagents"
      has "$s: worktree -> slice count from plans"         "$OUT" "SLICE_COUNT: 1"
      has "$s: worktree -> S01 open"                       "$OUT" "OPEN_SLICES:  S01"
      has "$s: worktree -> IS_LINKED_WORKTREE yes"         "$OUT" "IS_LINKED_WORKTREE: yes"
      printf 'team: on\n' > "$WT/.ytstack/PREFERENCES.md"
      printf -- '---\nmilestone: M999\nslice: S02\n---\n# plan\n\n- [ ] T01 -- also touches `a.ts`\n' > "$WT/.ytstack/M999-S02-PLAN.md"
      run_pre "$P" "$WT"
      has "$s: team: on -> EXECUTION team"                 "$OUT" "EXECUTION: team"
      has "$s: two slices naming a.ts -> OVERLAP"          "$OUT" "a.ts: S01 S02"
      rm -f "$WT/.ytstack/PREFERENCES.md" "$WT/.ytstack/M999-S02-PLAN.md"
      # the lanes file is written by the orchestrator during a run: it must not make the tree "dirty" (M024)
      run_pre "$P" "$WT"; _d0=$(printf '%s\n' "$OUT" | sed -n 's/^DIRTY: //p')
      printf '# Lanes\n' > "$WT/.ytstack/LANES.md"
      run_pre "$P" "$WT"
      has "$s: LANES.md alone does not change DIRTY" "$OUT" "DIRTY: $_d0"
      if [ "$_d0" = no ]; then
        echo x > "$WT/zz-stray.txt"; run_pre "$P" "$WT"
        has "$s: another changed file -> DIRTY yes" "$OUT" "DIRTY: yes"
        rm -f "$WT/zz-stray.txt"
      fi
      rm -f "$WT/.ytstack/LANES.md" ;;
    code-review)
      has "$s: worktree -> task plan found" "$OUT" "TASK_PLAN_EXISTS: yes"
      has "$s: worktree -> COMMITS_SOURCE echoed" "$OUT" "COMMITS_SOURCE: "
      ( cd "$WT" && echo cr > cr.txt && git add cr.txt && git commit -qm "M999-S01-T01: reviewed change" ) >/dev/null 2>&1
      run_pre "$P" "$WT"
      has "$s: task-ref commit -> COMMITS_SOURCE task-ref" "$OUT" "COMMITS_SOURCE: task-ref"
      case "$OUT" in *"BASE_SHA: none"*) bad "$s: task-ref commit -> BASE_SHA resolved";; *) ok "$s: task-ref commit -> BASE_SHA resolved";; esac ;;
    finish-lane)
      # who merges (M025): risk unless PREFERENCES says otherwise; a typo reads as human
      has "$s: no merge_by in PREFERENCES -> risk" "$OUT" "MERGE_BY: risk"
      printf 'merge_by: coordinater\n' > "$WT/.ytstack/PREFERENCES.md"
      run_pre "$P" "$WT"
      has "$s: a merge_by outside the three values reads as human" "$OUT" "MERGE_BY: human"
      has "$s: and the note names the value" "$OUT" "MERGE_BY_NOTE: merge_by: 'coordinater' is not human|coordinator|risk (using human)"
      rm -f "$WT/.ytstack/PREFERENCES.md" ;;
    visual-review)
      # the evidence of a visual review (M025) is read from the main checkout, also from a worktree
      has "$s: worktree -> no Run section in the bare fixture" "$OUT" "RUN_SECTION: no"
      has "$s: worktree -> the runtime script is found" "$OUT" "RUNTIME_TOOL: $ROOT/bin/ytstack-runtime"
      has "$s: worktree -> evidence_dir defaults" "$OUT" "EVIDENCE_DIR: .ytstack/evidence"
      has "$s: worktree -> the evidence root is the main checkout" "$OUT" "EVIDENCE_ROOT: $MAIN"
      mkdir -p "$WT/.ytstack/spec"
      printf '# Runtime\n\n## Run\n\n- start: sleep 300\n- ready: true\n- needs: DATABASE_URL\n' > "$WT/.ytstack/RUNTIME.md"
      printf '# Review policy\n\n## Lenses\n\n- ui | applies: src/** | reads: docs/design.md | evidence: visual\n- api | applies: src/** | reads: docs/api.md | evidence: none\n' > "$WT/.ytstack/spec/REVIEW.md"
      printf 'evidence_dir: review/shots/\n' > "$WT/.ytstack/PREFERENCES.md"
      run_pre "$P" "$WT"
      has "$s: a Run section is stated" "$OUT" "RUN_SECTION: yes"
      has "$s: with what it needs" "$OUT" "RUN_NEEDS: DATABASE_URL"
      has "$s: evidence_dir from PREFERENCES" "$OUT" "EVIDENCE_DIR: review/shots"
      has "$s: the visual lens is listed" "$OUT" "- ui | applies: src/** | reads: docs/design.md | evidence: visual"
      case "$OUT" in *"- api |"*) bad "$s: a lens without visual evidence is not listed";; *) ok "$s: a lens without visual evidence is not listed";; esac
      rm -f "$WT/.ytstack/RUNTIME.md" "$WT/.ytstack/spec/REVIEW.md" "$WT/.ytstack/PREFERENCES.md"; rmdir "$WT/.ytstack/spec" ;;
    finish-branch)
      has "$s: worktree -> IS_LINKED_WORKTREE yes" "$OUT" "IS_LINKED_WORKTREE: yes"
      case "$OUT" in *"OPEN_TASKS:"*T01*) ok "$s: worktree -> open tasks listed (T01 has no summary)";; *) bad "$s: worktree -> open tasks listed (T01 has no summary)" "$(printf '%s' "$OUT" | grep OPEN_TASKS)";; esac ;;
    grill)
      has "$s: worktree -> milestone context target" "$OUT" "DESIGN_TARGET: $WT/.ytstack/M999-CONTEXT.md"
      has "$s: worktree -> no pitch" "$OUT" "PITCH: none" ;;
    resume-session)
      has "$s: worktree -> STATE lint clean (0)" "$OUT" "STATE_LINT: 0"
      has "$s: worktree -> no auto handoff there" "$OUT" "LATEST_AUTO_HANDOFF: none"
      run_pre "$P" "$MAIN"
      has "$s: main -> latest auto handoff from out-of-tree state" "$OUT" "LATEST_AUTO_HANDOFF: $PD/repos/"
      has "$s: main -> auto handoff timestamp read" "$OUT" "AUTO_HANDOFF_TS: 20"
      has "$s: main -> manual handoff event read" "$OUT" "MANUAL_HANDOFF_EVENT: user-triggered"
      has "$s: main -> manual handoff timestamp read" "$OUT" "MANUAL_HANDOFF_TS: 2026-01-01T00:00:00Z" ;;
  esac
done

# ---- technical spec in the preambles (M022) ----------------------------------
# One area `core` over f.txt and cr.txt (the file the code-review case committed
# under the task ref). The spec is committed without the task ref, so a plan
# that names `core` is unmet until the area file changes again.
echo "# technical spec"
pre() { run_pre "$(extract "$1")" "$2"; }
pre plan-task "$WT";        has "plan-task: no spec -> HAS_SPEC no" "$OUT" "HAS_SPEC: no"
pre summarize-task "$WT";   has "summarize-task: no spec -> impact check not run" "$OUT" "SPEC_IMPACT_EXIT: not-run"
mkdir -p "$WT/.ytstack/spec"
printf -- '---\nproject: fixture\n---\n\n# spec\n\n## Areas\n\n| Area | Covers | Status | File |\n|---|---|---|---|\n| core | x | implemented | [core.md](core.md) |\n\n## Keeping this true\n\n- x\n' > "$WT/.ytstack/spec/SPEC.md"
printf -- '---\narea: core\nstatus: implemented\npaths:\n  - f.txt\n  - cr.txt\nverified_at: %s\n---\n\n## Purpose\n\nx\n\n## Where implemented\n\nx\n\n## How to verify\n\nx\n\n## Decisions that apply now\n\nx\n' "$(git -C "$WT" rev-parse --short HEAD)" > "$WT/.ytstack/spec/core.md"
( cd "$WT" && git add .ytstack/spec && git commit -qm "docs: technical spec" ) >/dev/null 2>&1
for s in plan-task resume-session adopt-brownfield; do
  pre "$s" "$WT"; has "$s: spec present -> HAS_SPEC yes" "$OUT" "HAS_SPEC: yes"
done
pre summarize-task "$WT"
has "summarize-task: plan without the section -> exit 3" "$OUT" "SPEC_IMPACT_EXIT: 3"
cp "$WT/.ytstack/M999-S01-T01-PLAN.md" "$TMP/tp.spec.bak"
printf '\n## Spec impact\n\n- core: Behavior -- x\n' >> "$WT/.ytstack/M999-S01-T01-PLAN.md"
pre summarize-task "$WT"
has "summarize-task: named area not updated -> exit 1" "$OUT" "SPEC_IMPACT_EXIT: 1"
has "summarize-task: says what did not change"         "$OUT" "FAIL core: neither .ytstack/spec/core.md"
printf '\nedited with the task\n' >> "$WT/.ytstack/spec/core.md"
pre summarize-task "$WT"
has "summarize-task: area file changed with the task -> exit 0" "$OUT" "SPEC_IMPACT_EXIT: 0"
pre code-review "$WT"
has "code-review: spec present -> SPEC_EXISTS yes"            "$OUT" "SPEC_EXISTS: yes"
has "code-review: the area of the changed files is listed"    "$OUT" ".ytstack/spec/core.md"
has "code-review: first review -> round 1"                    "$OUT" "REVIEW_ROUND: 1"
printf -- '\n## Review\n\n- Round 1: %s..%s -- changes requested; blocking: 1; follow-ups: 0\n' "$(git -C "$WT" rev-parse --short HEAD~1)" "$(git -C "$WT" rev-parse --short HEAD)" >> "$WT/.ytstack/M999-S01-T01-PLAN.md"
pre code-review "$WT"
has "code-review: one recorded round -> round 2"              "$OUT" "REVIEW_ROUND: 2"
has "code-review: the follow-up base is the last reviewed head" "$OUT" "LAST_REVIEWED_HEAD: $(git -C "$WT" rev-parse --short HEAD)"
# The risk gate (M025): a round line with risk, invariants and by counts like
# the form before it, and the floor of the task's commit range is printed. T02
# has a commit with a parent; T01 starts at the root commit, which has no base.
printf -- '- Round 2: %s..%s -- approved; blocking: 0; follow-ups: 1; risk: low; invariants: none; by: review-M999-S01-T01\n' "$(git -C "$WT" rev-parse --short HEAD~1)" "$(git -C "$WT" rev-parse --short HEAD)" >> "$WT/.ytstack/M999-S01-T01-PLAN.md"
pre code-review "$WT"
has "code-review: a round line with risk, invariants and by counts -> round 3" "$OUT" "REVIEW_ROUND: 3"
has "code-review: and its head is the last reviewed head"      "$OUT" "LAST_REVIEWED_HEAD: $(git -C "$WT" rev-parse --short HEAD)"
cp "$WT/.ytstack/STATE.md" "$TMP/state.risk.bak"
sed 's/^active_task: T01/active_task: T02/' "$TMP/state.risk.bak" > "$WT/.ytstack/STATE.md"
printf -- '---\ntask: T02\n---\n## Files\n\n- Modify: f.txt\n' > "$WT/.ytstack/M999-S01-T02-PLAN.md"
( cd "$WT" && echo more >> f.txt && git add f.txt && git commit -qm "M999-S01-T02: change f" ) >/dev/null 2>&1
pre code-review "$WT"
has "code-review: the floor of the task's commit range is printed" "$OUT" "floor: low"
has "code-review: with the area the change touches"            "$OUT" "areas: core"
cp "$TMP/state.risk.bak" "$WT/.ytstack/STATE.md"; rm -f "$WT/.ytstack/M999-S01-T02-PLAN.md"
pre reassess-roadmap "$WT"
has "reassess-roadmap: drift report printed" "$OUT" "spec drift:"
pre verification-before-completion "$WT"
has "verification-before-completion: no Runs line -> the default is stated" "$OUT" "RUNS_LINE: Runs: once. Environment: local checkout."
has "verification-before-completion: the commit is printed" "$OUT" "HEAD: $(git -C "$WT" rev-parse --short HEAD)"
has "verification-before-completion: the runtime script is named" "$OUT" "RUNTIME_TOOL: $ROOT/skills/verification-before-completion/../../bin/ytstack-runtime"
has "verification-before-completion: no Run section in RUNTIME.md is stated" "$OUT" "RUN_SECTION: no"
printf '# Runtime\n\n## Run\n\n- start: sleep 300\n- ready: true\n' > "$WT/.ytstack/RUNTIME.md"
pre verification-before-completion "$WT"
has "verification-before-completion: a Run section is stated" "$OUT" "RUN_SECTION: yes"
rm -f "$WT/.ytstack/RUNTIME.md"
cp "$TMP/tp.spec.bak" "$WT/.ytstack/M999-S01-T01-PLAN.md"
( cd "$WT" && git rm -rq .ytstack/spec && git commit -qm "chore: remove fixture spec" ) >/dev/null 2>&1
rm -f "$WT/.ytstack/spec/core.md"; rmdir "$WT/.ytstack/spec" 2>/dev/null

# Fallback path: CLAUDE_SKILL_DIR left unsubstituted (foreign host) -> still resolves project scope
echo "# fallback without lib"
P=$(extract summarize-task); sed "s|$ROOT/skills/summarize-task|/nonexistent-skill-dir|g" "$P" > "$TMP/pre-fallback.sh"
run_pre "$TMP/pre-fallback.sh" "$WT"
[ "$EC" -eq 0 ] && ok "fallback: runs" || bad "fallback: runs" "exit $EC"
has "fallback: HAS_YTSTACK yes" "$OUT" "HAS_YTSTACK: yes"
has "fallback: IS_GIT yes in worktree" "$OUT" "IS_GIT: yes"

echo "# tree hygiene"
[ -z "$(git -C "$MAIN" status --porcelain)" ] && ok "main checkout clean after all preambles" || bad "main checkout clean" "$(git -C "$MAIN" status --porcelain | head -3 | tr '\n' ' ')"
[ -e "$ELSEWHERE/.ytstack" ] && bad "nothing written under CLAUDE_PROJECT_DIR" || ok "nothing written under CLAUDE_PROJECT_DIR"
[ -z "$(git -C "$BF" status --porcelain)" ] && ok "brownfield fixture clean after all preambles (read-only detection)" || bad "brownfield fixture clean" "$(git -C "$BF" status --porcelain | head -3 | tr '\n' ' ')"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
