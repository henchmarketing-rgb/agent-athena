# Operations Reference
> Day 2 and beyond. Run-time architecture, troubleshooting, cost, and operational procedures for a system that's already installed.

> **For installation, see [INSTALL.md](./INSTALL.md) (manual path) or run `bash install.sh` from the repo root.** This document assumes the system is already running.

> **Runtime note:** This guide is written against the OpenClaw runtime (the default). If you installed Athena on the **Hermes Agent** runtime, every `openclaw <verb>` command in this doc maps to its `hermes <verb>` equivalent (`gateway start`, `cron add`, `doctor`, etc.). Workspaces live at `~/.hermes/workspaces/<agent>/` instead of `~/.openclaw/workspaces/<agent>/`. See [docs/RUNTIME-ADAPTERS.md](./docs/RUNTIME-ADAPTERS.md) for the full mapping. The rest of this guide (Paperclip, office team, nightly pipeline, cost tracking, alerting) is runtime-agnostic.

---

## What OpenClaw actually is

Before touching anything, understand the architecture or you'll be confused the whole time.

**OpenClaw is:**
- A persistent gateway daemon running on your machine (macOS LaunchAgent or Linux systemd)
- An agent runtime that wraps Claude (or any LLM) with tools: exec, browser, filesystem, web search, memory
- A session manager that keeps conversation history across Discord messages
- A file-based memory system, the model has no persistent state, only what's written to disk

**OpenClaw is NOT:**
- A hosted service (it runs on your machine)
- A separate bot for each agent, one gateway, multiple channel personas
- A replacement for your IDE, it's your always-on AI team member

**The key insight:** Your workspace files ARE your agent's brain. `SOUL.md`, `AGENTS.md`, `MEMORY.md` are injected into every session automatically. If it's not in a file, the agent doesn't know it when the session restarts. Write things down.

**The "team" is one gateway + channel system prompts:**
Athena, Poseidon, Icarus, Forge, Argus, Heracles, Recovery, these are not separate bots. They're the same gateway, responding to different Discord channels, each with a different `systemPrompt` in the config. One gateway. One set of tools. Many personas.

---

## System requirements

**Mac (recommended):**
```bash
# Install Homebrew first: https://brew.sh
brew install node git gh jq ffmpeg yt-dlp imagemagick potrace
npm install -g openclaw pm2 vercel pnpm
gh auth login
```

**Linux:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git jq ffmpeg imagemagick
npm install -g openclaw pm2 vercel
```

**Required accounts (create before starting):**
- [Anthropic Console](https://console.anthropic.com), Claude API key (main model)
- [Discord Developer Portal](https://discord.com/developers), bot token
- [GitHub](https://github.com) + `gh auth login`
- [Brave Search API](https://brave.com/search/api/), free tier (2k queries/month) for web_search
- [NVIDIA NIM](https://build.nvidia.com), free tier, for deep research model (optional)

**Optional but high-value (free):**
- [Groq](https://console.groq.com), fast inference, Whisper transcription
- [Firecrawl](https://firecrawl.dev), better web scraping than default
- [OpenRouter](https://openrouter.ai), model fallback routing

**Discord bot permissions required:**
- `Send Messages`, `Read Messages`, `Read Message History`
- `Add Reactions`, `Attach Files`, `Embed Links`
- Enable `Message Content Intent` in Discord Dev Portal → Bot → Privileged Gateway Intents

---

## Operator setup

This document assumes the system is already installed. For step-by-step installation (manual path) see [INSTALL.md](./INSTALL.md). For the automated path run `bash install.sh` from the repo root.

The remainder of this document covers what you need _after_ install: the team structure (OFFICE.md), runtime configuration (openclaw.json), the multi-agent system, the nightly agent system, operational scripts, cost architecture, day-2 procedures, and troubleshooting.

---


## OFFICE.md — team structure (the most important file nobody writes well)

OFFICE.md is your operations manual. It defines how your team works, who does what, and the golden rules that govern every decision. Without it, your agent improvises.

```markdown
# OFFICE.md — Operations Manual

