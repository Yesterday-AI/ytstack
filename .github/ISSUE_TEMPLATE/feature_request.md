---
name: Feature request / new skill
about: Propose a new skill, hook, or capability
title: "feat: <short description>"
labels: enhancement
assignees: ''
---

## The problem

<!-- ytstack rejects speculative features. "My agent might want X" is not a problem
statement. Point at the specific session or failure that motivated this. -->

## Proposed change

<!-- What skill / hook / behavior would solve it? -->

## Scope check

Confirm this fits ytstack's curation (see CONTRIBUTING.md "Philosophy"):

- [ ] It does not replicate a vendored superpowers / gstack skill.
- [ ] It is not domain-specific functionality (that belongs in a separate plugin that depends on ytstack).
- [ ] If it is a new skill, it needs `.ytstack/` state to make sense (otherwise it belongs in a sibling plugin).
- [ ] It preserves the UX contracts in `docs/ux/`.

## Alternatives considered

<!-- Existing skills you tried, why they did not fit, or a steering slash-command that almost worked. -->
