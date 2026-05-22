# HEARTBEAT.md — Icarus Health Checks

Run this checklist when something seems off, or on request.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB
- [ ] CURRENT.md shows active strategic work and task tracking
- [ ] AGENTS.md is readable (contains Paperclip routing table)
- [ ] OFFICE.md is readable and contains valid agent IDs and company ID
- [ ] memory/ directory exists

## Channel
- [ ] #icarus channel exists in Discord server
- [ ] Bot can post to #icarus
- [ ] Last message in #icarus is within expected timeframe

## Paperclip API
- [ ] `PAPERCLIP_API_URL` env var is set
- [ ] `PAPERCLIP_API_KEY` env var is set
- [ ] `COMPANY_ID` env var is set
- [ ] API health check: `curl $PAPERCLIP_API_URL/health` returns 200
- [ ] Can list company tasks: `GET /api/companies/$COMPANY_ID/issues` returns valid JSON
- [ ] All 7 office agents exist in Paperclip (Copywriter, Outreach, Analytics, SEO, Social, Ads, Visual Director)

## Task Pipeline
- [ ] CURRENT.md has no task stuck "in_progress" in Paperclip for > 24 hours without a status update
- [ ] No tasks assigned to non-existent agent IDs
- [ ] Paperclip port 3100 is listening: `lsof -i :3100` shows a process

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No API keys or tokens written into any .md file
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #icarus:
```
ICARUS HEARTBEAT [date]
✅ Workspace: all files present
✅ Paperclip: running, 7 office agents confirmed
✅ API: POST /issues OK
✅ Memory: 1.8KB, clean
⚠️ Task #42: stuck in_progress for 30h — needs follow-up
```
