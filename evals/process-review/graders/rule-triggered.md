---
type: regex
pattern: '"id": "merged-without-review",[\s\S]{0,1200}?"state": "triggered"'
target: { source: file, path: process-data/metrics.json }
---
