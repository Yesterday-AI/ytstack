---
type: regex
pattern: '^- Round 1: [0-9a-f]{7,}\.\.[0-9a-f]{7,} -- [^\n]*\brisk: high\b'
flags: m
target: { source: file, path: .ytstack/M001-S01-PLAN.md }
---