## Team Structure
[Who exists, what they do, what tools they have]

Example:
- 🦉 Athena — Command centre, coordinator. Routes tasks, runs onboarding, owns compaction.
- 🌊 Poseidon — Deep research, intelligence. No exec. Confidence levels on all claims.
- ⚡ Icarus — Strategy, roadmaps, positioning. No exec. Asks one question first.
- 🔨 Forge — Dev agent. Code, builds, deploys. Has exec access.
- 👁️ Argus — Monitoring, health, cost tracking. Morning reports, weekly cost summaries.
- 🛡️ Heracles — Night oversight, QC. Scores nightly reports. Morning summary to #athena.
- 🚨 Recovery — Emergency failsafe. Elevated permissions. Incident response only.

## How Work Gets Done

1. You give a brief in #[main-channel]
2. [Main agent] plans and executes
3. You approve anything external (deploys, emails, posts, purchases)

## Pre-Task Discovery (REQUIRED before any project work)

Before creating tasks, answer:
1. What stage is this project? (Concept / MVP / Launched / Growing)
2. What's live? (URL? Social accounts? Email list? Users?)
3. What are we trying to achieve? (Specific, measurable)
4. What's the ONE action we want someone to take?
5. Any constraints? (Budget, timeline, tone, things off-limits)
6. Definition of done? (Draft only / ready to ship / needs design)

## Paperclip Task Flow
- Create issue → assign to agent → issue status moves to `in_progress`
- Agent works → moves to `in_review` when done
- You approve: `approve [ISSUE-ID]` in Discord
- Agent notified, moves to `done`

## Golden Rules
1. You approve all external actions (deploys, emails, posts, purchases)
2. Ask, don't assume — if requirements are unclear, ask first
3. One change at a time — verify it worked before the next
4. No silent failures — if something breaks, alert immediately
5. Write it down — if it's not in a file, it doesn't exist

## Agent IDs (Paperclip)
- Dev: [UUID]
- Copywriter: [UUID]
[etc]

## Discord Channels
- #[name]: [channel ID]
[etc]
```

---

## Secrets management (post-install)

### `~/.env.secrets`: secrets store for scripts

```bash
cat > ~/.env.secrets << 'EOF'
# Agent secrets — never committed to git
# Source this in scripts: source ~/.env.secrets

ANTHROPIC_API_KEY=your-key
SUPABASE_SERVICE_ROLE_KEY=your-key
GROQ_API_KEY=your-key
RAPIDAPI_KEY=your-key
# Add all service credentials here
EOF
chmod 600 ~/.env.secrets
```

### API keys in openclaw.json: model providers and tool keys

Different keys go in different places:

```json5
{
  // Model provider keys
  "models": {
    "providers": {
      "nvidia": { "apiKey": "nvap..." },
      "moonshot": { "apiKey": "sk-..." },
      "openrouter": { "apiKey": "sk-or-..." }
    }
  },
  // Tool API keys
  "env": {
    "GROQ_API_KEY": "gsk_...",
    "FIRECRAWL_API_KEY": "fc-...",
    "NVIDIA_API_KEY": "nvap...",
    "MOONSHOT_API_KEY": "sk-..."
  },
  // Brave search (in plugins)
  "plugins": {
    "entries": {
      "brave": {
        "config": {
          "webSearch": { "apiKey": "BSA..." }
        }
      }
    }
  }
}
```

Anthropic API key goes through OAuth during `openclaw onboard`, stored in `~/.openclaw/identity/`.

### Reference secrets by name in markdown

```markdown
# In MEMORY.md
- Supabase service role → ~/.env.secrets (SUPABASE_SERVICE_ROLE_KEY)
- App password → ~/.env.secrets (APP_PASSWORD)
```

### Workspace `.gitignore`

```gitignore
# Secrets
CREDENTIALS.md
**/credentials.md
.env
.env.*
*.env

