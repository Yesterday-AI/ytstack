---
name: using-ytstack
description: "Establishes how agents find and invoke ytstack skills. Load at session start or before selecting a workflow. The SessionStart hook supplies it when trusted; it can also be loaded explicitly."
tier: core
version: 0.2.1
kind: directive
user-invocable: false
---

<!-- Generated from skills/using-ytstack/SKILL.md by bin/build-codex. Do not edit. -->

**Codex:** Read [the host adapter](../../adapter.md) before following this skill.

# Using ytstack

<EXTREMELY-IMPORTANT>
This project uses ytstack. Load project state and skills as described in the Codex adapter. Trusted SessionStart hooks supply state automatically.

If you think there is even a 1% chance a ytstack skill applies to what the user asked, you ABSOLUTELY MUST load the skill using the Codex adapter BEFORE any other action.

IF A YTSTACK SKILL APPLIES, YOU DO NOT HAVE A CHOICE. USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction priority

User instructions always take precedence:

1. **User's explicit instructions** (`AGENTS.md`, direct messages) -- highest priority. If the user says "skip ytstack for this change", honor it.
2. **ytstack skills** -- override default agent behavior when they apply.
3. **Default agent behavior** -- lowest priority.

## The rule

**Invoke the relevant ytstack skill BEFORE any response or action.** Each skill's frontmatter `description` field states when to use it. Match the user's intent against the descriptions semantically -- not against keyword lists or canonical phrasings. If any skill's description plausibly covers the situation, load it using the Codex adapter to confirm. If the invoked skill turns out to be the wrong fit, that is fine; what is NOT fine is skipping the check.

Skills you might need (consult each skill's description, not this list, for the actual when-to-use):

- Project lifecycle: `init-project`, `plan-milestone`, `slice-milestone`, `plan-task`, `summarize-task`, `reassess-roadmap`
- Session continuity: `handoff-session`, `resume-session`
- Planning reviews: `office-hours`, `plan-ceo-review`, `plan-eng-review`
- Execution discipline: `test-driven-development`, `systematic-debugging`, `verification-before-completion`
- Parallel milestone execution: `spawn-milestone-team` explains the unsupported capability and sequential alternative.

The selection mechanism is **semantic, not phrase-based**. New user phrasings (different language, paraphrase, domain-specific vocabulary) should still trigger the right skill as long as the intent is covered by a description.

## Skill priority (when multiple could apply)

1. **Process skills first** (office-hours, plan-ceo-review, systematic-debugging). They determine whether / how to proceed.
2. **Structural skills next** (plan-milestone, slice-milestone, plan-task). They determine what to build.
3. **Execution skills last** (TDD, verification). They determine how to build.

"Let's build X" (greenfield, no pitch yet) -> `office-hours` first. "Fix this bug" -> `systematic-debugging` first.

## Red flags -- stop and invoke

These thoughts mean STOP, you're rationalizing:

| Thought | Reality |
|---|---|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I already know what they want" | Invoke the skill to be sure. |
| "Skills are overkill for this" | ytstack's skills handle simple cases fast. Use them. |
| "I'll just fix it directly" | Direct fixes bypass verification + scope checks. Use the skills. |
| "The plan is obvious" | Plans feel obvious until you write them down. Use `plan-task`. |
| "Let me read the files first" | Skills tell you which files to read. Check first. |
| "I'll figure it out as I go" | ytstack exists because "figure it out" loses context across sessions. |

## Process flow (what happens on every user message)

```dot
digraph using_ytstack {
    "User message received" [shape=doublecircle];
    "Match intent against skill descriptions" [shape=box];
    "Any skill plausibly applies?" [shape=diamond];
    "Load selected skill" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond directly" [shape=doublecircle];

    "User message received" -> "Match intent against skill descriptions";
    "Match intent against skill descriptions" -> "Any skill plausibly applies?";
    "Any skill plausibly applies?" -> "Load selected skill" [label="yes, even 1%"];
    "Any skill plausibly applies?" -> "Respond directly" [label="definitely not"];
    "Load selected skill" -> "Follow skill exactly";
    "Follow skill exactly" -> "Respond directly";
}
```

## After invoking a skill

Follow its Checklist exactly. Track each item with the available plan tool or a checklist in the conversation. Don't improvise steps. The skill's Terminal State section tells you what to do next -- respect it; don't auto-invoke the suggested follow-up skill unless the user explicitly asks for it.

## Reporting ytstack issues

If a ytstack skill, hook, or artifact misbehaves (the wrong skill fires, a hook errors, an artifact gets mangled), surface it to the human and suggest filing an issue at https://github.com/Yesterday-AI/ytstack/issues. Do not silently work around a ytstack bug -- a one-line report keeps the stack sharp.

## Summary

ytstack is active. Each skill's `description` field is the source of truth for when to invoke it. Match semantically, invoke proactively, follow the skill's checklist exactly, never auto-chain.
