---
milestone: M025
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T18:33:00Z
verification: passed
---

# M025-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M025-S01-T01: bin/ytstack-runtime reads RUNTIME.md and runs the product per worktree`).

## Outcome

`bin/ytstack-runtime` was built with six commands. `get` printed one value of "Run" or "Release" and exited 1 for a missing file, section or key. `signals` printed one tab separated line per source. `check` named each defect of the three sections on its own line and passed a file without them. `up` started the product in a process group of its own on a free port of the range, waited for `ready`, and printed `URL:`, `PORT:`, `PID:`, `LOG:` and `COMMIT:`; two directories got two ports, a port with a foreign listener was skipped, a second `up` printed the same instance. A start command that exited, a `ready` that never passed and a `ready` that hung ended with exit 1, the end of the log and no process left. `down` ended the group, children included, after the `stop` command when one was set. `tests/ytstack-runtime.test.sh` pins all of it, the live cases against a real `python3 -m http.server`.

`docs/ux/runtime-format.md` was corrected where the implementation settled something; see Deviations.

## Deviations from plan

- **Free text in a section.** The format said that every line of a section that is not `- key: value` fails. Now only list lines are read; other lines are free text, and a section without a list line counts as absent. Reason: the scaffolds write the three headings with one line of explanation, and `adopt-brownfield` names the source of a value there. One slip is still caught: a key line of "Run" or "Release" that lost its `- `.
- **A bar inside a signal command.** ` | ` separates the fields of a signal, and a `read` command often pipes. A new field starts only where `<word>: ` follows the bar; anything else stays part of the command.
- **More than the format listed in `check`:** a key twice, a signal name that is no lowercase slug, `ports` outside 1 to 65535.
- **`up` refuses a file that fails `check`**, whichever section the problem is in. One rule instead of a second validation of "Run" in bash.
- **A second `up` asks `ready` again** before it prints the instance, so exit 0 always means a product that answers. An instance that no longer answers within the timeout is stopped.
- **`COMMIT:` says `(with uncommitted changes)`** when the working tree differs from the commit, and `none` outside a repository. A task is usually verified before its commit; the bare hash would name a state that is not the one running.
- **`ready` is bounded.** An attempt that still runs at the deadline is stopped, so a check that hangs cannot outlast `--timeout`. Default timeout: 60 seconds.
- **`down` does not trust a pid alone.** The instance file records when the process started (`/proc/<pid>/stat` on Linux, `ps -o lstart=` elsewhere). A recorded pid that another process carries counts as not running, and its group is not ended.
- **`status` exits 1** for `not running`; `get` exits 64 for a section other than "Run" and "Release".
- **`start` stays in the foreground.** A command that returns counts as a failed start. A product that detaches by itself (`docker compose up -d`) is written in its foreground form with a `stop` line.

## Follow-ups

- shortcut in `bin/ytstack-runtime`: two `up` at the same moment in one worktree both start (one agent per worktree is the model). Upgrade: a noclobber claim on the instance file.
- shortcut: two worktrees that pick the same port in the same second. The loser's start fails to bind; `up` sees that when the process is gone by the time `ready` passes, not later. Upgrade: claim the port in a shared file.
- shortcut: the token rule is the one of `bin/ytstack-handover`, as a copy in awk. A password inside a connection string and a short password are not seen. Upgrade both scripts together.
- The fallback of the port probe for a bash without `/dev/tcp` (`nc -z`) has no test: every bash at hand has `/dev/tcp`.
- Not part of this task and not touched: `yt_epoch` in `hooks/lib/git-ctx.sh` returns nothing under BusyBox `date` (alpine without GNU coreutils), so `tests/git-ctx.test.sh` fails one assertion there ("lint: stale last_updated"). It fails the same way at the base commit `8cb7db4`.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-runtime.test.sh` -- passed at the working tree on top of `8cb7db4` in the local checkout (macOS, bash 3.2.57). Last line `125 passed, 0 failed`, exit 0.

Also run on that tree: `bash tests/run-all.sh` locally, `ALL SUITES PASSED` (21 suites); `python3 bin/ytstack-check`, exit 2, 27 warnings (the baseline), no `[fail]`; `bash tests/run-all.sh` in `ubuntu:26.04` from an export, `ALL SUITES PASSED`; every suite on its own in `alpine` 3.24.4 from an export: this suite `125 passed, 0 failed`, all others passed except the one assertion of `git-ctx` named under Follow-ups.

Not checked: a session in which an agent ran `up`, verified at the instance and ran `down`. A product other than the fixture server (a dev server that forks workers, a container). The `nc` fallback of the port probe. A host without `/proc` and without `ps`.
