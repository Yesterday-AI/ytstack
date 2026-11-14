---
type: regex
pattern: '^- Round 1: [^\n]*\binvariants: (?!none\b)[^\n]*archiv'
flags: im
target: { source: file, path: .ytstack/M001-S01-PLAN.md }
---
