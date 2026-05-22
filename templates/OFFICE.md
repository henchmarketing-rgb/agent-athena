# OFFICE.md — Team Structure & IDs

> This file contains Paperclip IDs, team structure, and standard operating procedures.
> Every agent reads this on session start to know the team layout and how to route tasks.

## Paperclip

- **Company ID:** [SET DURING ONBOARDING — get from `curl http://127.0.0.1:3100/api/companies | jq '.[0].id'`]
- **API Base:** http://127.0.0.1:3100/api

## Office Agents (Paperclip Task Queue Workers)

Each office agent has a full workspace at `workspaces/office/[name]/` with SOUL.md, IDENTITY.md, AGENTS.md, and CLAUDE.md.

| Agent | Paperclip ID | Type | Workspace | Emoji |
|-------|-------------|------|-----------|-------|
| Copywriter | [ID] | content | `workspaces/office/copywriter/` | ✍️ |
| Outreach | [ID] | outreach | `workspaces/office/outreach/` | 📧 |
| Analytics | [ID] | data | `workspaces/office/analytics/` | 📊 |
| SEO | [ID] | seo | `workspaces/office/seo/` | 🔍 |
| Social | [ID] | social | `workspaces/office/social/` | 📱 |
| Ads | [ID] | advertising | `workspaces/office/ads/` | 🎯 |
| Visual Director | [ID] | design | `workspaces/office/visual-director/` | 🎨 |

> **Note:** Dev work is handled by **Forge** 🔨 (dedicated workspace agent at `workspaces/forge/`), not an office agent.

**Paperclip adapterConfig for each worker:**
```json
{
  "cwd": "~/.openclaw/workspaces/office/[agent-name]",
  "model": "claude-sonnet-4-6",
  "dangerouslySkipPermissions": false,
  "maxTurnsPerRun": 20,
  "timeoutSec": 300
}
```

> ⚠️ **Security:** `dangerouslySkipPermissions: false` is the safe default. Setting it to `true` disables Claude Code's permission prompts, which means a prompt injection in any external content (Discord message, web page, Paperclip task description) can result in shell execution. Only enable per-agent for agents you've fully scoped. See [SECURITY.md](../SECURITY.md).

## Discord Channels

| Channel | Purpose |
|---------|---------|
| #🦉〡athena | Command centre, daily comms, morning summaries |
| #🌊〡poseidon | Research briefings and intelligence |
| #⚡〡icarus | Strategy, roadmaps, decision frameworks |
| #🔨〡forge | Dev reports, build status, deployment logs |
| #👁️〡argus | Health reports, cost summaries, alerts |
| #🛡️〡heracles | Nightly QC scores, morning oversight reports |
| #🚨〡recovery | Emergency incidents only |
| #errors | Nightly agent error reports (auto-posted) |
| #nightly | Nightly agent completion reports |

## SOPs

- **Task routing:** Athena assigns tasks via Paperclip. Use agent type to match.
- **Nightly branches:** Always `nightly/YYYY-MM-DD`. Never push to main.
- **Escalation:** Agent → Athena → Operator. Skip to operator for CRITICAL alerts.
- **Compaction:** Weekly on Sunday. Athena owns this.
