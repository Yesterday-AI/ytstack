---
milestone: M030
project: ytstack
size: M
created: 2026-11-14T15:30:00Z
status: done
total_slices: 3
completed_slices: 3
---

# M030 Roadmap

**Goal:** A project that runs its own review agents learns from every finding a review bot made that those agents missed: the escape is detected at merge, recorded once and counted, and a repeated or severe one turns into a proposed change to the owning role's file, which a person approves.

**Exit criteria:** see `M030-CONTEXT.md`.

## Slices

- [x] S01 -- `bin/ytstack-review-escapes` reads a pull request's bot threads, their resolution and the own roles' findings, and says which bot findings escaped.
- [x] S02 -- Projects declare their own reviewers in `REVIEW.md`, and escapes are recorded and counted as signals of `kind: review`.
- [x] S03 -- The `review-lessons` skill turns recurring or severe escapes into role-file proposals, runs after merges, and `retro` reports escape rates.

## Run order

Sequential. Before S03 fixes the threshold, S01's script runs read-only on recent merged PRs of a pilot project to measure how often bot and role findings can be matched.
