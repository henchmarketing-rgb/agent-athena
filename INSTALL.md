# Manual Install Guide
### Step-by-step setup for operators who don't want to run `install.sh`
*Companion to the README. Read this if you want to understand or customise every step.*

> **Most users should run `bash install.sh` instead.** That script handles everything in this guide automatically and is idempotent (re-running resumes from the last successful step). Use this manual path only if you want to do it yourself or are debugging an install failure.

---

## Fastest Path

```bash
git clone https://github.com/henchmarketing-rgb/agent-athena.git
cd agent-athena
bash install.sh
```

The install script handles everything below automatically. After it completes, Athena walks you through the rest in Discord. See [docs/ONBOARDING-PHASES.md](docs/ONBOARDING-PHASES.md) for the full flow.

If you prefer manual setup, continue with this guide.

---

## Pre-Flight Checklist

Complete these before touching any configuration.

- [ ] Decide your runtime: **OpenClaw** (default, multi-channel) or **Hermes Agent** (single-profile self-improving). See [docs/RUNTIME-ADAPTERS.md](docs/RUNTIME-ADAPTERS.md) for the comparison
- [ ] Claude auth ready, setup-token (`claude auth login && claude setup-token`) or API key from [console.anthropic.com](https://console.anthropic.com). For Hermes, an OpenRouter key works as a single-key alternative
- [ ] Discord bot created, added to server with correct permissions + intents
- [ ] Discord server ID + #athena channel ID copied
- [ ] All required accounts created (GitHub, Brave Search, optionally Vercel/Supabase)
- [ ] ID Capture Sheet prepared (see below), fill in as you go
- [ ] Node.js ≥ 20, pm2, and git installed
- [ ] For Hermes runtime: Python 3.11+ and `uv` (the Hermes setup script will install if missing)
- [ ] `gh` CLI installed and authenticated (`gh auth login`)
- [ ] Shell profile editable (~/.zshrc, ~/.bashrc, or equivalent)

## Choosing your runtime

The install script asks at Step 7 which runtime you want. Both are first-class — the workspace `.md` files (the actual Athena product) work identically on either.

| | OpenClaw (default) | Hermes Agent |
|---|---|---|
| Stack | Node.js | Python |
| Discord topology | One bot, 14 channels, persona-per-channel | One bot, one active persona, Athena fronts |
| Other personas | Live in their channels | Loaded as skills, dispatched via cron + Paperclip |
| Self-improving | No | Yes (Hermes generates new skills from experience) |
| Install | `npm install -g openclaw` | `git clone` + `bash setup-hermes.sh` |
| Home dir | `~/.openclaw/` | `~/.hermes/` |

Pick OpenClaw for the live multi-agent Discord experience. Pick Hermes for autonomous single-channel orchestration backed by the wider Hermes plugin/skill ecosystem. See [docs/RUNTIME-ADAPTERS.md](docs/RUNTIME-ADAPTERS.md) for the deep dive.

---

## ID Capture Sheet

**Fill this in as each credential is generated. Never proceed past a step without recording its IDs here first.**

```
=== OPENCLAW ID CAPTURE SHEET ===
Generated: [DATE]
Operator:  [NAME]

--- EXTERNAL SERVICES ---
Discord Bot Token:          ___________________________________
Discord Guild (Server) ID:  ___________________________________

Discord Channel IDs:
  #🦉〡athena:              ___________________________________
  #🌊〡poseidon:            ___________________________________
  #⚡〡icarus:               ___________________________________
  #🔨〡forge:                ___________________________________
  #👁️〡argus:                ___________________________________
  #🛡️〡heracles:             ___________________________________
  #🚨〡recovery:             ___________________________________
Anthropic API Key:          ___________________________________
Vercel Token:               ___________________________________
GitHub Username:            ___________________________________

--- PAPERCLIP ---
Paperclip Company ID:       ___________________________________

Agent IDs:
  Dev:          ___________________________________
  Copywriter:   ___________________________________
  SEO:          ___________________________________
  Social:       ___________________________________
  Marketing:    ___________________________________
  Ads:          ___________________________________
  Outreach:     ___________________________________
  Analytics:    ___________________________________

--- OPENCLAW ---
OPENCLAW_TOKEN:             ___________________________________

--- CRON IDs ---
  full-backup:              ___________________________________
  session-cleanup:          ___________________________________
  site-health:              ___________________________________
  weekly-compaction:        ___________________________________
  [project]-nightly:        ___________________________________

--- PM2 ---
Process name: paperclip | Port: 3100
```

---

## Step 1: Identity Files

Create these in your agent's workspace directory before anything else. They load on every session.

### `SOUL.md`: Personality
```markdown
# SOUL.md

You're [NAME]. Not a chatbot. A right-hand.

## Core
- Be genuinely helpful, not performatively helpful.
- Have opinions. Disagree when you're right.
- Be resourceful before asking. Figure it out first.

## Vibe
[Describe tone: direct, casual, funny, serious — be specific]
```

### `IDENTITY.md`
```markdown
# IDENTITY.md
- **Name:** [Your AI's name]
- **Role:** Personal AI assistant to [operator name]
- **Emoji:** [Pick one]
- **Platform:** Primarily Discord
```

### `USER.md`
```markdown
# USER.md
- **Name:** [Full name]
- **Goes by:** [Preferred name]
- **Discord ID:** [ID]
- **Timezone:** GMT+[X]
- **Style:** [How they communicate]

## What they're working on
[Active projects]
```

### `MEMORY.md`
```markdown
# MEMORY.md — Hard Facts Only

## People
- [Name] = [Who] | Discord: [handle] | Timezone: GMT+[X]

## Accounts
- GitHub: [username]
- Vercel: [project]

## Discord Channels
- [emoji]〡[name]: [channel ID]

## [Project Name]
- Repo: [org/repo]
- Live: [URL]

## Silent Replies
When you have nothing to say, respond with ONLY: NO_REPLY
```

⚠️ **Never put API keys, passwords, or tokens in MEMORY.md.** They end up in LLM context windows. Use `~/.env.secrets` instead (see Secrets section).

### `AGENTS.md`
```markdown
# AGENTS.md

## Every Session
Read before anything else:
1. `CURRENT.md` — live project state
2. `memory/YYYY-MM-DD.md` (today + yesterday)
3. `OFFICE.md` — your role and SOPs
4. `AGENT-ROSTER.md` — full team

## Memory
- Daily logs → memory/YYYY-MM-DD.md
- Long-term → MEMORY.md
- When told "remember this" → write it immediately

## Secrets hygiene
- NEVER write API keys, JWTs, service role keys, or passwords into markdown files.
- Store secrets in ~/.env.secrets or macOS Keychain.
- Reference secrets by name only: "Supabase service role → ~/.env.secrets (SUPABASE_SERVICE_ROLE_KEY)"
- Run scripts/secrets-check.js periodically to scan for exposed credentials.

## Safety
- No destructive commands without asking
- No installing software without explicit permission
- Confirm before anything that leaves the machine
```

### `HEARTBEAT.md`
```markdown
# HEARTBEAT.md

## Checks (silent, only report problems)
1. Cron health — flag consecutiveErrors > 0
2. Session sizes — flag any session file > 50MB
3. CURRENT.md freshness — flag if > 48 hours old
4. MEMORY.md size — warn if > 3000 bytes
5. Nightly outcome health — run nightly-report.js. Flag <50% success rate.
6. Site health — run site-health.js. Flag any failing sites.
7. Backup recency — flag if no backup in 48 hours.
8. Session bloat — run session-cleanup.js. Flag if >10 orphaned sessions.
9. Secrets exposure — run secrets-check.js. Flag any credentials found in workspace files.
10. Weekly compaction — flag if no summary in last 10 days.
11. Nightly notes activity — check NIGHTLY-NOTES.md. Flag if no entries in last 7 days.

If all pass: reply HEARTBEAT_OK
If anything fails: report and fix if safe.
```

### `NIGHTLY-NOTES.md`
```markdown
# NIGHTLY-NOTES.md — Cross-Agent Shared Memory

Every nightly agent reads this before starting.
If you discover something useful for other projects — append it here.

## [YYYY-MM-DD] [Agent: project-name]
- What I found: [brief description]
- Relevant to: [other projects or "all"]
- Why it matters: [one sentence]
```

---

## Step 2: Secrets Management

### The rule
**Never put credentials in markdown files.** They get read into LLM context and sent to API providers. Even private repos are not safe, anything in a file that loads into context is exposed.

### `~/.env.secrets`: local secrets store

```bash
cat > ~/.env.secrets << 'EOF'
# Agent secrets — never committed to git
SUPABASE_SERVICE_ROLE_KEY=your-key-here
YOUR_APP_PASSWORD=your-password-here
YOUR_API_KEY=your-api-key-here
EOF
chmod 600 ~/.env.secrets
```

### Reference by name in markdown

```markdown
# MEMORY.md
- Supabase service role → ~/.env.secrets (SUPABASE_SERVICE_ROLE_KEY)
- App owner password → ~/.env.secrets (YOUR_APP_PASSWORD)
```

### `.gitignore`: protect sensitive files

```gitignore
# Secrets
.env
.env.*
*.env
~/.env.secrets
CREDENTIALS.md
**/credentials.md
**/company/

# Large files
public/books/*.pdf
*.mp4
*.mov
```

### Scanning for exposed secrets

```bash
node ~/.openclaw/workspace/scripts/secrets-check.js
```

Run this before any git push. Add it to your heartbeat checks.

---

## Step 3: Athena / Orchestrator Agent

⚠️ **CRITICAL, Never assert capabilities the agent doesn't have.**

Athena's `SOUL.md` must contain this exact capability list:

```markdown
## What I Can Do
✅ Fetch external URLs (NOT localhost/127.0.0.1)
✅ Read/write workspace files
✅ Send Discord messages
✅ Brief the executor agent via Discord

## What I Cannot Do
❌ exec / shell commands
❌ localhost or 127.0.0.1 (web_fetch blocks these)
❌ Direct Paperclip API calls
❌ Deploy code
```

### Athena → Executor brief format

Every brief must end with a confirmation request:

```
@[Executor] — Task from Athena
Project: [Name] | ID: [Paperclip UUID]

TASK 1
Title: [specific, actionable title]
Agent: [Dev | Copywriter | SEO | etc]
Agent ID: [UUID]
Description: [what to do, acceptance criteria, file paths]

Confirm: reply here when tasks are created with Paperclip task IDs.
```

The `Confirm:` line is mandatory. Without it Athena has no signal tasks were created.

---

## Step 4: Paperclip Setup

### 4.1 Install

```bash
npm install -g paperclipai
paperclipai onboard
```

⚠️ **CRITICAL, Port Squatting Trap:**

`paperclipai onboard` starts a process on port 3100 and leaves it running. pm2 will fail silently if port 3100 is already occupied.

```bash
# Check what's on 3100
lsof -i :3100

# Kill it before starting pm2
kill -9 [PID]
```

### 4.2 Turn Off Board Approval

⚠️ **CRITICAL, Silent API Key Blocker:**

`requireBoardApprovalForNewAgents` is ON by default. This silently prevents API key generation with no error.

In Paperclip admin → Settings → set `requireBoardApprovalForNewAgents: false` before creating any agents.

### 4.3 Task-Type Specialists, Not Per-Project Agents

✅ Correct: Dev, Copywriter, SEO, Social, Marketing, Ads, Outreach, Analytics
❌ Wrong: MonitorTheSit-Dev, ProjectAlpha-Writer

Agents are reusable across projects. Tasks carry project context.

### 4.4 Required adapterConfig

```json
{
  "adapterConfig": {
    "cwd": "/path/to/agent/workspace",
    "model": "claude-sonnet-4-6",
    "dangerouslySkipPermissions": false,
    "maxTurnsPerRun": 20,
    "timeoutSec": 300
  }
}
```

> ⚠️ **Security tradeoff.** With `dangerouslySkipPermissions: false` (the safe default), agents pause waiting for confirmation during unattended runs. Setting it to `true` lets nightly work complete without intervention but **disables Claude Code's permission prompts**. Combined with agents that consume external content (Discord, web, Paperclip task descriptions), a prompt injection becomes shell execution. Read [SECURITY.md](./SECURITY.md) before flipping the flag, and prefer scoping it per-agent (e.g., a nightly QC agent reading only your own logs) rather than globally.

### 4.5 pm2 Configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'paperclip',
    script: './dist/server.js',
    env: {
      NODE_ENV: 'production',
      PORT: '3100'   // Required — prevents port drift
    }
  }]
};
```

```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup   # follow the output instructions
```

---

## Step 5: OpenClaw Configuration

### 5.1 OPENCLAW_TOKEN: Persistent Env Var

⚠️ **CRITICAL:** Must be set persistently, not just in the current shell.

```bash
echo 'export OPENCLAW_TOKEN="your-token-here"' >> ~/.zshrc
source ~/.zshrc
```

### 5.2 Channel Configuration: Binding Is Not Enough

⚠️ **CRITICAL, Silent Channel Drop:**

Agent bindings in `bindings[]` do NOT make an agent respond to messages. Every channel must have an entry in the guild's `channels` block.

```json
"channels": {
  "discord": {
    "guilds": {
      "[GUILD_ID]": {
        "channels": {
          "[CHANNEL_ID]": {
            "allow": true,
            "requireMention": false,
            "systemPrompt": "..."
          }
        }
      }
    }
  }
}
```

If a channel is missing from this block, messages are silently dropped. No error, no log.

**Fix:** Add every agent channel to the `channels` block in `~/.openclaw/openclaw.json`. The `bindings[]` array is routing — the `channels` block is permission. Both must reference the channel.

To verify which channels are registered:

```bash
cat ~/.openclaw/openclaw.json | node -e "const c=require('fs').readFileSync('/dev/stdin','utf8'); const cfg=JSON.parse(c); const guilds=cfg?.channels?.discord?.guilds||{}; Object.entries(guilds).forEach(([g,v])=>Object.keys(v.channels||{}).forEach(ch=>console.log(g+'/'+ch)));"
```

If an agent's channel ID is missing from the output, add it to the `channels` block and restart the gateway.

### 5.3 Subagent Model: Pin It Explicitly

⚠️ **CRITICAL, LiveSessionModelSwitchError:**

If a session has a model override active (e.g. you switched to Opus mid-session) and spawns a subagent, OpenClaw tries to switch models on a live session, which fails with `LiveSessionModelSwitchError` and the subagent dies immediately.

**Fix:** pin `agents.defaults.subagents.model` in `openclaw.json` so subagents always use a fixed model regardless of the parent session state.

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "model": "anthropic/claude-sonnet-4-6",
        "runTimeoutSeconds": 900
      }
    }
  }
}
```

