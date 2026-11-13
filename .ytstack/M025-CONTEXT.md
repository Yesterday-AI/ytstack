---
milestone: M025
project: ytstack
created: 2026-11-13T18:09:00Z
size: L
---

# M025 -- Context

## Goal

Whether a person has to look at a change is decided per change, from its risk and its kind: a script computes a floor from the diff, an independent reviewer states the class, each area of the technical spec says how much may merge without a person, and a kind of change can require a second review with its own evidence, for a user interface a visual one at the running product.

## Exit criteria

- `bin/ytstack-runtime` starts the product of a project in a worktree from the "Run" section of `RUNTIME.md`, on a port of its own, and stops it again; `check` fails on a malformed section and on a token-looking string.
- `bin/ytstack-risk floor` returns `person` for a change to a rule document, to the invariant sections of an area file, to the checks and to a path no area covers, and at least `normal` for the never-low patterns and for a change over the size limit.
- `bin/ytstack-risk route` returns `unattended` only with an approving round line of another reviewer that is valid for the head, a class within the ceiling of every touched area, `invariants: none` and a passing record for every required lens; every other case is `person` with its reasons.
- A lens with `evidence: visual` passes only with a manifest whose hashes match images the reviewer took itself; `not run` never counts as a pass.
- `merge_by: risk` is the default; a project that declares no `auto_merge` and no `REVIEW.md` gets exactly the behaviour of `merge_by: human`.
- `code-review` records risk, severity, reach and the invariants a change touches; `finish-lane` merges on its own only when the route is `unattended` and the host's gates hold, and tells the person what merged that way.
- `bash tests/run-all.sh` passes on macOS and in the Linux containers (alpine and ubuntu 26.04); `bin/ytstack-check` reports no failure; no file under `vendor/` changed.

## Size

L -- see `M025-ROADMAP.md`.

## Decisions locked in discuss phase

- 2026-11-13T18:09:00Z: source is `docs/research/2026-11-13-openai-software-factory.md` and the operator's instructions in the session of 2026-11-13: the decision falls per change by severity and reach; a person is the exception path; a user interface change needs an independent, truly visual review against the project's guidelines; conceptual rules of a project are reach, and a change that touches them goes to a person.
- 2026-11-13T18:09:00Z: formats first: `docs/ux/runtime-format.md` and `docs/ux/review-policy-format.md`.
- 2026-11-13T18:09:00Z: the route without a person is the default mechanism (`merge_by: risk`), and everything undeclared goes to a person.
- 2026-11-13T18:09:00Z: the class is stated by the reviewer, never by the author; a script sets the floor.
- 2026-11-13T18:09:00Z: a lens is defined by the documents it reads, not by a role. No reviewer personas.
- 2026-11-13T18:09:00Z: `visual-review` is a native skill. The gstack design review fixes what it finds, which an independent reviewer must not do.

## Open questions

(none)
