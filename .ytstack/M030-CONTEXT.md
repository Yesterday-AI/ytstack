---
milestone: M030
project: ytstack
created: 2026-11-14T15:30:00Z
size: M
---

# M030 -- Context

## Goal

A project that runs its own review agents learns from every finding a review bot made that those agents missed: the escape is detected at merge, recorded once and counted, and a repeated or severe one turns into a proposed change to the owning role's file, which a person approves.

## Exit criteria

- `bin/ytstack-review-escapes --pr N` (read-only, `gh`) lists for a pull request every review-bot thread with its resolution (`fixed`: a later commit on the PR changed the thread's lines; `rejected`: resolved without such a change; `open`) and whether an own role reported the same finding on the same lines (`caught` / `escaped`). Exit codes and TSV output are documented; tests run against recorded fixtures, never the network.
- `.ytstack/spec/REVIEW.md` gains an optional `## Own reviewers` section: one line per role with the marker the role's findings carry, the role file lessons go to, and optionally which bot logins count. `bin/ytstack-risk check` (or `ytstack-spec lint`) validates it. Without the section nothing changes for a project.
- Escapes are recorded with the existing signals machinery: `kind: review` in `docs/ux/signal-format.md` and `bin/ytstack-signals`, key `review:<role>:<class-slug>`, so a recurring class raises `count` instead of opening a new record. Rejected bot findings are not recorded.
- A skill (`review-lessons`) runs the intake after a merge (called from `finish-lane` and `ship`, also on demand), assigns the owning role and the class, and when a class reaches the threshold (second sighting, or the first at critical/high) writes a proposal: the exact checklist or rule line for the role file, handed to a person as a question; it never edits a rule document itself.
- `retro` reports the escape rate per role for the milestone window.
- Docs (`docs/ux/review-policy-format.md`, `docs/ux/signal-format.md`, README, QUICKSTART), CHANGELOG; all suites, checker, Codex tests and plugin validation pass.

## Size

M -- 3 slices.

## Planning input

The maintainer's question how bot findings on PRs should feed the learning loop of a project's own review agents (meinKontext / context-mcp: roles `code`, `concept`, `tests`, `security` in `.github/reviewers/`, findings marked `<severity> (`<role>`)`, roles read their sources fresh at every review), and the go-ahead to plan it in ytstack, with the project-specific part as an issue in context-mcp: Yesterday-AI/context-mcp#1650 (declare the roles in `REVIEW.md`, keep role findings machine-readable, pilot on 30 merged PRs, wire it in).

## Decisions locked in discuss phase

2026-11-14: Lessons live in files, not in memory: the role reads its file at every review, so a lesson takes effect only as a line in the role file or its rule source.

2026-11-14: A lesson is a rule change, so a person approves it (the risk route already sends rule documents to a person). The intake proposes; it never writes the role file.

2026-11-14: Escapes reuse the signals ledger (`kind: review`) instead of a new record type: one finding per class, counted, with state `open` / `planned` / `fixed` / `dismissed`.

2026-11-14: Only `fixed` bot findings are lessons. A bot finding resolved without a code change is a false positive and is not recorded.

2026-11-14: Generic in ytstack: detection, classification, records, proposal format. Per project in `REVIEW.md`: which roles exist, their markers, their lesson files, which bots count.

## Open questions

- How reliably can "the same finding" be matched between a bot thread and a role finding? Plan: same file and overlapping lines, then the intake judges the text; measured on real merged PRs of a pilot project before the threshold is fixed.
