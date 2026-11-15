---
milestone: M025
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T18:42:00Z
verification: passed
---

# M025-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M025-S01-T02: scaffolds write Run, Release and Signals; verification uses a running instance`).

## Outcome

The `RUNTIME.md` template of `init-project` gained the headings "Run", "Release" and "Signals" with one line of free text each. `adopt-brownfield` got the same headings and a rule: a key line only for a command that a document or a script of the project states, with the source named in the free-text line; "Run" only with `start` and `ready` together; `bin/ytstack-runtime check` after writing. Both templates pass `check` as written, and the suite of the script proves that on the text of the two skills.

`plan-task` now says when a plan names `Environment: instance from bin/ytstack-runtime up`. `verification-before-completion` prints `RUNTIME_TOOL` and `RUN_SECTION` in its preamble and says in its ytstack paragraph how a check at the running product goes: `up`, the check against `URL:`, the `COMMIT:` line with the output, `down`; without a "Run" section or with a failed `up` the check is reported as not possible. The implementer and the verifier carry the same rule in one sentence each; for the verifier such a task gets no PASS.

## Deviations from plan

- The preamble of `verification-before-completion` changed, not only its prose: two lines print where the script is and whether "Run" exists. The agent then knows before it starts whether the check is possible. The vendored text was not touched.
- `tests/skill-preambles.test.sh` got three assertions for those two lines.
- The versions of the four skills were raised (`init-project` 0.2.1, `adopt-brownfield` 0.2.1, `plan-task` 0.3.2, `verification-before-completion` 0.3.0), as earlier tasks did.

## Follow-ups

- `plan-task` does not look into `RUNTIME.md` itself; it tells the user that the check will be reported as not possible while "Run" is missing. A preamble line like the one of `verification-before-completion` would make that a fact instead of a sentence.
- No eval case covers a task verified at a running instance.

## Spec

- skills: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-runtime.test.sh && /bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `d2f87e2` in the local checkout (macOS, bash 3.2.57): `129 passed, 0 failed`, `469 passed, 0 failed`, `OK (with 28 warning[s])`, exit 2, no `[fail]`. The one warning above the baseline of 27 is the spec drift of `checks-and-evals` after `d2f87e2`, which the coordinator closes.

Also run on that tree: `bash tests/run-all.sh` locally, `ALL SUITES PASSED`; `python3 -m unittest discover -s tests -p 'codex*_test.py'`, 13 tests, OK; the two suites named above in `ubuntu:26.04` and in `alpine` 3.24.4 from an export of the working tree, same counts. The run of all suites in both containers on the export of this commit follows the commit and stands in the worker's report.

Not checked: a session in which `init-project` or `adopt-brownfield` wrote the file, and one in which an agent verified a task at a running instance. Whether a model reads the new sentences as intended: no eval was run.
