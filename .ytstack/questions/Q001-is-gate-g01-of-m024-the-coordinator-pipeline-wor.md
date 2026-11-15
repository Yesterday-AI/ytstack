---
id: Q001
state: open
decides: the maintainer
opened: 2026-11-15T11:27:21Z
asked: none
answered: none
blocks: gate G01 (M024-S02, archived 2026-11-15)
---

# Q001 -- Is gate G01 of M024 (the coordinator pipeline works against a real pull request host) met by the context-mcp field runs of 2026-11-14/15?

## Context

Source: gate G01 of M024 (`archive/2026-11-15/M024/M024-S02-PLAN.md`, line 28) and `STATE.md`
Purpose: decide whether G01 closes once a context-mcp lane went fully through `finish-lane`, which the maintainer agreed to wait for

Gate G01 (`archive/2026-11-15/M024/M024-S02-PLAN.md`, line 28): "The pipeline works against a real pull request host | decides: the operator | how: the first lane of a consumer project finished with it, receipt in that project | lapses: never". Evidence so far, all from context-mcp (meinKontext): a coordinator ran `coordinate` for days with dozens of subagent lanes and about 40 merged PRs on 2026-11-14 (issue #54); PR watch registration and delivery worked from 0.9.2 on (issue #61 comment); `review-lessons` turned a merged PR's finding into a reviewer checklist line; `ytstack-risk route` was adopted but routed every change to `person` until 0.11.0 read the round from the host. Not seen yet: a lane that went through `finish-lane` end to end with an `unattended` merge, and a receipt for it in that project.

## Options

- A) Met: coordinator mode, lanes, PR watch and review lessons ran against GitHub in a real project; close G01 and record the evidence.
- B) Not yet: keep G01 open until one lane goes through `finish-lane` with a host-sourced round (0.11.0) and leaves a receipt in context-mcp.
- C) Drop the gate: it never lapses and nothing waits on it.

## Recommendation

B. The part G01 was written for, the pipeline from a finished lane to a merge decision on the host, has not run end to end yet; 0.11.0 is the first version where it can. One lane in context-mcp settles it.

## Answer
