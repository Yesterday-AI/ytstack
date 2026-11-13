---
milestone: M022
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M022-S01-T01: spec format contract, decision, roadmap plan`).

## Outcome

`docs/ux/spec-format.md` defined the technical spec: `SPEC.md` as a one-page entry point, one area file per system area with five frontmatter fields and eleven section names in a fixed order, the pointer-only rule, the maintenance rules (plan, closure, drift, decisions, scaffolds) and the list of what `bin/ytstack-spec lint` fails and warns on. The glossary in `docs/ux/writing-style.md` got the entry `technical spec`, set apart from the design-doc `spec`. `DECISIONS.md` got the entry "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)". `ROADMAP.md` got the section "Planned 2026-11-13" with the four corrections of the review comment and the M022 row. `M022-CONTEXT.md`, `M022-ROADMAP.md` and the three slice plans were written.

## Deviations from plan

- The plan in `ROADMAP.md` listed eleven mandatory sections for an area file. The contract requires four (Purpose, Where implemented, How to verify, Decisions that apply now); the other seven are optional and keep their place in the fixed order. Eleven mandatory sections would have produced filler in pointer-only files.
- The task line names a section in `docs/concept.md`. It became one bullet in the artifact list there ("Technical spec"), and it is committed with S01-T05, which carries the other corrections to that file.
- `ROADMAP.md` rides in this commit as a whole. Its frontmatter and section-state fixes belong to S01-T05; the state of its M023 row belongs to M023.

## Follow-ups

None.

## Spec

none -- not covered by an area yet: the spec did not exist before S01-T04; T04 writes the area files with these changes included

## Verification

Command: `python3 bin/ytstack-check` and the U+2014 count for `docs/ux/spec-format.md` -- passed at the working tree on top of `f4f54ab` in the local checkout. The checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line; the count printed 0.

Not checked: whether a session that reads only the format document writes a valid spec. No model run has read it yet (`claude plugin eval` was not started). `bin/ytstack-check` scans skill bodies for U+2014, not `docs/`; the count above is the only check on the new document.
