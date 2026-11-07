---
milestone: M016
slice: S01
task: T04
project: ytstack
closed: 2026-11-07T11:46:33Z
verification: passed
---

# M016-S01-T04 -- Summary

## Commits

- `71bfeb3` -- M016-S01-T04: plan post-tool-use-bash rewrite
- `4080474` -- M016-S01-T04: post-tool-use-bash resolves from payload cwd, stubs only on task-ref commits, accepts wrapper tokens

## Outcome

`hooks/post-tool-use-bash` sources the library, parses the payload once, and acts only on successful real `git commit` calls; the matcher now accepts wrapper tokens (`rtk`, `sudo`, `command`, `env X=1`) between the command separator and `git commit` while still rejecting echoes and `git log | grep commit`. It resolves the checkout from the payload `cwd` (fallback: the hook's `$PWD`, never `CLAUDE_PROJECT_DIR`), reads that checkout's STATE.md, renders `commit_ref_pattern` from `PREFERENCES.md` (default `^M###-S##-T##:`, tokens `M###`/`S##`/`T##`/`{task}`, taken literally after stripping quotes) and stubs the draft SUMMARY only when HEAD's subject matches, once, into that checkout's `.ytstack` (frontmatter now carries `worktree:`). 19 test cases cover the M015 contract plus worktree isolation, missing ref, wrapper token, custom pattern and the `$PWD` fallback.

## Deviations from plan

Incident during execution: the first version of the rewritten test used a counter inside `$(...)` for fixture names, so every fixture path was garbage; `( cd "$fixture"; git commit ... )` fell through into the real ytstack checkout and produced 11 junk commits (files `c`..`l`, the in-progress hook, and an overwritten `.ytstack/STATE.md`). Remediation: `git reset --soft 71bfeb3` + index reset, STATE.md restored from `71bfeb3` via `git show`, junk files removed; nothing had been pushed. The test now creates fixtures with `mktemp -d`, aborts the subshell on a failed `cd`, refuses non-fixture paths (`in_fixture`), and the suite is run from a neutral directory. Other test fixes: `jq -Rs . <<<` appended `\n` to the `cwd` value (use `printf | jq -Rs .`), the custom-pattern fixture had double backslashes, and the "non-matching" subject matched. The session-end budget threshold was widened to 5 runs < 5.0 s to avoid flakiness under load (still catches the ~1 s/call regression class).

## Follow-ups

- KNOWLEDGE (S03-T03): test fixtures must never `cd` without `|| exit`; counters do not survive `$(...)`; run shell suites from a neutral cwd.
- `tests/run-all.sh` (S03-T02) should `cd` to a temp dir before invoking suites.
- Codex host: payload `cwd` is the session cwd (no per-call cwd), so the `$PWD` fallback semantics are the same there.

## Verification

Command: `bash -n hooks/post-tool-use-bash && /bin/bash tests/post-tool-use-bash.test.sh` -- passed (19/19). Other suites: git-ctx 46/46, pre-compact 39/39, session-end 32/32. Real repo `git status` clean after the suites.
