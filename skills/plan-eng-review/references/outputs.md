# Review outputs: body sections and terminal block

Read this file when step 11 (write the review file) starts. The review lives in `REVIEW_FILE` from the preamble:

- **Milestone mode:** `<YT_DIR>/<M###>-ENG-REVIEW.md`, one file per milestone. A re-run reads the existing file, keeps its decision ledger (earlier answers are prior approvals) and replaces the review body.
- **Concept mode:** the pitch itself. Everything below goes under one `## Eng review YYYY-MM-DD` heading at the END of the pitch, with `###` sub-headings instead of `##`; the verdict annotation goes at the top (SKILL.md step 12).
- A path the user named explicitly wins over both.

Save only accepted changes; unresolved choices stay pending in the ledger. After writing, Read the file back and check that the accepted changes, the review body, the verdict and the final unresolved-decisions line are present and that the terminal block is the last section. A failed write or read-back blocks the step: report the error, retry once, then stop with the review shown in chat and labeled **not persisted**.

## Body sections, in order

```markdown
# Eng review: <M### title / pitch title>

target: <slice plan paths / pitch path>
mode: milestone | concept
branch: <BRANCH>
commit: <HEAD short sha>
date: <YYYY-MM-DD>

## Scope Challenge
<REALITY lines, numbered findings, dispositions, result: "scope accepted as-is" or "scope reduced per recommendation">

## Architecture
<findings most severe first, design-twice record when it ran, dispositions>

## Code quality
<findings, shared-code rubric evidence for extraction choices, dispositions>

## Tests
<coverage diagram (milestone) or test strategy (concept), findings, dispositions>

## Test plan
<from references/test-review.md Step 5>

## Performance
<findings with scale (rows, requests/s, bytes) or "scale unknown", dispositions>

## Outside voice
<reviewer, completed / unavailable / skipped, findings and dispositions>

## NOT in scope
<each piece of work considered and deferred, one sentence why>

## What already exists
<existing code or tools that already solve a sub-problem; reuse vs rebuild, linked to the Code quality decisions>

## Diagrams
<ASCII diagrams of non-trivial flows, state machines, pipelines; files that need inline diagrams>

## Failure modes
<per new path: one realistic production failure, whether a test covers it, whether error handling exists, whether the user sees a clear error or a silent failure>

## Parallelization
<see below>

## Implementation tasks
<see below>

## Suppressed findings
<confidence 3-4 findings, one line each>

## Decision ledger
<one record per decision, see SKILL.md; ends with "Approval readiness: PASS (<IDs>)">

## Completion summary
<see below>

## ENG REVIEW REPORT
<terminal block, see below; nothing follows it>
```

The ledger may already sit earlier in the file from the review steps; keep one copy, anywhere before the terminal block.

**Failure modes.** Any failure with no test AND no error handling AND a silent outcome is a **critical gap**. Count them; the count goes into the summary and the terminal block.

**Diagrams.** ASCII for flows, states, dependencies, pipelines and decisions. Name the files whose complex model, service or helper behavior deserves an inline diagram in code. Flag stale diagrams near the touched code even outside scope.

## Parallelization

Milestone mode: the lanes are the slices. Build a dependency table by module (directories or packages, not guessed files):

| Slice | Modules touched | Depends on |
| --- | --- | --- |
| S01 | `src/auth/`, `migrations/` | -- |
| S02 | `src/billing/` | S01 (shared `migrations/`) |

Then: **Parallel lanes** (slices with disjoint modules), **Execution order** ("Launch S01 + S03. Merge both. Then S02."), **Conflict flags** (slices that share a module and must run sequentially or coordinate). This is the input `ytstack:spawn-milestone-team` needs. With one primary module or fewer than two independent slices, write: "Sequential implementation, no parallelization opportunity."

Concept mode: name the independent workstreams the first milestone could split into, or write the sequential sentence.

## Implementation tasks

A flat list of build-actionable tasks, each derived from a specific accepted finding; no padding. A section with zero findings gets `_No new tasks from <section>._`

```markdown
- [ ] **E1 (P1, human: ~2h / CC: ~15min)** -- <component> -- <imperative title>
  - Surfaced by: <section> -- <finding ID and text>
  - Slice: <S## that should carry it, milestone mode>
  - Files: <paths to touch>
  - Verify: <test command or manual check>
```

P1 blocks shipping, P2 lands in the same milestone, P3 is a follow-up for `TODOS.md`. Effort ratios (human time divided by CC time) as defaults, adjusted to the real work with the assumption stated: scaffolding ~100x, tests ~50x, features ~30x, bug fix with regression test ~20x, architecture ~5x, research ~3x. Use `E<n>` IDs so they do not collide with slice task IDs `T##`.

## Completion summary

```markdown
- Scope Challenge: <scope accepted as-is / scope reduced per recommendation>
- Reality rows: <n>/<n> applicable rows emitted, <n> unverified premises
- Architecture: <n> issues
- Code quality: <n> issues
- Tests: <diagram produced / strategy written>, <n> gaps
- Performance: <n> issues
- NOT in scope: written
- What already exists: written
- TODOS.md: <n> items proposed
- Failure modes: <n> critical gaps
- Unresolved decisions: <n>
- Outside voice: <codex / subagent> <completed / unavailable / skipped> (<reason>)
- Parallelization: <n> lanes, <n> parallel / <n> sequential
- Completeness picks: <X>/<Y> answers chose the 10/10 option (n/a if no scored answers)
```

## Terminal block

```markdown
## ENG REVIEW REPORT

| Field | Value |
| --- | --- |
| Mode | milestone <M###> / concept |
| Verdict | go / stop / rescope |
| Scope Challenge | scope accepted as-is / scope reduced per recommendation |
| Issues | architecture <n>, code quality <n>, test gaps <n>, performance <n> |
| Critical gaps | <n> |
| Outside voice | <reviewer> <completed / unavailable / skipped> |
| Commit | <short sha> |

Top risks:
1. <risk, file:line or plan line>
2. <risk>
3. <risk>

NO UNRESOLVED DECISIONS
```

**Verdict.** `go` when no CRITICAL finding stays unresolved and every accepted remedy is recorded in the plan. `stop / rescope` when a CRITICAL finding was rejected or deferred without a mitigation, the feasibility check failed, or the user chose to rescope.

**Last line.** Exactly one of: the unbolded line `NO UNRESOLVED DECISIONS`, or a `**UNRESOLVED DECISIONS:**` label followed by one bullet per open decision (ID and the missing answer), the last bullet being the file's last line. Never silently default an unresolved decision.
