---
milestone: M024
slice: S01
task: T03
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S01-T03 -- Summary

## Commits

- The commit that carries this file (`M024-S01-T03: lane kinds in the brief; Status, Uncommitted and Next in the report`).

## Outcome

`bin/ytstack-brief render` took `--kind implement|review|prepare` and wrote a `## Kind` section from the sentences in `skills/spawn-milestone-team/brief-template.md`. A review brief pinned its commit or range and had no Git section; a prepare brief told the worker to commit nothing and to list its files under `Uncommitted:`. `check` validated eleven labels, the three values of `Status:` and their consistency with `Blockers:`. `tests/ytstack-brief.test.sh` covers the three kinds, the usage errors and the report rules.

`codex/adapter.md` says that a worker does only what the Kind section allows, and `docs/codex.md` names the three kinds. `skills/minimal-code/SKILL.md` says that every report states under "Not checked:" what was not run or looked at. `skills/resume-session/SKILL.md` lists "Suggested skills" among the handoff sections it reads.

## Deviations from plan

- `--head` and `--base` of a review brief must be commit hashes. A branch name is refused with exit 64, because a name pins nothing.
- `--head` without `--kind review` is a usage error (exit 64): it would hand a reviewer a brief that lets it change files.
- The task line names the implementer and the verifier. No change to `agents/implementer.md` or `agents/verifier.md` is part of this task. The implementer reports "in the shape the brief gives under Report: every label", so it follows through the template. The verifier reads `Outcome:`, `Checks run:` and `Not checked:` from a worker's report and names none of the three new labels.
- The reading side of "Suggested skills" (`resume-session`) is in this task. The section itself is written by `handoff-session` and belongs to M024-S04-T03.

## Follow-ups

- `check` does not enforce the order of the labels. The template asks for "all eleven labels, in this order"; a report with the labels in another order passes.
- `host-adapters.md` states the brief rule for Codex and lists neither the entry of 2026-11-13 on bounded work nor the one on coordinator mode under "Decisions that apply now".
- No real dispatch with a rendered brief has been made, neither a Claude subagent nor `codex exec`.

## Spec

- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("`bin/ytstack-brief`: the brief of a dispatched worker and its report")
- skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Dispatch)
- host-adapters: `.ytstack/spec/host-adapters.md` -- Behavior ("Codex"); `docs/codex.md` (a source of the area), section "Supported behavior"

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-brief.test.sh; /bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `128 passed, 0 failed`; `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: a worker that received a `review` or a `prepare` brief. A Codex session that follows the adapter paragraph. Whether a model keeps `partial` and `blocked` out of its paragraphs, which the checker cannot see.