Without this, any session where the model was ever switched can cause all subagents to fail silently.

---

### 5.4 Gateway Restart: Required After Every Config Change

```bash
openclaw gateway restart
```

Run this after every config change. No exceptions.

### 5.4 GitHub Auth for Nightly Agents

```bash
gh auth login
gh auth status   # Must show: Logged in to github.com
```

Nightly agents cannot push branches without this.

---

## Step 6: Nightly Agent System

### 6.1 AGENT-BRIEF vs TASK-QUEUE: Keep Separate

⚠️ **CRITICAL, Multi-Task Trap:**

- **`AGENT-BRIEF.md`**: Context only. Tech stack, rules, off-limits. No tasks.
- **`TASK-QUEUE.md`**: Tasks only. What to do tonight. ONE task.

If tasks appear in `AGENT-BRIEF.md`, agents try to do all of them in one run.

### 6.2 Required Nightly Prompt Guardrails

Every nightly prompt must include:

```
Rules:
- Do not spawn subagents — do all work inline.
- STOP after committing and pushing. Do not continue.
- Build step: [npm run build / no build step for static HTML]
- Read ~/.openclaw/workspace/NIGHTLY-NOTES.md before starting. Append reusable findings.
- On unrecoverable error: post to Discord channel [ERROR_CHANNEL_ID]:
  "FAILED [project] [date] / Error: [what] / Last step: [what completed]" then STOP.
```

