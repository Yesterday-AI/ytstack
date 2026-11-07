---
milestone: M016
slice: S01
task: T03
project: ytstack
closed: 2026-11-07T11:37:06Z
verification: passed
---

# M016-S01-T03 -- Summary

## Commits

- `d376fbb` -- M016-S01-T03: plan session-end rewrite
- `f63913a` -- M016-S01-T03: session-end appends one JSON line out-of-tree; lib prefers real jq/python3 binaries and md5 keys for the 1.5s budget

## Outcome

`hooks/session-end` appends exactly one JSON line (`timestamp`, `event`, `reason`, `session_id`, `project`, `milestone`, `slice`, `task`, `worktree`, `linked_worktree`) to `<state>/repos/<repo>/worktrees/<wt>/sessions/<session_id>/session.jsonl`, built with `printf` and `sed` escaping (no `jq`/`python3` encoder). It never creates `.ytstack/journal/` and never touches the checkout. Per-session files make it single-writer. The library gained `yt_jq` / `yt_python` (prefer `/usr/bin`, homebrew and `/usr/local` binaries over version-manager shims and the macOS `/usr/bin/python3` stub), `YT_TRIGGER` / `YT_REASON` from the single parse call, and md5-based 16-hex keys (`/sbin/md5 -q`, `md5sum`, then sha fallbacks).

## Deviations from plan

The budget test failed first: 5 runs took 5.05 s. Measured causes: asdf `jq` shim 150-240 ms per call (called twice), `shasum` (perl) 110 ms per call (called twice), `/usr/bin/python3` stub 0.4-1 s. Fixes landed in the library instead of the hook (binary preference, one parse call, md5 keys), which also speeds up every other hook. Key digest is therefore md5, not sha256 as written in DECISIONS 2026-11-07 / M016-CONTEXT -- same 16-hex shape, same uniqueness properties for this purpose; CONTEXT gets a one-line note in S03-T03's docs pass. After the fix: session-end 0.5 s cold / pre-compact 0.3 s with the user's real PATH.

## Follow-ups

- KNOWLEDGE gotcha (S03-T03): version-manager shims and the macOS python stub dominate hook latency; resolve real binaries once.
- `tests/session-end.test.sh` case 8 depends on `python3` for timing; fine on macOS and CI, document.

## Verification

Command: `bash -n hooks/session-end && /bin/bash tests/session-end.test.sh` -- passed (32/32, 5 runs in well under 2.5 s). Other suites: pre-compact 39/39, git-ctx 46/46, post-tool-use-bash 10/10.
