---
milestone: M027
project: ytstack
created: 2026-11-13T18:09:00Z
size: M
---

# M027 -- Context

## Goal

What production says reaches the plan: a scheduled run reads the project's signal sources, separates real findings from noise and records each once; an incident gets a record and proposed mitigations that only a person carries out.

## Exit criteria

- `bin/ytstack-signals new` records a finding once: a second sighting of the same key raises its count instead of creating a file, a sighting of a fixed one is recorded as a regression, a dismissed one stays dismissed.
- The skill `signal-intake` reads every source of the "Signals" section of `RUNTIME.md` with its read time, records findings through the script and changes nothing else: no product file, no target.
- The skill `incident` writes one record with what is seen (each fact with its read time), a timeline, hypotheses with their evidence and proposed mitigations; every mitigation is a staged script made with `bin/ytstack-handover` that the agent never runs; the root cause is found afterwards through `systematic-debugging`.
- Neither skill runs a command that changes the target. A missing "Signals" section stops `signal-intake` with the format to add.
- `bin/ytstack-signals check` validates findings and incident records.
- `bash tests/run-all.sh` passes on macOS and in the Linux containers; `bin/ytstack-check` reports no failure.

## Size

M -- see `M027-ROADMAP.md`.

## Decisions locked in discuss phase

- 2026-11-13T18:09:00Z: the procedure is skill work; the trigger comes from the host (a scheduled run, a person) and the read access from the project (the commands under "Signals"). ytstack ships no service.
- 2026-11-13T18:09:00Z: read only. An unattended run with access to production never changes it; a mitigation is a handover script.
- 2026-11-13T18:09:00Z: no perf-factory skill of its own. The intake records the finding; the cause is `systematic-debugging`, the fix a normal task.
- 2026-11-13T18:09:00Z: sitting in an incident channel and answering there is an integration of the host and stays out.

## Open questions

(none)
