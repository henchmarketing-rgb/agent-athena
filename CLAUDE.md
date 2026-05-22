# CLAUDE.md — Athena Setup Guide Repository

This is the agent-athena repository. It contains workspace files, templates, scripts, and documentation for setting up a production multi-agent AI system on OpenClaw + Paperclip.

## Repository Structure

```
workspaces/
  athena/          — Command centre, coordinator (OpenClaw Discord agent)
  poseidon/        — Deep research, intelligence (OpenClaw Discord agent)
  icarus/          — Strategy, Paperclip CEO (OpenClaw Discord agent, has exec)
  forge/           — Dev, builds, deployments (OpenClaw Discord agent, has exec)
  argus/           — Monitoring, health, cost tracking (OpenClaw Discord agent)
  heracles/        — Night oversight, QC (OpenClaw Discord agent)
  recovery/        — Emergency failsafe (OpenClaw Discord agent, elevated exec)
  office/
    copywriter/    — Brand content (Paperclip heartbeat worker)
    outreach/      — Cold email, LinkedIn (Paperclip heartbeat worker)
    analytics/     — KPIs, reports (Paperclip heartbeat worker)
    seo/           — SEO audits, content briefs (Paperclip heartbeat worker)
    social/        — Social media (Paperclip heartbeat worker)
    ads/           — PPC, A/B variants (Paperclip heartbeat worker)
    visual-director/ — Art direction (Paperclip heartbeat worker)

templates/         — Blank templates for new workspaces
config/            — openclaw.json template, ecosystem.config.js, sites.example.json
scripts/           — Operational scripts (backup, cleanup, health, compaction, cost tracking)
prompts/           — Nightly agent prompt templates
docs/              — Detailed guides (auth, Paperclip API, MCP servers, onboarding, capabilities)
```

## Architecture

- **OpenClaw** = Discord gateway + agent runtime (chat, tools, memory, sessions)
- **Paperclip** = company orchestration (org chart, tasks, budgets, heartbeats, governance)
- **Icarus** bridges both: lives in OpenClaw with exec access, calls Paperclip API to create/assign tasks

## Task Pipeline

```
Operator → Athena (Discord) → Icarus (strategises + creates tasks via Paperclip API)
  → Office agents (execute via Paperclip heartbeats, output to project folders)
  → Icarus (monitors + synthesises) → Athena → Operator
```

## Key Files

- `install.sh` — one-script installer (deps, auth, Discord, credentials, workspace, gateway)
- `docs/ONBOARDING-PHASES.md` — full onboarding flow (bootstrap + 7 Discord-native phases)
- `docs/CLAUDE-AUTH-SETUP.md` — Claude OAuth/API key setup
- `docs/PAPERCLIP-API.md` — Paperclip heartbeat protocol, endpoints, org chart
- `docs/AGENT-CAPABILITIES.md` — what each agent can/cannot do
- `docs/MCP-SERVERS.md` — recommended MCP servers
- `config/openclaw-template.json` — full 7-agent OpenClaw config

## When Editing This Repo

- Agent names: Athena, Poseidon, Icarus, Forge, Argus, Heracles, Recovery (workspace agents) + Copywriter, Outreach, Analytics, SEO, Social, Ads, Visual Director (office agents)
- Use current agent names only (see team list above)
- Icarus has exec and is the Paperclip CEO — don't remove this
- Office agents are Paperclip heartbeat workers, NOT Discord agents
- Forge is dev only — NOT a Paperclip API bridge
- Secrets never go in markdown files — reference by name only
- All workspace agents need: SOUL.md, IDENTITY.md, AGENTS.md, MEMORY.md, CURRENT.md, HEARTBEAT.md, CLAUDE.md
- All office agents need: SOUL.md, IDENTITY.md, AGENTS.md, CLAUDE.md

## Git Conventions (strictly enforced)

1. **One intentional commit.** Main is always a single commit. All work on a feature branch; squash everything into one clean commit before merging to main. No multi-commit history, no dangling branches, no stale tags left behind after shipping.

2. **No Claude footprints in commits.** Do NOT append session URLs (claude.ai/code/...) to commit messages. Do NOT add Co-Authored-By trailers. Do NOT mention Claude, the model name, or Anthropic in commit messages, PR titles, PR bodies, or code comments. Commits must look like they were written by the operator.

3. **Clean wrap-up before any push to main.** Before merging: delete working branches, remove temporary tags, ensure CI is green, and verify the squash commit message is clear and intentional. The repo history should always look deliberate.
