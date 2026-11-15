# Reconcile 2026-11-15

Run by `ytstack:reconcile` (0.3.0 from this checkout) on the ytstack repository itself, after the maintainer asked whether its own artifacts were current. The maintainer approved the proposed cleanup ("ja go"), which covered both classes below, and decided `merge_by: human` for this repository.

| Class | Found | Choice | Where |
| --- | --- | --- | --- |
| Draft stubs, unfilled drafts, planned never sliced, untracked, `.local` | 0 each | -- | -- |
| STATE.md history | 26 earlier status paragraphs, 37,523 bytes (bound 12,000); "Next action" still named operator actions of M025-M027 | A: moved verbatim | `archive/2026-11-15/STATE-history.md` |
| Closed milestones | 19 (M010, M012, M016-M028, M030-M033) | A for M010-M030 (271 files); kept M031-M033 (released in 0.11.0 today, still looked up) | `archive/2026-11-15/M###/` |
| External plan | none | -- | -- |

Every line of the old `STATE.md` is in the new `STATE.md` or in the archive file, except `last_updated` (new time) and the "Open decisions" sentence, which named a stale entry count. The new `STATE.md` (1,300 bytes) holds the frontmatter, the current status, a fresh "Next action" and "Open decisions".

Also done in the same change, outside the reconcile classes:

- Gate G01 of M024 (open, never lapses) moved with its slice plan; it continues as `questions/Q001` with context, options and a recommendation.
- `PREFERENCES.md` gained a `## Ceremony` block with today's defaults and `merge_by: human`, so `ytstack-upkeep` no longer reports risk routing as not set up.
- `ROADMAP.md`: the stale "Total" line now counts every milestone; `PROJECT.md` names Kimi Code next to Claude Code and Codex.