| Guardrail | Failure without it |
|---|---|
| No subagents | Spawns children, costs spiral |
| STOP after push | Keeps inventing new work |
| NIGHTLY-NOTES path | Agents work in isolation, no cross-project learning |
| Error channel ID | Silent failures, no alert |

### 6.3 AGENT-BRIEF.md Template

```markdown
# AGENT-BRIEF.md — [Project Name]

You are an autonomous improvement agent for [PROJECT].
Read this file first, then get to work.

## Project
- **App**: [description]
- **Repo**: [org/repo] (local: ~/Apps/[name])
- **Stack**: [frameworks, DB, deploy]
- **Branch rule**: Always work on nightly/YYYY-MM-DD. Never touch main.
- **Build check**: npm run build — if it fails, revert ALL changes.
- **Commit**: Only if build passes. Message: nightly(YYYY-MM-DD): <what you did>

## Start of Every Run
1. Read GOTCHAS.md — known traps, don't repeat them
2. Read ~/.openclaw/workspace/NIGHTLY-NOTES.md — learn from other agents
3. Read this brief for current focus
4. Do the work
5. Append to GOTCHAS.md if you hit anything unexpected
6. Post report to Discord channel [CHANNEL_ID]
7. Append to NIGHTLY-NOTES.md if you found something useful for other projects

## Current Focus
[The one thing to do tonight]

## Off-Limits
- Never touch [file]
- No changes to [route] without testing

## Cross-Agent Notes (REQUIRED)
After each run, if you discovered something that would help other nightly agents:
Append to ~/.openclaw/workspace/NIGHTLY-NOTES.md with format:
## [YYYY-MM-DD] [Agent: project-name]
- What I found: ...
- Relevant to: [other projects or "all"]
- Why it matters: [one sentence]
```