# Large assets
*.pdf
*.mp4
*.mov
public/books/

# OpenClaw internals
.openclaw/
```

---

## openclaw.json configuration

The full config. Replace bracketed values with yours.

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-6",
        "fallbacks": ["anthropic/claude-opus-4-6"]
      },
      "workspace": "~/.openclaw/workspace",
      "contextPruning": {
        "mode": "cache-ttl",   // Uses Anthropic prompt caching — saves ~97% on input costs
        "ttl": "3m",
        "keepLastAssistants": 3
      },
      "compaction": {
        "mode": "default",
        "maxHistoryShare": 0.15,
        "memoryFlush": { "enabled": true }  // Auto-saves memory before context compacts
      },
      "timeoutSeconds": 3600,
      "heartbeat": {
        "every": "2h",
        "activeHours": {
          "start": "07:00",
          "end": "23:00",
          "timezone": "Your/Timezone"  // IANA timezone
        },
        "lightContext": true
      }
    },
    "list": [
      {
        "id": "main",
        "workspace": "~/.openclaw/workspace"
      },
      {
        "id": "poseidon",
        "model": "anthropic/claude-sonnet-4-6",
        "workspace": "~/.openclaw/workspace"
      },
      {
        "id": "research",
        "model": {
          "primary": "nvidia/moonshotai/kimi-k2-instruct",   // Free
          "fallbacks": [
            "nvidia/moonshotai/kimi-k2.5",                   // Free
            "moonshot/kimi-k2.5"                             // Paid fallback
          ]
        },
        "workspace": "~/.openclaw/workspace"
      },
      {
        "id": "executor",
        "model": "anthropic/claude-sonnet-4-6",
        "workspace": "~/.openclaw/workspace"
      }
    ]
  },

  "tools": {
    "exec": {
      "security": "full",    // "full" = runs with your permissions
      "ask": "on-miss"       // First time a command runs → asks. After that, runs freely.
    },
    "fs": {
      "workspaceOnly": false  // true = sandboxed to workspace only
    },
    "web": {
      "search": {
        "provider": "brave",
        "maxResults": 5,
        "timeoutSeconds": 30
      }
    }
  },

  "session": {
    "reset": {
      "mode": "idle",
      "idleMinutes": 120   // Context resets after 2h of inactivity — intentional
    }
  },

  "channels": {
    "discord": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN",
      "groupPolicy": "allowlist",    // Only listed users can trigger the agent
      "streaming": "off",
      "allowFrom": [
        "user:YOUR_DISCORD_USER_ID"  // Add more users here for team access
      ],
      "guilds": {
        "YOUR_GUILD_ID": {
          "requireMention": false,
          "channels": {
            "YOUR_MAIN_CHANNEL_ID": {
              "allow": true,
              "requireMention": false,   // false = responds to every message
              "systemPrompt": "You are Athena...\n\n[Athena identity + coordinator rules]"
            },
            "YOUR_POSEIDON_CHANNEL_ID": {
              "allow": true,
              "requireMention": false,
              "systemPrompt": "You are Poseidon...\n\n[Research identity + confidence levels]"
            },
            "YOUR_ICARUS_CHANNEL_ID": {
              "allow": true,
              "requireMention": false,
              "systemPrompt": "You are Icarus...\n\n[Strategy identity + one-question rule]"
            },
            "YOUR_RECOVERY_CHANNEL_ID": {
              "allow": true,
              "requireMention": false,
              "systemPrompt": "RECOVERY MODE. Act fast, no hesitation. Emergency stop: bash ~/.openclaw/workspace/scripts/emergency-stop.sh"
            }
          }
        }
      }
    }
  },

  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "channelHealthCheckMinutes": 15
  }
}
```

**After every config change:**
```bash
openclaw gateway restart
```

