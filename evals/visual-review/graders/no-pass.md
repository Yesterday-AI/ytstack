---
type: regex
pattern: '^- Lens ui: [^\n]* -- pass\b'
flags: m
match: not_contains
target: { source: file, path: .ytstack/M001-S01-PLAN.md }
---
