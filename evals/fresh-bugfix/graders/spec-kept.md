---
type: regex
pattern: '^(?![^\n]*DECISIONS)[^\n]*archived\s+rows\s+are\s+(?:always\s+)?(?:excluded|left\s+out|never\s+(?:exported|printed|part|included)|not\s+(?:exported|printed|part|included))(?![^.\n]*\b(?:unless|except)\b)'
flags: im
target: { source: file, path: .ytstack/spec/export.md }
---
