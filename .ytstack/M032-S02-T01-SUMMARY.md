---
milestone: M032
slice: S02
task: T01
project: ytstack
closed: 2026-11-15T02:00:00Z
verification: passed
---

# M032-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M032-S02-T01: the lesson skill, its listings, preamble test and eval case`).

## Outcome

`skills/lesson/SKILL.md` (0.1.0) closed an incident of any class in eight steps: preamble with every lesson and the open incident records, one class line, the target by the first rule that applies (machine check, proposal for agent behaviour or a rule, knowledge entry; never `AGENTS.md`/`CLAUDE.md`), `ytstack-signals lesson new` with the action per case, the lesson put in place (or described as `## Files` and `## Verification` for a lane), one question for a proposal only outside coordinator mode and only interactive, check and a fixed report. It invoked no skill. The skill was listed in `using-ytstack` (0.2.3), `docs/concept.md`, `docs/codex.md`, the count in `docs/kimi.md` (40), `evals/README.md` and the `skills` area file. `tests/skill-preambles.test.sh` ran its preamble in main and in a worktree and checked the tool lines and the lesson and incident lists. `evals/lesson/` held the case: the second red `main` of an open lesson's class, graded on the skill firing, the `lesson new --class flaky-order` call, count 2 on F001, no F002, and `AGENTS.md` unchanged.

## Deviations from plan

- The lane sections in the skill's Step 6 use a `~~~` fence around the Markdown example, because the example itself holds a command block.

## Follow-ups

- README and QUICKSTART text goes into the slice report (another worker owns those files).
- The eval case is not run (cost); `claude plugin eval . --case lesson` is named in the report.

## Spec

- skills: the class table, the `lesson` sentence, the not-run list

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check && bash tests/hooks-readonly.test.sh` -- `622 passed, 0 failed`; the checker `OK (with 9 warning[s])`, no `[fail]` (the warnings are older ones of other skills); `69 passed, 0 failed` with the injection at 8630 characters (guard 9500); at the working tree on top of `3b5109e` in the local checkout (macOS, bash 3.2). The fixture built in an empty directory: `signals ok: 1 finding(s), 0 incident(s)`, `all tests passed`, and the `agents-untouched` pattern matched the untouched file in Python and in Node.
