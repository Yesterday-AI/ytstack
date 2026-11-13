---
type: regex
pattern: 'since[^\n]*(?:\n[^\n]*)?archiv|archiv[^\n]*(?:\n[^\n]*)?since'
flags: i
target: { source: file, path: tests/run.sh }
---
