---
type: regex
pattern: 'G02[\s\S]{0,400}?\blapsed\b|\blapsed\b[\s\S]{0,200}?G02'
flags: i
target: last_message
---