### 6.4 GOTCHAS.md: Mandatory for Every Project

```markdown
# GOTCHAS.md

- [YYYY-MM-DD] What was tried, what went wrong, what actually works
```

Every project needs this. Every nightly agent reads it before starting. Every agent appends when it hits an unexpected issue.

### 6.5 Cron Chain Order

```
1:00am  — full-backup
1:15am  — session-cleanup --purge
2:00am  — Project A nightly agent (timeout: 30min)
2:30am  — Project B nightly agent (timeout: 30min)
3:00am  — Project C nightly agent (timeout: 30min)
4:00am  — Synthesis agent (reads all reports, posts morning handover)
Sunday 23:00 — weekly-compaction
Every 30min (7am–11pm) — site-health
```

All nightly crons: `sessionTarget: isolated`

---

## Step 7: Project Scaffold

Every project with a nightly agent needs:

```
~/Apps/[project-name]/
  AGENT-BRIEF.md    ← Context only. No tasks.
  TASK-QUEUE.md     ← Tonight's task. ONE task.
  GOTCHAS.md        ← Known bugs and wrong assumptions

paperclip-output/[project-name]/
  DOSSIER.md
  BRAND.md
  strategy/
  content/
  social/[platform]/post-NNN/   ← caption.txt + image.png + meta.json
  ads/
  outreach/leads/
  outreach/sequences/
  video/
  logs/
```

