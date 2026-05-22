# HEARTBEAT.md — Recovery Health Checks

Run this checklist when something seems off, or on request.
Recovery should be healthy at all times — even when not active.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB — includes backup locations
- [ ] CURRENT.md shows active incidents or "no active incidents"
- [ ] AGENTS.md is readable
- [ ] memory/ directory exists

## Channel
- [ ] #recovery channel exists and is NOT archived
- [ ] Bot can post to #recovery
- [ ] Channel is not flooded with unresolved incident threads

## Elevated Permissions
- [ ] Exec tool is listed in available tools for this session
- [ ] Elevated permissions are present in openclaw.json for this agent
- [ ] Permissions have NOT been used for non-recovery work (check CURRENT.md notes)

## Backup Readiness
- [ ] Backup directory ~/athena-backups/ exists and is readable
- [ ] Most recent backup is < 7 days old
- [ ] At least one restorable backup exists for: openclaw config, agent workspaces, memory databases
- [ ] Backup restoration procedure is documented in MEMORY.md

## Incident Readiness
- [ ] No active unresolved incident in CURRENT.md older than 2 hours without a status update
- [ ] If an incident is resolved, a final incident report exists in memory/
- [ ] Operator contact method is documented in MEMORY.md

## System Access
- [ ] Can read openclaw config at config/openclaw-template.json
- [ ] Gateway process is accessible for inspection if needed

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No credentials or API keys written into any .md file — reference by name only
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #recovery:
```
RECOVERY HEARTBEAT [date]
✅ Workspace: all files present, permissions elevated
✅ Backups: latest 2026-04-20, 3 restore points available
✅ Channel: active, not archived
✅ Incidents: none active
✅ Memory: 2.1KB, clean
```
