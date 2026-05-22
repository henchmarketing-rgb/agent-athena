# NIGHTLY-NOTES.md

> Cross-agent learning log. Every nightly agent reads this before starting and appends useful findings when done.
> Lives at: `~/.openclaw/workspace/NIGHTLY-NOTES.md`

## How This Works

- Nightly agents read this file at the start of every run
- If they discover something useful (a gotcha, a shortcut, a pattern), they append it here
- Every agent benefits from every other agent's discoveries
- Athena compacts this file weekly to prevent bloat

---

## Format

Each entry follows this structure:

```
### [DATE] — [AGENT NAME] — [PROJECT]
**Found:** [What was discovered]
**Impact:** [Why it matters for other agents]
**Action:** [What to do about it, if anything]
```

---

## Notes

[Entries are appended below by nightly agents]
