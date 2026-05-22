# AGENT-CAPABILITIES.md

What each agent type can and cannot do.
Use this as a reference when writing SOUL.md files or assigning tasks.

---

## Athena (Command Centre / Coordinator)

The main interface agent. Talks to the operator, routes work to other agents.

**Can do:**
- ✅ Fetch external URLs (NOT localhost/127.0.0.1)
- ✅ Read/write workspace files
- ✅ Send Discord messages to any channel
- ✅ Route briefs to Icarus, research to Poseidon, tasks to Forge
- ✅ Web search (if Brave Search API configured)
- ✅ Reason, plan, write long-form content

**Cannot do:**
- ❌ exec / shell commands
- ❌ Access localhost or 127.0.0.1 (web_fetch blocks private hostnames)
- ❌ Direct Paperclip API calls (routes through Icarus)
- ❌ Deploy code
- ❌ Run builds or tests

**Important:** Never assert capabilities Athena doesn't have in her SOUL.md.
If SOUL.md claims Athena can do something she can't, she'll hallucinate attempts and fail silently.

---

## Icarus (Strategy / Paperclip CEO)

The strategy agent and Paperclip CEO. Breaks briefs into tasks, creates them in Paperclip, assigns to office agents, monitors, synthesises.

**Can do:**
- ✅ exec / shell commands (for Paperclip API calls via curl)
- ✅ Create Paperclip tasks via `POST /api/companies/{id}/issues`
- ✅ Assign tasks to office agents by agentId
- ✅ Monitor task status via Paperclip API
- ✅ Read/write workspace files
- ✅ Web search
- ✅ Strategy, roadmaps, decision frameworks

**Cannot do:**
- ❌ Run builds, deploy code (that's Forge)
- ❌ Execute the actual task work (delegates to office agents)

---

## Forge (Dev / Executor Agent)

The hands-on dev agent. Writes code, runs builds, deploys, ships.

**Can do:**
- ✅ exec / shell commands
- ✅ Read/write files anywhere on the filesystem
- ✅ Run builds and tests
- ✅ Make API calls (including localhost)
- ✅ Deploy via Vercel/GitHub/etc
- ✅ Push git branches

**Cannot do:**
- ❌ Autonomous decisions about scope without a brief
- ❌ Multi-project work in a single session (context leakage)

---

## Poseidon (Research / Intelligence)

Deep research agent. Evidence-driven, confidence-rated.

**Can do:**
- ✅ Web search, web_fetch (external URLs)
- ✅ Read/write workspace files
- ✅ Long-form analysis, competitor research, market intelligence

**Cannot do:**
- ❌ exec / shell commands
- ❌ Access localhost (web_fetch blocks private hostnames)

---

## Argus (Monitoring / Health)

Watchman. Reads health checks, escalates real problems.

**Can do:**
- ✅ Read workspace files, daily memory, session logs
- ✅ Web fetch (for site-health checks)
- ✅ Send Discord messages, escalate to #recovery on CRITICAL
- ✅ Read cost data from `scripts/cost-tracker.js` output

**Cannot do:**
- ❌ exec / shell commands
- ❌ Modify production code or configs
- ❌ Trigger Recovery directly (operator escalates)

---

## Heracles (Night Oversight / QC)

Reviews nightly agent runs. Posts a morning quality summary.

**Can do:**
- ✅ Read all nightly agent reports
- ✅ Score each run as PASS / PARTIAL / FAIL
- ✅ Post morning summary to #athena
- ✅ Mark missing reports as automatic FAIL

**Cannot do:**
- ❌ exec / shell commands
- ❌ Modify the work being reviewed
- ❌ Override another agent's verdict on its own task

---

## Recovery (Emergency Failsafe)

Last-resort agent with elevated permissions. Only activated by the operator.

**Can do:**
- ✅ exec / shell commands (full)
- ✅ Read/write any file on the host
- ✅ Restart gateway, kill processes, roll back deployments

**Cannot do:**
- ❌ Activate itself; only the operator triggers Recovery
- ❌ Make architectural changes beyond the immediate fix

> ⚠️ **Access control.** Recovery is documented as activated by `@Recovery` mention. **Anyone with send access to your Discord can trigger it.** If your server is not single-operator, gate Recovery behind a Discord role check before going live. See [SECURITY.md](../SECURITY.md).

---

## Office Agents (Paperclip Heartbeat Workers)

Backend task agents: Copywriter, Outreach, Analytics, SEO, Social, Ads, Visual Director.

**How they work:**
- Registered in Paperclip with `adapterConfig` pointing to their workspace
- Wake via Paperclip heartbeats when tasks are assigned
- Follow the heartbeat protocol: checkout → execute → output to project folder → update task status
- Output is visible in Paperclip UI (file paths + deliverables)
- Do NOT live in Discord, they are Paperclip-only backend workers

**adapterConfig:**
```json
{
  "cwd": "~/.openclaw/workspaces/office/[agent-name]",
  "model": "claude-sonnet-4-6",
  "dangerouslySkipPermissions": false,
  "maxTurnsPerRun": 20,
  "timeoutSec": 300
}
```

> ⚠️ **Security:** Default is `false`. Setting `true` disables permission prompts and turns prompt injection in agent input into shell execution. See [SECURITY.md](../SECURITY.md) before flipping.

**Agent model = task type, NOT per-project:**
- ✅ Copywriter, SEO, Social, Ads, Outreach, Analytics, Visual Director
- ❌ MonitorTheSit-Writer, ProjectAlpha-SEO (defeats reusability)

---

## Nightly Agent

Autonomous improvement agent. Runs on a cron schedule, no human in the loop.

**Must have in its prompt:**
- `Do not spawn subagents, do all work inline`
- `STOP after committing and pushing. Do not continue.`
- Error channel ID for failure alerts
- NIGHTLY-NOTES.md path for cross-agent learning

**Must NOT:**
- Touch main branch directly
- Auto-merge PRs
- Make scope decisions beyond the current TASK-QUEUE.md entry
- Continue inventing work after the task is done

---

## Multi-Agent Routing (One Gateway, Many Agents)

OpenClaw supports multiple isolated agents from a single gateway process. Each agent has:
- Its own workspace (files, SOUL.md, MEMORY.md, etc.)
- Its own session store (`~/.openclaw/agents/<agentId>/sessions`)
- Its own auth profiles

Configure in `openclaw.json`:
```json5
{
  agents: {
    list: [
      { id: "athena", workspace: "~/.openclaw/workspaces/athena" },
      { id: "poseidon", workspace: "~/.openclaw/workspaces/poseidon" },
      { id: "icarus", workspace: "~/.openclaw/workspaces/icarus" },
      { id: "forge", workspace: "~/.openclaw/workspaces/forge" }
    ]
  },
  bindings: [
    { agentId: "athena", match: { channel: "discord", peer: { kind: "channel", id: "ATHENA_CHANNEL_ID" } } },
    { agentId: "icarus", match: { channel: "discord", peer: { kind: "channel", id: "ICARUS_CHANNEL_ID" } } }
  ]
}
```

Each channel routes to a specific agent. Agents are fully isolated, separate memory, sessions, and tools.