This is mandatory. Config changes have zero effect until the gateway reloads.

---

## Multi-agent system (the "team")

Each Discord channel gets a different system prompt = different persona. Same gateway. One config file.

**Per-channel system prompt structure:**
```
You are [NAME] [emoji] — [role] for [company/operator].

YOUR IDENTITY:
- Agent ID: [id] | Model: [model]
- Workspace: ~/.openclaw/workspace

CAPABILITIES:
[List what this agent CAN do]
✅ exec, browser, github, deploy, filesystem
✅ Paperclip API, cron management

CANNOT:
❌ [List what it cannot do — be explicit]
❌ Deploy without approval

YOUR JOB:
[Specific, concrete description]

RULES:
[Agent-specific rules — not the same as AGENTS.md]
```

**The recovery channel system prompt** (your panic button):
```
You are [NAME] 🚨 — RECOVERY MODE.

THIS CHANNEL EXISTS because something broke and you need it stopped NOW.

EMERGENCY STOP (kills all agents + disables all crons):
bash ~/.openclaw/workspace/scripts/emergency-stop.sh

PRIORITY:
1. Read the message — what is broken?
2. If runaway: emergency-stop.sh FIRST, questions after
3. session_status — check current state
4. openclaw cron list — look for anything still running

RULES:
- Act first, report after
- Never ask "are you sure?"
```

---

## Nightly agent system

### The pattern

Every project that gets nightly agents needs this in its repo:

```
~/Apps/[project]/
  AGENT-BRIEF.md      ← Context, rules, stack info, current focus
  GOTCHAS.md          ← Known bugs — READ FIRST every run
```

### AGENT-BRIEF.md template

```markdown
# AGENT-BRIEF.md — [Project Name]

## Project
- Repo: [org/repo] | Local: ~/Apps/[name]
- Stack: [frameworks, DB, deploy target]
- Branch rule: Always nightly/YYYY-MM-DD. NEVER touch main.
- Build: `npm run build` — fail = revert ALL changes
- Commit: only if build passes. Message: `nightly(YYYY-MM-DD): iter-N: what you did`

## Start of Every Run
1. Read GOTCHAS.md — known traps, don't repeat them
2. Read ~/.openclaw/workspace/NIGHTLY-NOTES.md — learn from other agents
3. Read this brief
4. Do the work
5. Append to GOTCHAS.md if you hit anything unexpected
6. Post report to Discord channel [CHANNEL_ID]
7. Append to NIGHTLY-NOTES.md if useful for other projects

## Safety Rules
1. Never modify .env, secrets, or build config
2. Never delete files — only create or modify
3. Never touch main
4. If uncertain — skip and note it
5. Build must pass before committing

## Current Focus
[What to work on tonight — be specific]

## Off-Limits
[What NOT to touch — be explicit]

## Cross-Agent Notes (REQUIRED)
After this run, append to ~/.openclaw/workspace/NIGHTLY-NOTES.md:
## [YYYY-MM-DD] [Agent: project-name]
- What I found: ...
- Relevant to: ...
- Why it matters: ...
```

### Cron setup

