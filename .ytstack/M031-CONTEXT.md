---
milestone: M031
project: ytstack
created: 2026-11-15T00:45:00Z
size: L
---

# M031 -- Context

## Goal

An agent in a project that adopted ytstack uses the factory tools that are already shipped (risk route, PR watch, release watch, signals, review lessons) without being told, learns when the plugin changed under it, and a person can set those tools up from one guide.

## Exit criteria

- `coordinate` has an explicit "Factory tools" step: `ytstack-risk route` before every merge (also when the coordinator merges itself, not only through `finish-lane`), PR watch registration of all open PRs, `ytstack-watch release` after every production release, `signal-intake` / `incident` for signals, `review-lessons` after a merge with a bot finding. Each tool is named with the command and the condition under which it is skipped.
- `ytstack-risk route` can return `unattended` in a repository where agents may not write in the main checkout and a ruleset binds reviews to the head: the review round comes from the host (the review on the current head: commit, author, verdict line) instead of a line the pull request has to commit. A fixture test reproduces the context-mcp case (issue #54 comment, context-mcp #1715) and routes it `unattended` where the rules allow it.
- The SessionStart block (and `ytstack-upkeep`) says once per session, in one line each and only when it applies: risk routing not configured although the project has `.ytstack/spec/` (everything goes to a person); PR watch off or its worker without a fresh heartbeat; `RUNTIME.md` without "Release" or "Signals" although the project releases or has signals; and "ytstack X.Y installed, this session loaded skills of A.B: reload the skills you use" with the CHANGELOG headings in between, when the installed plugin is newer than the one the session started on.
- `coordinate` can rotate in one step while lanes run: write the handoff, re-register the PR watches to the successor session, hand over the background agents' addresses; the rule "rotate after one compaction" becomes followable under load.
- `QUICKSTART.md` has a "Setting up the factory tools" section (greenfield and brownfield/upgrade variants: `REVIEW.md` and `auto_merge`/`merge_by: risk` with a dry `route` on a recent PR, PR watch enable/install-worker incl. the shim caveat and coordinator registration, `RUNTIME.md` "Release" and "Signals", `ytstack-upkeep` on a schedule) and an "Upgrading from 0.x" checklist.
- `reconcile` (or `adopt-brownfield`) detects a large plan outside `.ytstack/` (for example `plans/*.md` tables) and offers to map it into milestones and slices, so `ytstack-frontier` sees it.
- Docs, CHANGELOG; all suites, checker, spec lint/drift, Codex and Kimi tests and plugin validation pass; evals for changed skills with a case.

## Size

L -- 5 slices.

## Planning input

Issue #54 (coordinator session in context-mcp hand-built a PR babysitter, a review tiering and a release post-check that 0.7-0.9 already ship), its comments (setup guide gap; `route` can never return `unattended` there; the subagent-PR watch gap, closed in 0.9.1/0.9.2), and the two smaller observations of issue #61 (a session keeps the skill text it loaded; rotation after one compaction is not followable under load). Points 1 and 2 of #54 for the PR watch are done (0.9.1, 0.9.2).

## Decisions locked in discuss phase

2026-11-15: The milestone makes existing tools explicit and reachable; it adds no new factory tool. New tools for incidents and upstream feedback are M032 and M033.

2026-11-15: Warnings appear only when they apply and once per session; a project that uses none of the tools sees nothing.

## Open questions

- Version awareness: where does a session learn which plugin version it started on? Candidates: the SessionStart hook writes the version into the session state directory; a later hook compares it with the installed version.
- Risk route: does every host expose the verdict line of a review with its commit (GitHub reviews: `commit_id`, `body`), and how does a round count across pushes without a file?
- External plans: detect only, or also convert? Plan: detect and propose the mapping as a question; the conversion runs only after a yes.
