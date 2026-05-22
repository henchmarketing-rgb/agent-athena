# HEARTBEAT.md — Argus Health Checks

Run this checklist when something seems off, or on request.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB
- [ ] CURRENT.md shows latest health status, cost data, and active alerts
- [ ] AGENTS.md is readable
- [ ] memory/ directory exists

## Channel
- [ ] #argus channel exists in Discord server
- [ ] Bot can post to #argus
- [ ] Morning health report was posted to #athena today (check last run date)

## Scheduled Reports
- [ ] argus-morning cron: last run was today at or before 6:30am
- [ ] argus-cost cron: last run was this Sunday (or most recent Sunday)
- [ ] No scheduled run has been skipped without a logged reason

## Monitoring Scripts
- [ ] scripts/nightly-report.js runs without error
- [ ] scripts/cost-tracker.js runs without error and produces cost figures
- [ ] scripts/secrets-check.js exits 0 (no credentials exposed)
- [ ] Site uptime check: all monitored URLs returning 2xx

## Cost Tracking
- [ ] Weekly API cost is within expected range — no unexpected spikes
- [ ] Cost trend is flat or decreasing week-over-week (flag if rising)
- [ ] Cost data file in memory/ is current (updated within last 7 days)

## Alerting
- [ ] No CRITICAL alerts are sitting unacknowledged in CURRENT.md
- [ ] All WARNING alerts have a logged timestamp and responsible agent

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No credentials or API keys in any .md file
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #argus:
```
ARGUS HEARTBEAT [date]
✅ Morning report: posted 06:12am
✅ Cost cron: last run Sunday — within budget
✅ Sites: all 2xx
✅ Scripts: nightly-report OK, cost-tracker OK, secrets-check OK
⚠️ Cost trend: +12% WoW — flagging for review
```
