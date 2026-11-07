---
milestone: M019
project: ytstack
created: 2026-11-07T18:10:00Z
size: L
---

# M019 -- Context

## Goal

ytstack's skills meet the 2026 bar for skill design and the plugin proves it: trigger-only descriptions inside Claude Code's listing budget, platform-native frontmatter (`metadata`, `user-invocable`, `disable-model-invocation`), an eval suite (`claude plugin eval`) plus a CI workflow for the shell suites, the missing lifecycle skills (`code-review`, `finish-branch`, `grill`, `retro`, `ship`, `document-release` -- absorbing M011), and an execution model that matches the platform (orchestrator + `Agent(isolation: worktree)` per slice instead of Agent Teams as the primary path, an advisory Stop hook for unsummarized work). Release 0.4.0 bundles M010 + M018 + M019.

## Exit criteria

- Every `skills/*/SKILL.md` description is a trigger statement (when to use, when not), under 1,536 characters, in the third person, without summarising the procedure; `tier`/`version` moved under `metadata:`; reference skills (`atomic-design`, `deutschland-stack-api`, `european-alternatives-api`, `oss-project`, `software-craftsmanship`) carry `user-invocable: true` + `disable-model-invocation: true` where they are lookup material; `bin/ytstack-check` enforces length + `metadata` and warns on procedure-summary phrases ("RED-GREEN-REFACTOR:", "Six forcing questions", step lists) in descriptions; `claude plugin validate .` clean.
- `evals/` suite for `claude plugin eval`: one case per lifecycle skill (prompt + `tool_used: Skill` grader + an outcome grader on the produced artifact), scaffold fixture with `.ytstack/`, documented run command with `--threshold`; results of one local run recorded in KNOWLEDGE (pass rate, cost).
- `.github/workflows/ci.yml`: `tests/run-all.sh` + `bin/ytstack-check` on macOS and ubuntu runners (no API cost); badge in README.
- New skills: `code-review` (inline superpowers `requesting-code-review` + `receiving-code-review`), `finish-branch` (inline superpowers `finishing-a-development-branch`), `grill` (inline superpowers `brainstorming` as the relentless-questions step before plan-milestone), `retro`, `ship`, `document-release` (installed gstack via Skill tool, same contract as the three planning wrappers); all with Namespace notes / gstack precheck, listed in `using-ytstack`, covered by the preamble suite and the checker; M011 marked absorbed.
- `spawn-milestone-team` rewritten: default path = orchestrator (never edits source) dispatching `Agent(isolation: "worktree")` per slice with the slice plan in the prompt and `worktree.baseRef: "head"` guidance, verifier agent per slice, merge step; Agent Teams only as an explicit opt-in (`team: true`); `agents/*.md` updated to the subagent contract (`memory`, no `skills` reliance).
- Advisory `Stop` hook (`hooks/stop`): when STATE has an active task whose SUMMARY is missing or still `closed: draft`, print a one-line reminder (exit 0, never block); hooks.json entry; test.
- Release 0.4.0: CHANGELOG (M010 + M018 + M019 from `[Unreleased]`), manifests, README status, clean-clone verification, tag; operator note for skills.sh listing and marketplace catalog sync.

## Size

L -- 5 slices, ~18 tasks. Review after slicing whether S03 (new skills) should become its own milestone; it is kept here because it absorbs M011 and shares the wrapper contract work of S01.

## Decisions locked in discuss phase

- 2026-11-07: Agent Teams demoted to opt-in; subagents in worktrees are the default execution model (platform: teams still experimental, `skills` ignored for teammates, no resume; subagents have `isolation: worktree`, fork, `memory`).
- 2026-11-07: new superpowers-based skills use the inline + Namespace-note wrapper shape; new gstack-based skills use the installed-dependency shape (M017). No third shape.
- 2026-11-07: descriptions follow superpowers' rule "never summarise the workflow in the description" and Anthropic's third-person what+when guidance; ytstack's own `tier`/`version` keys move under `metadata` so claude.ai upload no longer errors.

## Closing note (2026-11-07)

Done: 5 slices / 18 tasks. Every exit criterion met; one deliberate deviation recorded in S01-T02 (`disable-model-invocation` not set on the lookup skills so the model can trigger them). Found and fixed on the way: the `web-design` plugin dependency disabled ytstack in every isolated load (DECISIONS "No hard plugin dependencies"). Evals: first full run 10/11 at threshold 1.0, skill-fired 11/11, $3.55; the changed cases re-run before the tag (see S05-T03). Clean clone at `90340b0`: 12 suites green, checker 0 fails, validate clean. Released as 0.4.0.

## Open questions

- (answered S02-T01) `claude plugin eval` runs headless on its own: Write / Edit / Bash come from `--allow-tools`, `AskUserQuestion` is not granted, the appended system prompt tells the agent to take each RECOMMENDATION; no `--permission-mode` flag is involved.
- (answered S04-T02) `Stop` payload carries `stop_hook_active`, `last_assistant_message`, `transcript_path`; the hook uses the first and `cwd`.

## Research basis

`docs/research/2026-11-07-notes/developer-skills-landscape.md` (recommendations 1-10), `claude-code-platform-changes.md` (skills frontmatter, budgets, eval tooling, agent teams/subagents), `agentic-sdlc-methodology.md` (verification in harness, orchestrator-worker).
