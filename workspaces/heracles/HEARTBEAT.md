# HEARTBEAT.md — Heracles Health Checks

Run this checklist when something seems off, or on request.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB
- [ ] CURRENT.md shows active oversight tasks and any recurring failure patterns
- [ ] AGENTS.md is readable
- [ ] GOTCHAS.md exists (recurring nightly failure patterns)
- [ ] memory/ directory exists

## Channel
- [ ] #heracles channel exists in Discord server
- [ ] Bot can post to #heracles
- [ ] Morning summary was posted to #athena today at or before 7am

## Nightly QC Coverage
- [ ] All expected nightly agent reports exist for last night (Forge, office agents)
- [ ] Any missing report is already flagged as FAIL in CURRENT.md
- [ ] Every report reviewed has a score: PASS, PARTIAL, or FAIL
- [ ] No report scored PASS without evidence cited in the review

## Scoring Integrity
- [ ] CURRENT.md contains the score log from the most recent nightly run
- [ ] FAIL and PARTIAL scores include: what failed, why, and what should happen next
- [ ] Recurring failures (2+ nights) are recorded in GOTCHAS.md

## Morning Summary
- [ ] Morning summary posted to #athena includes: what shipped, what failed, what needs human attention
- [ ] Operator was tagged if any item requires human intervention
- [ ] Summary does not reference or assign fixes — review and report only

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No credentials or API keys in any .md file
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #heracles:
```
HERACLES HEARTBEAT [date]
✅ Morning summary: posted 06:58am
✅ Reports reviewed: 4/4 agents reported
✅ Scores: 3x PASS, 1x PARTIAL (Forge — build warnings)
✅ GOTCHAS.md: up to date
⚠️ Forge: 2nd night with linting warnings — added to GOTCHAS.md
```
