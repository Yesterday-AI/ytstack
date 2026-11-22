---
runs: 1
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Bash, Write, Edit]
append_system_prompt: "Headless evaluation run, no human available and no GitHub access. When a skill says to ask the user (AskUserQuestion), do not ask: take the option the skill names for a non-interactive run, or infer the answer from the prompt, then continue. End with one line listing the files you wrote."
expected_outcome: >-
  The process-review skill fires. It does not mine (the data is there and there is no GitHub access), runs tools/process-review/analyze.mjs on ./process-data, writes the change of 8 March with its expectation (unreviewed merges down) into process-data/config.json, analyses again and renders process-data/report.html. metrics.json holds the expectation as confirmed and the rule merged-without-review as triggered; the reply gives shares with their denominators and says that nobody of the measured team has read the findings yet.
---

How is our pull request and review process doing? The data for acme/shop from 1 to 21 March 2026 is already mined into ./process-data, and this machine cannot reach GitHub, so work with what is there. One thing I really want to know: on 8 March we started to require a review on every pull request, because too much went in unreviewed. That was supposed to bring the unreviewed merges down. Did it? Put the HTML report next to the data in ./process-data.
