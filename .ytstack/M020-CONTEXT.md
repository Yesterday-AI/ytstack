---
milestone: M020
project: ytstack
created: 2026-11-09T16:29:16Z
size: M
---

# M020 -- Context

## Goal

Kimi Code CLI users can load ytstack's existing skills and receive its lifecycle context through an official, documented adapter without maintaining a second skill tree.

## Exit criteria

- Kimi installs ytstack through a native plugin manifest that selects the existing `skills/` tree and exposes the skills as `ytstack:<name>`. No ytstack `extra_skill_dirs` entry, generated skill tree or copied skill directory is required.
- The manifest uses `sessionStart.skill` for the static directive, system-prompt for the adapter and native hooks for lifecycle. Shared scripts retain Claude Code and Codex behavior. Kimi uses explicit plain output only where consumed: SessionStart and PostCompact prepare pending project context, and UserPromptSubmit injects it on the next real user prompt.
- The pinned gstack installation remains independent and is exposed without copied skills. A same-name test proves original invocation by exact path when available, with no shadowing, recursive wrapper invocation or loss of ytstack artifact handling; older hosts retain the source-check and explicit stop.
- Regression tests cover the native manifest, payload and output compatibility, pending lifecycle and paths containing spaces. The standard test suite and contract checker complete with no new failures. Fresh isolated installations on supported Kimi versions verify namespaced skill discovery, gstack coexistence, dynamic context on a real user prompt, handoff and journal behavior.
- Installation and support boundaries are documented in `docs/kimi.md`, with README and QUICKSTART pointers: tested Kimi versions, native installation/reinstall/reload, user scope, independent gstack discovery, required local tools, hook fail-open, Web SessionEnd limitations and unsupported Claude-specific workflows.

## Size

M -- auto-selected in non-interactive planning. See `M020-ROADMAP.md` for slice breakdown.

## Planning input

GitHub issue #30, the user's instruction to proceed, and the maintainer's requirement that every new host reuse the existing Claude Code and Codex plugin as much as possible. The same gstack-identity requirement applies to later OpenCode (#28) and Vibe (#29) work; their implementations remain out of M020 scope.

## Decisions locked in discuss phase

2026-11-09: Keep the existing `skills/` tree and shared lifecycle scripts as the single source, following the Codex distribution decisions. Add only Kimi-specific manifest, runtime and documentation surfaces.

2026-11-09: Prefer Kimi's native plugin manifest over `extra_skill_dirs` for ytstack. It preserves `ytstack:<skill>` names and provides native session-start, system-prompt and lifecycle integration. Use the maintainer-approved multi-host and gstack-identity requirements recorded in DECISIONS.md.

## Open questions

- Verify the pending-context bridge on the locally installed 2.5.3 and current stable 2.6.2, including exact gstack `path` selection where available.
- A real-model smoke test for semantic skill selection remains a separately authorized operator step; local fixtures prove host mechanics only.

## Reassessment 2026-11-14T11:03:02Z

After **S01**, changed the roadmap without changing the milestone goal or slice count:

- S02 no longer assumes that SessionStart stdout reaches the model. It adds a per-session pending bridge using SessionStart/PostCompact plus UserPromptSubmit, while keeping `sessionStart.skill` as the static bootstrap.
- S02 adds PostCompact and real close/replay tests, and the adapter gains exact gstack path selection when the host supports it.
- S03 now explicitly covers tested Kimi versions, hook fail-open and Web SessionEnd limits.

Reason: official documentation, current source at `f082f04`, upstream issues/PRs and real plugins showed that SessionStart output is discarded, UserPromptSubmit consumes plain context, and newer Kimi versions support exact skill paths. Evidence and alternatives: `docs/research/2026-11-14-kimi-native-plugin-best-practices.md`.

## PR integration on origin/main 0.8.0

The PR was rebuilt directly on `origin/main` instead of integrating the stale local 0.4.2 base. The native manifest, shared skill tree and pending lifecycle design remain. The earlier external-gstack design and exact-path tests are superseded by the 2026-11-14 decision that shipped six self-contained gstack adaptations in 0.6.0. Kimi invokes those skills as `ytstack:<name>`; no gstack installation, extra directory or cross-plugin call is added. The live suite now tests all six managed adaptation paths and namespace isolation from a project override. Original task plans and summaries above remain historical evidence of the earlier base; final PR verification is appended to `M020-S03-T02-SUMMARY.md`.
