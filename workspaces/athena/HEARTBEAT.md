# HEARTBEAT.md — Athena Health Checks

Run this checklist when something seems off, or on request.

## Gateway
- [ ] `openclaw gateway status` → should return `running`
- [ ] Gateway process is not consuming excessive CPU/memory

## Agents
- [ ] All 7 agent workspaces exist: athena, poseidon, icarus, forge, argus, heracles, recovery
- [ ] Each workspace has: SOUL.md, IDENTITY.md, AGENTS.md, MEMORY.md, CURRENT.md, CLAUDE.md
- [ ] MEMORY.md for each agent is under 3KB
- [ ] Each workspace has OFFICE.md and AGENT-ROSTER.md

## Discord
- [ ] Bot is online and responding in #athena
- [ ] All 7 channels exist in server (#athena, #poseidon, #icarus, #forge, #argus, #heracles, #recovery)
- [ ] Pinned messages are present in each channel
- [ ] Channel IDs in openclaw.json match actual Discord channel IDs

## Paperclip
- [ ] `paperclipai status` or check port 3100 is listening
- [ ] All 7 office agents exist: Copywriter, Outreach, Analytics, SEO, Social, Ads, Visual Director
- [ ] Dev work routed to Forge (dedicated workspace agent, not an office agent)
- [ ] OFFICE.md contains valid agent IDs and company ID

## Crons
- [ ] argus-morning: 6:00am daily — check last run date
- [ ] argus-cost: Sunday 9:00am — check last run date
- [ ] weekly-compaction: Sunday 23:00 — check memory/archive/ for recent files
- [ ] secrets-check: Sunday 23:05 — check last output

## Memory
- [ ] memory/ directory exists in all workspaces
- [ ] memory/archive/ exists in all workspaces
- [ ] No daily files older than 90 days
- [ ] MEMORY.md < 3KB
- [ ] No exposed credentials in any .md file

## Scripts
- [ ] scripts/nightly-report.js runs without error
- [ ] scripts/gen-current.sh writes correct CURRENT.md
- [ ] scripts/secrets-check.js returns exit 0
- [ ] scripts/weekly-compaction.js runs without error

## Environment
- [ ] ~/.env.secrets exists and is chmod 600
- [ ] ANTHROPIC_API_KEY is set
- [ ] DISCORD_BOT_TOKEN is set
- [ ] BRAVE_SEARCH_API_KEY is set (optional)

## Recovery
- [ ] #recovery channel is not archived
- [ ] Recovery agent workspace exists and has correct SOUL.md
- [ ] Recovery agent has elevated tool permissions in openclaw.json

## Report Format

When running this as a task, post results to #athena:
```
HEARTBEAT [date]
✅ Gateway: running
✅ Agents: 7/7 workspaces healthy
✅ Discord: 7 channels, bot online
✅ Paperclip: running, 8 agents
⚠️ Memory: [agent] MEMORY.md at 2.9KB — compaction soon
✅ Crons: all on schedule
✅ Secrets: clean
```
