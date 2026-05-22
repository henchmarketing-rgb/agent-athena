# AGENT-ROSTER.md — Full Team

> Who exists, what they do, how to reach them. Read by all agents to know the team.

## Workspace Agents (OpenClaw)

| Agent | Emoji | Role | Channel | Has Exec | Model |
|-------|-------|------|---------|----------|-------|
| **Athena** | 🦉 | Command centre, coordinator | #🦉〡athena | No | claude-sonnet-4-6 |
| **Poseidon** | 🌊 | Deep research, intelligence | #🌊〡poseidon | No | claude-sonnet-4-6 (escalates to opus) |
| **Icarus** | ⚡ | Strategy, Paperclip CEO, task delegation | #⚡〡icarus | Yes (Paperclip API) | claude-sonnet-4-6 |
| **Forge** | 🔨 | Dev, builds, deployments | #🔨〡forge | Yes | claude-sonnet-4-6 |
| **Argus** | 👁️ | Monitoring, health, cost tracking | #👁️〡argus | No | claude-sonnet-4-6 |
| **Heracles** | 🛡️ | Night oversight, QC, accountability | #🛡️〡heracles | No | claude-sonnet-4-6 |
| **Recovery** | 🚨 | Emergency failsafe, incident response | #🚨〡recovery | Yes (elevated) | claude-sonnet-4-6 |

## Office Agents — Paperclip Task Queue Workers

Each has a full workspace at `workspaces/office/[name]/` with SOUL.md, IDENTITY.md, AGENTS.md, CLAUDE.md.

| Agent | Type | Emoji | What They Do |
|-------|------|-------|-------------|
| Copywriter | content | ✍️ | Blog posts, landing pages, email sequences |
| Outreach | outreach | 📧 | Cold email, LinkedIn, partnership outreach |
| Analytics | data | 📊 | Dashboards, reports, tracking setup |
| SEO | seo | 🔍 | Technical SEO, content optimisation, audits |
| Social | social | 📱 | Social media content, scheduling, engagement |
| Ads | advertising | 🎯 | PPC campaigns, Meta/Google ads management |
| Visual Director | design | 🎨 | Asset creation, brand guidelines, visual QA |

> **Dev work** is handled by **Forge** 🔨 (dedicated workspace agent), not an office agent.

## Routing Rules

### Workspace Agents (Discord channels)
- **Research needed?** → Poseidon 🌊 (#poseidon)
- **Strategy / brief the office?** → Icarus ⚡ (#icarus)
- **Code / builds / deployments?** → Forge 🔨 (#forge)
- **Health check / cost report?** → Argus 👁️ (#argus)
- **Something broken?** → Recovery 🚨 (#recovery)
- **Everything else** → Athena 🦉 decides and routes

### Office Agents (Paperclip task queue)
- **Blog posts, emails, landing pages?** → Copywriter ✍️
- **Cold email, LinkedIn, partnerships?** → Outreach 📧
- **Reports, dashboards, KPIs?** → Analytics 📊
- **Keyword research, SEO audits, meta copy?** → SEO 🔍
- **Social media posts, scheduling?** → Social 📱
- **PPC, A/B variants, ad copy?** → Ads 🎯
- **Asset specs, mood boards, brand QA?** → Visual Director 🎨

> Office agents don't receive tasks via Discord. Icarus (Paperclip CEO) creates tasks directly in the Paperclip API. Office agents wake via heartbeats and execute.
> **Operator → Athena → Icarus (strategises + creates tasks in Paperclip) → Office agents (execute via heartbeats) → Icarus (monitors + synthesises) → Athena → Operator**

## Task Pipeline Flow

```
Operator: "Brief the office on Q2 content"
  ↓
Athena posts to #icarus with context
  ↓
Icarus strategises → breaks into tasks:
  - Blog series → Copywriter
  - Social campaign → Social
  - SEO audit → SEO
  ↓
Icarus creates tasks directly in Paperclip API (has exec access)
  POST /api/companies/{companyId}/issues
  (one per office agent, with assigneeAgentId set)
  ↓
Paperclip wakes office agents via heartbeats
Office agents checkout tasks (atomic lock)
Office agents execute and output to project folders
Office agents update task status in Paperclip (files + paths visible in UI)
  ↓
Icarus monitors via Paperclip API
Icarus synthesises results into strategic deliverable
Posts to #icarus, tags Athena
  ↓
Athena reports back to operator in #athena
Operator approves → done
```

## Nightly Flow

1. Forge runs nightly dev tasks (one per project)
2. Heracles reviews Forge's output (scores: PASS / PARTIAL / FAIL)
3. Argus runs morning health check
4. Heracles posts morning summary to #athena