---

## Step 8: Discord Channel Structure

```
#🦉〡athena     — command centre, daily comms
#🌊〡poseidon   — deep research, intelligence
#⚡〡icarus      — strategy, roadmaps
#🔨〡forge       — dev reports, build status
#👁️〡argus       — health reports, cost tracking
#🛡️〡heracles    — nightly QC, morning summaries
#🚨〡recovery    — emergency failsafe
```

---

## Step 9: Operational Scripts

```bash
~/.openclaw/workspace/scripts/
  full-backup.sh          # Daily workspace + session backup
  session-cleanup.js      # Purge orphaned executor sessions
  site-health.js          # Check all live sites are responding
  weekly-compaction.js    # Summarise and archive old memory files
  secrets-check.js        # Scan for exposed credentials in workspace
  nightly-report.js       # Agent success/failure rate over last N days
  nightly-tracker.js      # Log nightly run outcomes
```

---

## Step 10: Content Studio (Open Design) — optional, recommended

[Open Design](https://github.com/nexu-io/open-design) is the open-source alternative to Claude Design. It runs locally, drives any installed coding-agent CLI (Claude Code, Codex, Cursor Agent, Gemini, OpenCode, Qwen, Copilot CLI), and ships **19 composable Skills** × **71 brand-grade Design Systems**. Athena's office agents (Copywriter, Visual Director, Social) use it to produce social cards, blog posts, decks, landing pages, and product visuals from a single prompt.

`install.sh` offers this as Step 10 (opt-in). To set it up manually:

```bash
git clone https://github.com/nexu-io/open-design.git ~/Apps/open-design
cd ~/Apps/open-design

# Open Design pins pnpm via packageManager.
corepack enable
pnpm install

# First run — daemon (:7456) + web (:3000)
pnpm dev:all
open http://localhost:3000
```

Requirements: Node 20–22 (Open Design's `better-sqlite3` doesn't have prebuilt binaries for Node 24). Disk: ~500MB after install. Repo size: ~50MB clone.

After install, the path is recorded in `~/.env.secrets` as `OPEN_DESIGN_PATH=$HOME/Apps/open-design` so Athena agents can shell into it.

For production deployment (single-process, daemon serving the static export):

```bash
cd ~/Apps/open-design
pnpm build && pnpm start  # daemon at :7456 serves out/
```

See `~/Apps/open-design/QUICKSTART.md` and `README.md` for the full feature list.

---

## Step 11: Design Studio (Playwright + Firecrawl) — optional

Lower-level browser + scraping utilities, separate from Open Design:

```bash
npm install -g playwright firecrawl-cli
npx playwright install chromium
```

Used by Athena agents for browser automation, screenshot capture, and web scraping. `install.sh` Step 11 wraps this.

---

## Verification Checklist

Run after full setup. Every item must pass before going live.

**Paperclip:**
- [ ] `pm2 list` → paperclip shows `online`
- [ ] `curl http://127.0.0.1:3100/health` returns `{"status":"ok"}`
- [ ] No other process on port 3100 (`lsof -i :3100`)
- [ ] `requireBoardApprovalForNewAgents` is OFF
- [ ] All agent IDs recorded in ID Capture Sheet

**OpenClaw:**
- [ ] Gateway restarted after final config change
- [ ] All Discord channels have `allow: true` in channels config
- [ ] `OPENCLAW_TOKEN` set persistently (verify with `echo $OPENCLAW_TOKEN` in new terminal)
- [ ] `gh auth status` → authenticated

**Secrets:**
- [ ] `~/.env.secrets` exists and has `chmod 600`
- [ ] No raw API keys in MEMORY.md or any markdown file
- [ ] `secrets-check.js` returns clean
- [ ] CREDENTIALS.md in .gitignore (if it exists)

**Nightly system:**
- [ ] All cron prompts include the 5 required guardrails
- [ ] TASK-QUEUE.md exists and is separate from AGENT-BRIEF.md
- [ ] GOTCHAS.md exists in every project repo
- [ ] NIGHTLY-NOTES.md exists in workspace root
- [ ] Error Discord channel ID set in every nightly prompt

**State:**
- [ ] pm2 state saved (`pm2 save`)
- [ ] `pm2 startup` instructions followed
- [ ] MEMORY.md contains all IDs from capture sheet (values → references only)
- [ ] CURRENT.md exists and is up to date

---

## Common Mistakes

- **Skipping SOUL.md or writing it generically**: you'll get a generic assistant
- **Putting secrets in MEMORY.md**: they end up in LLM context. Use `~/.env.secrets`
- **Putting everything in MEMORY.md**: bloat. Hard facts only
- **Running `paperclipai onboard` and leaving it**: squats port 3100
- **`requireBoardApprovalForNewAgents` left ON**: API keys silently fail
- **Per-project agents instead of task-type specialists**: defeats reusability
- **Missing `adapterConfig`**: agents pause during nightly runs
- **Binding without channel entry**: messages silently dropped
- **No `agents.defaults.subagents.model` set**: subagents inherit parent session model; if that session ever had a model override, all subagents fail with `LiveSessionModelSwitchError`
- **Editing openclaw.json without restarting gateway**: changes have no effect
- **Tasks in AGENT-BRIEF.md**: agent tries all of them at once
- **GOTCHAS.md not created**: agents repeat the same bugs nightly
- **NIGHTLY-NOTES.md not set up**: agents work in isolation, no cross-project learning
- **`gh auth login` skipped**: nightly agents can't push branches
- **`OPENCLAW_TOKEN` not persisted**: works now, breaks on restart

---

## What Good Looks Like

After this setup, your system should:

- Remember who the operator is across sessions
- Know all active projects without being told
- Have a personality, not just politeness
- Run code, deploy, manage tasks without hand-holding
- Ship improvements to projects overnight
- Give a morning handover automatically
- Know when to stay quiet and when to speak up
- Alert on failures, never fail silently
- Back up its own state daily
- Scan for exposed secrets before every push

If all of that is true, it's set up right.

---

*Based on a production multi-agent system running 6+ active projects with autonomous nightly agents.*
