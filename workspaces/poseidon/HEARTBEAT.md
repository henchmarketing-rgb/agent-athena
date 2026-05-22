# HEARTBEAT.md — Poseidon Health Checks

Run this checklist when something seems off, or on request.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB
- [ ] CURRENT.md reflects active or recently completed research jobs
- [ ] AGENTS.md is readable
- [ ] memory/ directory exists
- [ ] memory/archive/ directory exists

## Channel
- [ ] #poseidon channel exists in Discord server
- [ ] Bot can post to #poseidon
- [ ] Last message in #poseidon is within expected timeframe

## Research Tools
- [ ] web_search is available and returning results (test with a simple query)
- [ ] web_fetch is functional (test with a known-good URL)
- [ ] No tool returning auth errors or rate limit blocks

## Research Quality Gates
- [ ] CURRENT.md has no research job stuck "in_progress" for > 48 hours
- [ ] No active dossier files are > 30 days stale without a completion marker
- [ ] All research outputs include confidence levels [HIGH] [MEDIUM] [LOW] [UNVERIFIED]

## Model Access
- [ ] claude-sonnet-4-6 is responding normally
- [ ] claude-opus-4-6 escalation path available for complex jobs

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No exposed credentials or API keys in any .md file
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #poseidon:
```
POSEIDON HEARTBEAT [date]
✅ Workspace: all files present
✅ Channel: online, posting OK
✅ Web search: functional
✅ Memory: 1.2KB, clean
⚠️ CURRENT.md: 1 job stale (> 48h) — needs review
```
