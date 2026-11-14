---
milestone: M027
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T19:20:41Z
verification: passed
---

# M027-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M027-S01-T02: the skill signal-intake reads the sources and records findings`).

## Outcome

The skill `signal-intake` was written as a native procedure with seven steps. Its preamble printed the sources, the result of `bin/ytstack-runtime check` and every existing finding. A project without `.ytstack/`, without the scripts, with a `RUNTIME.md` the check rejects or without a "Signals" section stopped it; for the missing section it printed the lines to add. One shell block read every source once and stamped the read time, the exit code and the line count. The skill stated how a key is chosen and seven rules that separate a finding from noise, recorded through `bin/ytstack-signals new` with the read time of the source, and ended with one report. It asks nothing, so it needs no branch for an unattended run.

The eval case `evals/signal-intake/` was written: a project with one source whose script prints one error nobody recorded, one that an open finding carries and one that a fixed finding carries, and five free graders.

## Deviations from plan

- A source that could not be read is recorded as a finding with the key `<source>:unreadable`, not only named in the report. The report of a run nobody watches may be read by nobody; the finding is counted from run to run.
- The skill commits `.ytstack/signals/` only when the prompt, the schedule or `STANDING.md` says so. The brief did not decide who commits; without the files the next run records everything as new.
- A line the source marks as resolved is not a sighting, even when its key belongs to an open finding. The report names it; the state stays, because only whoever closes the task sets `fixed`.
- The grader for the regression is `tool_used` on the `bin/ytstack-signals new` call with the key of the fixed finding, together with `file_exists` on `F004-*.md`. A `regex` grader needs a fixed path, and the name of the new file comes from a title the agent writes.
- "No file outside `.ytstack/` changed" is graded for `src/export.js` only (the file that holds the obvious cause). The free graders cannot compare a whole tree.

## Follow-ups

- The eval case has not run. The coordinator runs it; a first run shows whether the prompt triggers the skill and whether the sandbox lets the read block write under `TMPDIR`.
- The noise rules are prose. Whether an agent applies rule 6 (a single occurrence of a kind of line that comes and goes) the same way twice is not measured by the case, which has no such line.

## Spec

- skills: area file updated by the coordinator in the closing task
- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh` -- exit 0, last line `481 passed, 0 failed` (469 at `85298e0`; the twelve new ones are the skill's preamble in the main checkout and in a linked worktree), at the working tree on top of `155a861` in the local checkout (macOS, bash 3.2.57).

`python3 bin/ytstack-check` -- exit 2, no `[fail]` line, 32 warnings, the same as at `85298e0`. `python3 tests/codex_plugin_test.py` -- 13 tests, OK.

By hand, once: `bash evals/signal-intake/fixture.sh` in a temporary directory built the project (exit 0); the skill's preamble printed one source and two findings there; the shell block of Step 3 ran under zsh and printed `SOURCE: errors | ... exit: 0 | lines: 3`; three `ytstack-signals new` calls as Step 5 writes them answered `new F003`, `seen-again F001` (count 4) and `regression F004` (reopens F002), and `check` passed. The frontmatter of the case files parsed as YAML and the grader patterns compiled.

Not checked: the eval case itself (`claude plugin eval` was not run; its `--help` lists no mode that parses a case without a run). Whether a `tool_used` grader accepts `tool: Bash` with `input_match` the way the existing cases use `tool: Skill`. The skill in a real session against a real tracker.
