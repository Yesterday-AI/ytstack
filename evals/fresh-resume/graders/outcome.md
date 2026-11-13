---
type: regex
pattern: 'archived\b(?:[^.\n]|\.(?=\S)){0,160}?(?<!\bnot\s)(?<!never\s)\b(?:excluded|omitted|skipped|dropped|left[\s*_]+out|filtered[\s*_]+out)\b|archived\b(?:[^.\n]|\.(?=\S)){0,160}?(?:\b(?:not|never|no[\s*_]+longer)|n\Wt)[\s*_]+(?:be\s+|a\s+)?(?:part|included|exported|in\s+the\s+export|printed|contained|present)\b|\b(?:exclud(?:es|ed|ing)|omit(?:s|ted|ting)|skip(?:s|ped|ping)|drop(?:s|ped|ping)|leav(?:es|ing)[\s*_]+out|filter(?:s|ed|ing)[\s*_]+out|without)[\s*_]+(?:the\s+|all\s+|any\s+)?archived\b|\bonly\b[^.\n]{0,60}?\b(?:non-?archived|not[\s*_]+archived|unarchived)\b'
flags: i
target: last_message
---
