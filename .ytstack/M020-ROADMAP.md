---
milestone: M020
project: ytstack
size: M
created: 2026-11-09T16:29:16Z
status: done
total_slices: 3
completed_slices: 3
---

# M020 Roadmap

**Goal:** Kimi Code CLI users can load ytstack's existing skills and receive its lifecycle context through an official, documented adapter without maintaining a second skill tree.

**Exit criteria:**
- Kimi installs ytstack through a native plugin manifest that selects the existing `skills/` tree and exposes the skills as `ytstack:<name>`. No ytstack `extra_skill_dirs` entry, generated skill tree or copied skill directory is required.
- The manifest uses `sessionStart.skill` for the static directive, system-prompt for the adapter and native hooks for lifecycle. Shared scripts retain Claude Code and Codex behavior. Kimi uses explicit plain output only where consumed: SessionStart and PostCompact prepare pending project context, and UserPromptSubmit injects it on the next real user prompt.
- The six gstack-derived skills remain self-contained ytstack adaptations under their qualified names. Native tests activate each from the managed plugin and prove that a same-name project override does not replace `ytstack:<name>`. No external gstack installation or cross-plugin invocation exists.
- Regression tests cover the native manifest, payload and output compatibility, pending lifecycle and paths containing spaces. The standard test suite and contract checker complete with no new failures. Fresh isolated installations on supported Kimi versions verify namespaced skill discovery, adapted-skill identity, dynamic context on a real user prompt, handoff and journal behavior.
- Installation and support boundaries are documented in `docs/kimi.md`, with README and QUICKSTART pointers: tested Kimi versions, native installation/reinstall/reload, user scope, self-contained gstack adaptations, required local tools, hook fail-open, Web SessionEnd limitations and unsupported Claude-specific workflows.

## Slices

Slice detail lives in per-slice `M020-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [x] S01 -- A native Kimi installation loads every shared ytstack skill under its own namespace, including the six self-contained gstack adaptations.
- [x] S02 -- Native static bootstrap plus pending dynamic context through UserPromptSubmit, PreCompact/PostCompact handoff handling and SessionEnd journaling through shared scripts, without changing Claude Code or Codex behavior.
- [x] S03 -- Users can install, update and troubleshoot the Kimi adapter from the repository documentation, backed by the complete verification suite and an explicit Kimi version matrix.

## Run order

Slices execute sequentially. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits reality.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md
