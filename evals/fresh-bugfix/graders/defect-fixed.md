---
type: regex
pattern: '^(?![ \t]*(?:el)?if\b[^\n]*-z[^\n]*since)[^\n]*\n(?![ \t]*#)(?![^\n]*-z[^\n]*since)[^\n]*\$\{?archived\b'
flags: m
target: { source: file, path: src/export.sh }
---
