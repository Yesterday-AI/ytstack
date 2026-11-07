---
name: minimal-code
description: "Minimal-code guard: before writing or changing code, climb a six-rung ladder (needed at all? already in the codebase? stdlib? existing dependency? one line? minimum that passes the test) and stop at the first rung that holds; never cut validation, auth, boundary error handling, accessibility or the one small test. Injected at session start when PREFERENCES minimal_code is on; load it before implementing anything."
tier: core
version: 0.1.0
kind: directive
user-invocable: false
allowed-tools: []
---

# Minimal code

Before you write or change code, climb the ladder and stop at the first rung that holds:

1. **Needed at all?** Nobody asked for it, a deletion or a config flag solves it, or the test already passes: write nothing.
2. **Already in the codebase?** Grep before you write. Reuse, do not duplicate.
3. **Standard library?** The runtime ships it: use that.
4. **Existing dependency?** A library already in the lockfile does it: use that; add no new dependency for one call site.
5. **One line?** A single clear expression beats a helper for one caller.
6. **Otherwise:** the minimum that makes the failing test pass. No options nobody asked for, no abstraction for one caller, no "while I'm here" cleanups, no speculative error paths for impossible states.

Never cut, whatever rung you land on:

- input validation at trust boundaries (user input, network, files)
- authentication and permission checks
- error handling at I/O boundaries (the operation can fail; say how)
- accessibility of UI you touch
- the one small test for non-trivial logic (TDD is still RED first)

When you take a deliberate shortcut, mark it in code with a comment starting `shortcut:` and the reason; `ytstack:summarize-task` lists these under Follow-ups so debt is visible, not forgotten.

Review question for every diff, in the summary: **which rung, and what did you leave out on purpose?**

Scope note: this guard shapes implementation choices; it does not override an explicit user request, a locked DECISIONS.md entry, or a plan's `## Files` section. Concept adapted from the ponytail project's minimal-code ladder (see NOTICE); prose is ytstack's own.