```bash
# Main agent nightly
openclaw cron add \
  --name "[project]-nightly" \
  --cron "0 2 * * *" \
  --tz "Your/Timezone" \
  --message "Read ~/Apps/[project]/AGENT-BRIEF.md and GOTCHAS.md first, then work on the current focus. Branch: nightly/\$(TZ=Your/Timezone date +%Y-%m-%d). Build must pass before committing." \
  --session isolated \
  --timeout-seconds 2700 \
  --announce \
  --channel discord \
  --to "channel:YOUR_MAIN_CHANNEL_ID"

# Operational crons
openclaw cron add --name "full-backup" --cron "0 1 * * *" --tz "Your/Timezone" \
  --message "bash ~/.openclaw/workspace/scripts/full-backup.sh" \
  --session isolated --timeout-seconds 300 --announce --channel discord \
  --to "channel:YOUR_MAIN_CHANNEL_ID"

openclaw cron add --name "session-cleanup" --cron "15 1 * * *" --tz "Your/Timezone" \
  --message "node ~/.openclaw/workspace/scripts/session-cleanup.js --purge" \
  --session isolated --timeout-seconds 120 --announce --channel discord \
  --to "channel:YOUR_MAIN_CHANNEL_ID"

openclaw cron add --name "weekly-compaction" --cron "0 23 * * 0" --tz "Your/Timezone" \
  --message "node ~/.openclaw/workspace/scripts/weekly-compaction.js" \
  --session isolated --timeout-seconds 300 --announce --channel discord \
  --to "channel:YOUR_MAIN_CHANNEL_ID"

openclaw cron add --name "site-health" --cron "*/30 0-16 * * *" --tz "UTC" --exact \
  --message "node ~/.openclaw/workspace/scripts/site-health.js --quiet" \
  --session isolated --timeout-seconds 60 --best-effort-deliver --announce \
  --channel discord --to "channel:YOUR_MAIN_CHANNEL_ID"
```

**Critical cron settings:**
- `--session isolated`, each cron run gets a fresh context, doesn't pollute your main session
- `--timeout-seconds`, agentTurn crons need 3–5× the actual script runtime (LLM warmup + exec + response)
- `--announce`, posts a summary to Discord when done

### GOTCHAS.md

```markdown
# GOTCHAS.md

- [YYYY-MM-DD] What I tried → what went wrong → what actually works
```

Every project needs this. Every agent reads it. Every failure gets documented here. This is free institutional memory.

---

## Operational scripts

Put these in `~/.openclaw/workspace/scripts/`. They're called by crons and heartbeat.

### `full-backup.sh`
Backs up workspace files and session history to `~/athena-backups/`. Keeps last 30. Run at 1am nightly.

### `session-cleanup.js`
Finds orphaned executor sessions (created by crons, never cleaned up). Dry run first: `node session-cleanup.js`, purge: `node session-cleanup.js --purge`.

### `site-health.js`
Checks your live URLs return 200. Config: add your URLs to the script. `--quiet` flag only outputs failures.

### `secrets-check.js`
Scans workspace files for patterns matching API keys, JWTs, passwords. Run before any git push.

### `nightly-report.js`
Reads cron run history and shows success/failure rates over last N days. `--days 7`.

### `weekly-compaction.js`
Summarises old memory files into weekly rollups, moves them to `memory/weekly/`.

### `gen-current.sh`
Auto-generates `CURRENT.md` from real system state: git branches, last commits, pm2 status, cron health. Run nightly or on demand.

### `emergency-stop.sh`
Disables ALL crons, restarts gateway, kills all active agent runs. Use when something is runaway.

---

## Cost architecture

Real numbers from production use.

**Model costs (Anthropic, March 2026):**
- Sonnet 4-6: ~$3/MTok input, ~$15/MTok output
- With 99% cache hit rate (typical for steady sessions): effective input cost ~$0.03/MTok
- Opus 4-6: ~$15/MTok input, ~$75/MTok output (fallback only)

**What actually costs money:**
- Long interactive sessions with big workspace files (MEMORY.md + AGENTS.md in every turn)
- Nightly agents: ~25k tokens/run → ~$0.50/run → $2.50/night for 5 projects → ~$75/month
- Context resets: each new session re-warms the cache, first turn is expensive, subsequent turns cheap

**Cost levers (in order of impact):**
1. Keep MEMORY.md under 3000 bytes, it's injected every single turn
2. Keep SOUL.md, AGENTS.md, OFFICE.md lean, same reason
3. Use `cache-ttl` context pruning, 97% cost reduction on input after first turn
4. Use NVIDIA NIM (free) for research agents, zero cost for research-heavy tasks
5. Set session idle reset to 2h, prevents zombie sessions accumulating context

