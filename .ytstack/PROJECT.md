---
name: ytstack
slug: ytstack
created: 2026-04-23T14:49:41Z
updated: 2026-04-23T14:49:41Z
---

# ytstack

**One-liner:** A Claude Code plugin for AI-first software development: clamp around the best superpowers/gstack skills plus Project-OS artifact discipline, orchestrated via SessionStart hooks.

## What this project is

ytstack is an opinionated software-development OS for AI agents, packaged as a Claude Code plugin. It cherry-picks the best skills from superpowers (execution: TDD, systematic-debugging, verification) and gstack (decision: plan-ceo-review, office-hours), adds Project-OS artifacts (`PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, milestone/slice/task hierarchy) adapted from external AI-first methodology, and orchestrates everything via SessionStart-hook-driven context injection.

The goal: replicate ~95% of GSD v2's value (project-management, context management, artifact lifecycle) without building GSD's TypeScript runtime. Use Claude Code's native Agent Teams feature for per-task fresh context instead.

## Why it exists

Three observations drove this:

1. **superpowers and gstack each solve a different slice of the AI-coding problem.** Neither alone is enough. Combined naively, they conflict (interactive prompts, skill overlap, token bloat).
2. **GSD solves context-rot and autonomous long-running work, but requires its own TypeScript runtime.** Too heavy for most teams.
3. **An external AI-first methodology provides a conceptual framework** that works across AI tools, but has no Claude Code implementation.

ytstack is the cleanup: one curated, opinionated Claude Code plugin that takes the best from all three, skips the overhead, and ships a shareable stack.

## Success criteria

- A team can install ytstack with one `/plugin install` and start a tracked project in under 5 minutes.
- Every skill in ytstack follows the UX contract (AskUserQuestion format, writing-style, skill-structure) enforced by CI.
- An 8-hour milestone can run with minimal user intervention via Agent Teams + ytstack skills, producing committed artifacts at each phase.
- Zero dependencies on external runtimes (no GSD CLI, no gstack binary).
- Upstream superpowers and gstack stay vendored via git subtree, updateable via `./sync-upstream.sh`.

## Current status

M001 (Foundation) in progress. UX contracts locked (docs/ux/*). First skill drafted (init-project). Plugin manifest and test-install pending. See `.ytstack/ROADMAP.md` for full milestone breakdown.
