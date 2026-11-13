---
name: minimal-code
description: "Work contract the SessionStart hook points at when PREFERENCES minimal_code is on, and that every dispatched brief carries. Load before writing or changing code, before adding a check or a review round, and before reporting: it decides how little code and how little evidence is enough, and what must never be cut. Not user-invoked and not a procedure skill."
metadata:
  tier: core
  version: 0.2.0
  kind: directive
user-invocable: false
allowed-tools: []
---

# Work contract: smallest complete change, smallest sufficient evidence

Finish the agreed task with the least code and the least checking that fully does it. More work needs a reason you can name: a requirement that is not met, a failure case somebody can reach, or evidence that does not establish the result.

## Reach before size

Before you choose a solution, list every place the change must reach: callers, tests, fixtures, config, exports, the area file of the technical spec. Say what it could break for a user or a caller. That list is the scope. Then pick the smallest solution that covers all of it. Small about the solution, never about the change: a caller left broken is not a small change, it is an unfinished one.

## The ladder

Stop at the first rung that holds:

1. **Needed at all?** Nobody asked for it, a deletion or a config flag solves it, or the test already passes: write nothing.
2. **Already in the codebase?** Grep before you write. Reuse, do not duplicate.
3. **Standard library?** The runtime ships it: use that.
4. **Existing dependency?** A library already in the lockfile does it: use that; add no new dependency for one call site.
5. **One line?** A single clear expression beats a helper for one caller.
6. **Otherwise:** the minimum that makes the failing test pass. No options nobody asked for, no abstraction for one caller, no "while I'm here" cleanups, no speculative error paths for impossible states.

- A bug fix greps every caller of what it touches and fixes the cause once, in the shared code.
- Code you move or merge keeps its validation and its error handling.
- Between two solutions of the same size, take the one that is right on edge cases.

## Never cut

- input validation at trust boundaries (user input, network, files)
- authentication and permission checks
- error handling at I/O boundaries (the operation can fail; say how)
- accessibility of UI you touch
- the one small test for non-trivial logic: a branch, a loop, a parser, money, permissions (TDD is still RED first)

A trivial change needs no new test: a rename, a constant, a text, a config value, a moved line. Do not write one to look thorough. A deliberate shortcut gets a comment `shortcut: <the limit>, <when to upgrade>`. A shortcut that names its limit is a decision, not a defect; `ytstack:summarize-task` lists it under Follow-ups.

## Evidence

- Run what the plan's Verification names: that command, as often as the plan says (once, unless it says more), in the environment it names. A plan that asks for one pass of 44 scenarios gets 44 runs, not 88.
- Do not add passes, scenarios, suites, environments or acceptance conditions on your own. Do not weaken a gate the plan approved. A serious risk you discover is reported with its concrete trigger, and the plan is revisited; it is not answered with more runs.
- Evidence is a check, run on a commit, in an environment. Record all three. The same check on the same commit in the same environment does not expire because a new session or a new agent reads it. Renew it when the commit changed, the environment differs, the run failed or flaked, or an independent run is required and has not happened for this commit.
- A finding that the project's policy rates non-blocking holds nothing. It becomes a tracked follow-up.
- A verdict only a person can give is never recorded as given by you. Name who decides and how; it goes to them as one question.

## Report

End every report with **Not checked:** what you did not run or did not look at, and why. "Nothing" only when that is true.

Review question for every diff, in the summary: **which rung, and what did you leave out on purpose?**

Scope note: this contract shapes how much work is enough. It does not override an explicit user request, a locked DECISIONS.md entry, a plan's `## Files` section or a check the project requires for every change (CI on the current head, a required review). Concepts adapted from the ponytail project (see NOTICE); prose is ytstack's own.
