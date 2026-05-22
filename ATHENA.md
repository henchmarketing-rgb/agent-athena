# Athena: Project Overview

## What Is Athena?

Athena is a production multi-agent AI system built on OpenClaw + Paperclip.

It's named after the Greek goddess of wisdom and craft, not just thinking, but making. That's exactly what this system does: it thinks and builds, around the clock.

## The System

### Agent Team: 14 named agents

**7 workspace agents** (live in Discord, one channel each):
- **Athena**: command centre, primary interface, team coordinator
- **Poseidon**: deep research, intelligence, long-form analysis
- **Icarus**: strategy, roadmaps, positioning, decision frameworks
- **Forge**: dedicated dev agent for project builds and deployments
- **Argus**: monitoring, morning reports, cost tracking, alerting
- **Heracles**: night shift overseer, quality control, agent accountability
- **Recovery**: emergency failsafe, elevated permissions

**7 office agents** (run as Paperclip heartbeat workers, no Discord channel):
- **Copywriter**: brand content, long-form, voice
- **Outreach**: cold email, LinkedIn, sequences
- **Analytics**: KPI reports, dashboards, metrics
- **SEO**: audits, content briefs, technical SEO
- **Social**: social media posts, scheduling, engagement
- **Ads**: PPC, A/B variants, campaign management
- **Visual Director**: art direction, brand visual rules

### Core Infrastructure
- **Paperclip**: task queue: backlog → in_progress → in_review → done
- **AGENT-BRIEF.md**: per-project nightly agent instructions
- **GOTCHAS.md**: known failure patterns, shared across agents
- **NIGHTLY-NOTES.md**: cross-agent learning log
- **Daily memory files**: `memory/YYYY-MM-DD.md` per day
- **Weekly compaction**: daily logs → weekly summaries → long-term MEMORY.md

### Nightly System
Each project has a nightly agent that:
1. Reads GOTCHAS.md before touching anything
2. Creates a dated branch (`nightly/YYYY-MM-DD`)
3. Works the task from AGENT-BRIEF.md
4. Runs a build check, must pass before commit
5. Posts a report to Heracles in Discord
6. Heracles quality-scores each report and posts morning summary to #athena

### Self-Improving Skills System
Agents improve through a weekly review cycle:

1. `scripts/skill-review.js` runs every Sunday, scans all workspaces for `GOTCHAS.md`, `NIGHTLY-NOTES.md`, and recent daily memory files
2. Compiles findings into `SKILL-REVIEW.md` in Athena's workspace
3. Athena reads `SKILL-REVIEW.md` and updates agent `SOUL.md` / `AGENTS.md` files with new rules based on real production failures

This is learned behaviour, not scheduled updates. Agents get better from what actually broke.

## Roadmap

- [x] Cloud deployment guide (CLOUD-DEPLOY.md)
- [x] Per-agent cost tracking (scripts/cost-tracker.js)
- [x] Self-improving skills (scripts/skill-review.js → SKILL-REVIEW.md)
- [x] Memory compaction (scripts/weekly-compaction.js)
- [x] Auto GitHub backup (scripts/full-backup.sh)
- [ ] Cloud gateway, always-on server deployment
- [ ] Real-time alerting (UptimeRobot or equivalent)
- [ ] Paperclip auto-reconnect on session expiry

## Branding

- Name: **Athena**
- Emoji: 🦉
- Taglines: *"wisdom and craft"* | *"builds while you sleep"*
- GitHub: `your-github-username/agent-athena`
