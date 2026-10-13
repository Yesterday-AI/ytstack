---
name: spawn-milestone-team
description: "Explains the Agent Teams support boundary when parallel milestone execution is requested in Codex."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - spawn team
  - dispatch milestone
  - agent team
  - parallel slice execution
  - ytstack team
---

<!-- Generated from skills/spawn-milestone-team/SKILL.md by bin/build-codex. Do not edit. -->

**Codex:** Read [the host adapter](../../adapter.md) before following this skill.

# Milestone teams in Codex

This workflow requires Claude Code Agent Teams and its coordination hooks.
They are not provided by this Codex package.

## Checklist

1. Explain the limitation.
2. Offer sequential execution.

## Procedure

Stop before any capability probe or team spawn. Do not start another host.
Offer `plan-task` -> implementation -> `verification-before-completion`
-> `summarize-task` for each task instead.

## Terminal State

Return after explaining the supported workflow. Do not spawn agents or
invoke another skill unless the user requests it.
