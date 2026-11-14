---
milestone: M033
project: ytstack
created: 2026-11-15T00:45:00Z
size: S
---

# M033 -- Context

## Goal

Agents feed their experience with ytstack back upstream through an explicit, configurable channel: bugs, gaps and workarounds, proposals and field evidence become issues at `Yesterday-AI/ytstack` (filed by the agent or suggested to the person, per setting), without duplicates and without personal or customer data.

## Exit criteria

- A setting `upstream_feedback: suggest | file | off` (default `suggest`, today's behaviour) in `.ytstack/PREFERENCES.md`, with a user-level fallback in `~/.ytstack/config`; `using-ytstack`'s "Reporting ytstack issues" paragraph becomes this channel.
- The channel names what goes upstream and when: bugs; gaps and workarounds (a tool existed but was not used, or was missing); proposals from `retro`, `lane-retro`, `review-lessons` and the M032 lesson loop when the lesson concerns ytstack itself; field evidence from first real-host runs.
- Rules the agent follows, checked where a machine can: search existing issues first and comment instead of duplicating; one observation per issue with evidence (versions, commands, counts); no personal or customer data; tell the person the link in one line.
- `retro` and `lane-retro` end with an "Upstream" section filed per the setting.
- Docs, CHANGELOG; all suites, checker, Codex and Kimi tests, plugin validation; an eval case for `file` and `suggest`.

## Size

S -- 1 slice.

## Planning input

Issue #55: feedback guidance covers only misbehaving skills, as a suggestion; the person had to tell every session "file your experiences and optimization proposals there as issues, always". Issues #53, #54, #57 and #61 are themselves examples of the reports the channel should produce.

## Decisions locked in discuss phase

2026-11-15: Default stays `suggest`; `file` is opt-in per project or per user, because filing publishes text to a public repository.

## Open questions

- How the agent checks for duplicates cheaply (`gh issue list --search`), and what it does without `gh` auth (falls back to `suggest`).
