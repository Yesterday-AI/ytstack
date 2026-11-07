---
milestone: M019
slice: S04
task: T03
project: ytstack
closed: 2026-11-07T20:40:00Z
verification: passed
---

# M019-S04-T03 -- Summary

## Commits

- (see `git log --grep '^M019-S04-T03'`) -- agents to the subagent contract; checker validates isolation / memory; agent-structure doc

## Outcome

`agents/implementer.md` rewritten for worktree dispatch: `isolation: worktree`, `memory: project`, `maxTurns: 150`, `ytstack:minimal-code` preloaded, the branch step first, the STATE-copy rule, no merge / push / reassess, final report format; `agents/verifier.md` gets `isolation: worktree`, `memory: project`, `maxTurns: 60` and a "Before the first task" checkout step; `agents/architect.md` gets `memory: project`, `maxTurns: 40` and an Agent-tool dispatch note. `docs/ux/agent-structure.md` documents the new fields, the ignored ones (`hooks`, `mcpServers`, `permissionMode`) and `skills:` as a preload. `bin/ytstack-check` fails `isolation` other than `worktree` and `memory` outside `user|project|local`, warns on ignored fields and on an implementer without worktree isolation; `tests/ytstack-check.test.sh` section 7 covers it.

## Deviations from plan

None.

## Follow-ups

- None.

## Verification

Command: `/bin/bash tests/ytstack-check.test.sh && bin/ytstack-check && claude plugin validate .` -- passed.
