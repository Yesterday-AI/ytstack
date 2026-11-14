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

SKILLS="adopt-brownfield handoff-session init-project plan-milestone plan-task quick-task reassess-roadmap reconcile resume-session slice-milestone spawn-milestone-team summarize-task office-hours plan-ceo-review plan-eng-review retro ship document-release systematic-debugging test-driven-development verification-before-completion code-review finish-branch grill"

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
      grep -rqE '\.claude/skills/gstack|vendor/gstack|gstack-skill-start|\bbun\b' "$ROOT/skills/$s" && bad "$s: no gstack runtime reference" || ok "$s: no gstack runtime reference" ;;
    reconcile)
      has "$s: clean fixture -> no draft stubs" "$OUT" "DRAFT_STUBS: 0"
      printf -- '---\nclosed: draft\n---\n' > "$WT/.ytstack/M999-S01-T09-SUMMARY.md"
      printf -- '---\nmilestone: M777\nstatus: planned\n---\n' > "$WT/.ytstack/M777-ROADMAP.md"
      echo junk > "$WT/.ytstack/stray.md"
      run_pre "$P" "$WT"
      has "$s: draft stub counted"            "$OUT" "DRAFT_STUBS: 1"
      has "$s: planned-never-sliced counted"  "$OUT" "PLANNED_NEVER_SLICED: 1"
      has "$s: untracked counted (3 new files)" "$OUT" "UNTRACKED: 3"
      rm -f "$WT/.ytstack/M999-S01-T09-SUMMARY.md" "$WT/.ytstack/M777-ROADMAP.md" "$WT/.ytstack/stray.md" ;;
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
      rm -f "$WT/.ytstack/PREFERENCES.md" "$WT/.ytstack/M999-S02-PLAN.md" ;;
    code-review)
      has "$s: worktree -> task plan found" "$OUT" "TASK_PLAN_EXISTS: yes"
      has "$s: worktree -> COMMITS_SOURCE echoed" "$OUT" "COMMITS_SOURCE: "
      ( cd "$WT" && echo cr > cr.txt && git add cr.txt && git commit -qm "M999-S01-T01: reviewed change" ) >/dev/null 2>&1
      run_pre "$P" "$WT"
      has "$s: task-ref commit -> COMMITS_SOURCE task-ref" "$OUT" "COMMITS_SOURCE: task-ref"
      case "$OUT" in *"BASE_SHA: none"*) bad "$s: task-ref commit -> BASE_SHA resolved";; *) ok "$s: task-ref commit -> BASE_SHA resolved";; esac ;;
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
