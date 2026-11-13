---
project: ytstack
updated: 2026-11-13
---

# ytstack -- technical spec

## What this is

ytstack is a plugin for Claude Code and Codex. It ships one tree of skills (procedures an agent loads), three agent definitions, lifecycle hooks and a few scripts. Together they keep a project's memory in Markdown files under `.ytstack/` and lead an agent through plan, execute, verify and close. Part of the skills wrap procedures from superpowers (vendored) and gstack (installed). There is no runtime: everything is skill text, shell and one Python checker.

This spec says what applies now. `STATE.md` says where the work stands, `DECISIONS.md` why, the `M###-*` files what happened.

## Areas

| Area | Covers | Status | File |
|---|---|---|---|
| skills | Skill classes, the shared preamble, ceremony preferences, the work contract, the spec in the loop, coordinating many lanes, the three agents | implemented | [skills.md](skills.md) |
| artifacts | The files under `.ytstack/`, who writes each: plans and summaries, the technical spec, lanes, questions, standing instructions; what is user-owned | implemented | [artifacts.md](artifacts.md) |
| hooks-and-state | The lifecycle hooks, the resolver library, state outside the tree, the SessionStart injection, the status segment | implemented | [hooks-and-state.md](hooks-and-state.md) |
| host-adapters | Manifests, marketplace entries and hook registration for Claude Code and Codex, the Codex helper | implemented | [host-adapters.md](host-adapters.md) |
| dependencies | superpowers as a read-only subtree, gstack as a pinned installed prerequisite, concepts-only sources | implemented | [dependencies.md](dependencies.md) |
| checks-and-evals | The contract checker, the test suites, the spec tool, the brief tool, the coordinator scripts, the behavioural evals, the CI workflows | implemented | [checks-and-evals.md](checks-and-evals.md) |

## Invariants that hold everywhere

- `vendor/**` is never edited. Different behaviour goes into a ytstack wrapper (`AGENTS.md`, "Never modify vendored content").
- Hooks write nothing into the checkout. Volatile state lives outside the tree ([hooks-and-state.md](hooks-and-state.md)).
- `.ytstack/` artifacts are user-owned. Only `ytstack:reconcile` archives, and it asks first ([artifacts.md](artifacts.md)).
- Every skill follows the contracts under `docs/ux/`; `bin/ytstack-check` enforces the mechanical part.
- No em-dash in prose; own wording only, concepts from third parties, never their text (`AGENTS.md`).

## Build and test

Nothing is built. Checks, from the repository root:

```bash
bash tests/run-all.sh
python3 bin/ytstack-check          # exit 2 = warnings only, a pass
python3 -m unittest discover -s tests -p 'codex*_test.py'
claude plugin validate .
```

What each one covers: [checks-and-evals.md](checks-and-evals.md).

## Keeping this true

- A task plan names its **Spec impact**: the area and section it changes, or `none`.
- A task that changes behaviour updates the area file, or the source the area file names, in the same commits. A task that restores the described behaviour, a refactoring and a trivial edit close with `none`.
- A decision that changes what applies in an area is linked under that area's "Decisions that apply now" in the same commits; the entry it replaces leaves the list.
- Which area describes a path: the `paths` in each area file. Which areas need a look: `bin/ytstack-spec drift`.
- The format: `docs/ux/spec-format.md` in the ytstack plugin.