**NVIDIA NIM free tier**, genuinely free, generous limits, 128k+ context models. Use for: lead research, competitor analysis, long-form writing, anything that needs deep context. Set as primary model for your research agent (Poseidon) with a paid fallback.

---

## Day 2 and beyond

### Adding a new project to the nightly system

1. Create `~/Apps/[project]/AGENT-BRIEF.md`, context, stack, current focus
2. Create `~/Apps/[project]/GOTCHAS.md`, empty to start
3. Create `paperclip-output/[project]/DOSSIER.md`, business context
4. Add a nightly cron (see Step 8)
5. Update `CURRENT.md` to include the project

### Retiring a project

1. Disable the cron: `openclaw cron disable [CRON_ID]`
2. Move the local repo to `~/Apps/_archive/`
3. Remove from `CURRENT.md`
4. Keep `GOTCHAS.md`, the knowledge is still useful

### Handling a bad nightly run

```bash
cd ~/Apps/[project]
git log --oneline -5          # Find the bad commit
git revert HEAD               # Or:
git reset --hard HEAD~1       # (destructive — only if not pushed)
git push origin main          # Push the revert
```

Then update `AGENT-BRIEF.md` with what went wrong and add it to `GOTCHAS.md`.

### Context getting heavy (approaching reset)

Signs: responses getting slower, agent seeming to "forget" recent context.

```
/status         # Check context % in Discord
```

When context is high:
1. Ask the agent to write a session summary to today's memory file
2. Start a fresh session, the agent will read the files and re-orient

Pattern for clean handover:
```
"Before we reset — write a catch-up summary to memory/[today].md covering 
everything we did this session, what's pending, and what to pick up next."
```

### Adding a second operator

In `openclaw.json`, add their Discord user ID to `allowFrom`:
```json
"allowFrom": [
  "user:YOUR_USER_ID",
  "user:THEIR_USER_ID"
]
```
Then `openclaw gateway restart`.

### Mobile workflow

Discord on your phone = full agent access. The bot responds identically whether you're on desktop or mobile. The recovery channel works on mobile, useful if something goes wrong at 3am and you need to stop the nightlies without opening a laptop.

---

## Troubleshooting

**The agent isn't responding in Discord**
1. Check `openclaw gateway status`, is it running?
2. Check the channel is in `guilds.[GUILD_ID].channels` in openclaw.json, not just in `bindings`
3. Check `requireMention`, if `true`, you need to @mention the bot
4. Check `allowFrom`, your Discord user ID must be listed
5. `openclaw gateway restart` after any config change

**Cron keeps erroring**
```bash
openclaw cron runs --id [CRON_ID] --limit 3
```
Look at the error message. Most common causes:
- Timeout too short, agentTurn crons need more time than the actual script (LLM warmup overhead). Add 3× the script runtime.
- Delivery failure, `"Unsupported channel: discord"` means gateway restarted and lost channel state. Restart gateway.
- Script error, check the script path is absolute, not relative

**`web_search` returns nothing / errors**
Brave API key not set. Add it to `plugins.entries.brave.config.webSearch.apiKey` in openclaw.json. Free tier at brave.com/search/api/.

**Agent ignoring SOUL.md / acting generic**
File is too long (>20k chars) and being truncated. Check with `wc -c ~/.openclaw/workspace/SOUL.md`. Keep it under 5k, personality doesn't need to be verbose.

**Nightly agent not pushing to GitHub**
```bash
gh auth status
```
If expired: `gh auth login`. Token expires periodically.

**`npm run build` hanging in nightly cron**
Timeout is too short. Set `--timeout-seconds 2700` (45 min) for any project with a build step. The LLM needs time to warm up + the build itself can take minutes.

**Context resets when you don't want it to**
Session idle timeout is kicking in. Change in openclaw.json:
```json
"session": {
  "resetByChannel": {
    "[YOUR_CHANNEL_ID]": {
      "mode": "idle",
      "idleMinutes": 240  // 4 hours
    }
  }
}
```

**pm2 not starting / port 3100 occupied**
```bash
lsof -i :3100           # Find what's on the port
kill -9 [PID]           # Kill it
pm2 start ecosystem.config.js
pm2 save
```

**Gateway eating memory / getting slow**
```bash
openclaw gateway restart
```
The gateway accumulates state over days. Weekly restart is fine.

---

## Verification checklist

Run after setup. Everything must pass.

**Tools:**
- [ ] `node --version` → 18+
- [ ] `gh auth status` → logged in
- [ ] `openclaw gateway status` → running
- [ ] `openclaw doctor --fix` → no errors

**Config:**
- [ ] Brave API key set (test: ask agent to search something)
- [ ] Discord bot token valid (agent responds in Discord)
- [ ] `allowFrom` includes your Discord user ID
- [ ] All channels in `guilds.[ID].channels`, not just in bindings
- [ ] `OPENCLAW_TOKEN` persists across new terminal (`echo $OPENCLAW_TOKEN`)

**Workspace:**
- [ ] SOUL.md exists and has a real personality
- [ ] AGENTS.md has your actual rules
- [ ] MEMORY.md exists, under 3000 bytes, no raw API keys
- [ ] OFFICE.md exists with your team structure
- [ ] HEARTBEAT.md has your health checks
- [ ] NIGHTLY-NOTES.md exists at workspace root

**Secrets:**
- [ ] `~/.env.secrets` exists, `chmod 600`
- [ ] `secrets-check.js` returns clean
- [ ] Workspace `.gitignore` covers CREDENTIALS.md and *.env

**Nightly system (for each active project):**
- [ ] `~/Apps/[project]/AGENT-BRIEF.md` exists
- [ ] `~/Apps/[project]/GOTCHAS.md` exists
- [ ] Cron created with `--session isolated`
- [ ] Cron timeout is at least 3× expected runtime
- [ ] Cron tested manually: `openclaw cron run [CRON_ID]`

**Operational:**
- [ ] `full-backup.sh` runs successfully
- [ ] `session-cleanup.js` (dry run) shows expected results
- [ ] `site-health.js` returns status for your live URLs
- [ ] `gen-current.sh` writes correct CURRENT.md
- [ ] `nightly-report.js --days 7` returns a summary

---

## What good looks like at 30 days

By the end of your first month, the system should:

- Wake up each morning with a summary of what happened overnight
- Know every active project without being told
- Push improvements to projects while you sleep
- Alert on failures before you notice them
- Back up its own state daily without being asked
- Stay quiet when there's nothing useful to say
- Know when to check files vs when to just answer
- Cost less than a Netflix subscription to run

If all of that is true, it's working.

---

## MCP Servers (Optional)

MCP (Model Context Protocol) servers extend what your agents can do, GitHub operations, web search, browser automation, database access. Start with GitHub + Brave Search, add more as needed.

Full guide: [docs/MCP-SERVERS.md](docs/MCP-SERVERS.md)

---

## What tends to go wrong (and why)

**Month 1:** Setup friction. Gateway restarts, cron timeouts, missing channel config. Most issues are one-time config problems. `openclaw doctor --fix` catches most of them.

**Month 2:** Context bloat. MEMORY.md grows. AGENTS.md gets padded with notes. Sessions start getting expensive. Trim the files. Keep only hard facts in MEMORY.md.

**Month 3+:** The system works but the briefs go stale. Nightly agents work on the wrong thing because AGENT-BRIEF.md wasn't updated. Spend 10 minutes a week updating current focus across all active briefs.

**The one thing most people underinvest in:** GOTCHAS.md. When a nightly run fails and you don't write it down, the same thing fails next week. When you do write it down, it never fails the same way twice.

---

*Built on a production system. Everything we know is in here.*
