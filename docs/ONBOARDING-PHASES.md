# Athena Onboarding

One script does everything. Or follow the manual steps below if you prefer.

## Quick Start (One Script)

```bash
git clone https://github.com/henchmarketing-rgb/agent-athena.git
cd agent-athena
bash install.sh
```

The script handles: dependencies, Claude auth, Discord setup, all credentials, OpenClaw onboard, workspace files, and gateway start. At the end, go to Discord and say hello to Athena.

---

## Manual Steps (if you prefer)

# Part 1: Prep Everything (~10 minutes)

Do all of this before touching OpenClaw. When you're done you'll have everything ready to paste.

## 1A: Accounts & Credentials

Open each link, sign up / log in, get the credential. Save them all in a text file (you'll paste each one during install).

| What | Where to Get It | What You Need |
|------|----------------|---------------|
| **Claude auth** | You'll generate this in step 1B | Setup-token OR API key |
| **Discord bot** | [discord.com/developers](https://discord.com/developers/applications) | Bot token |
| **Discord server** | Your Discord app | Server ID + #athena Channel ID |
| **GitHub** | [github.com/settings/tokens](https://github.com/settings/tokens) | Personal access token (repo scope) |
| **Brave Search** | [brave.com/search/api](https://brave.com/search/api/) | API key (free tier: 2k queries/mo) |
| **Vercel** *(optional)* | [vercel.com/account/tokens](https://vercel.com/account/tokens) | Deploy token |
| **Supabase** *(optional)* | Your Supabase project → Settings → API | Service role key |

### Discord Bot Setup

1. [discord.com/developers](https://discord.com/developers/applications) → **New Application** → name it "Athena"
2. **Bot** tab → **Reset Token** → copy the bot token
3. **Bot** tab → enable:
   - Message Content Intent ✓
   - Server Members Intent ✓
   - Presence Intent ✓
4. **OAuth2** → **URL Generator** → Scopes: `bot` → Permissions: Send/Read Messages, Read History, Add Reactions
5. Copy the generated invite URL → open it → add bot to your Discord server

### Discord Server + Channel

1. Create a Discord server (or use existing)
2. Create channel: `#🦉〡athena`
3. Enable **Developer Mode** (User Settings → Advanced → Developer Mode)
4. Right-click server name → **Copy Server ID**
5. Right-click #athena channel → **Copy Channel ID**

## 1B: Claude Auth Token

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Log in (opens browser — use your Claude account)
claude auth login

# Generate setup-token (uses your subscription, no API billing)
claude setup-token
# Copy the output — you'll paste it during openclaw onboard
```

> **Using an API key instead?** Go to [console.anthropic.com](https://console.anthropic.com) → API Keys → Create Key → add billing credit.
> Full auth options: [CLAUDE-AUTH-SETUP.md](CLAUDE-AUTH-SETUP.md)

## 1C: Software Install

```bash
# Node.js (if not installed)
# Mac: brew install node
# Linux: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install -y nodejs

# Required
npm install -g openclaw              # Agent runtime
npm install -g pm2                   # Process manager

# GitHub CLI
# Mac: brew install gh
# Linux: see https://cli.github.com
gh auth login                        # Authenticate with GitHub
```

## Checklist: You Should Now Have

- [ ] Claude setup-token (or API key), copied
- [ ] Discord bot token, copied
- [ ] Discord server ID, copied
- [ ] Discord #athena channel ID, copied
- [ ] GitHub token, from `gh auth login`
- [ ] Brave Search API key, copied
- [ ] Node.js, OpenClaw, PM2, gh, all installed
- [ ] *(Optional)* Vercel token, Supabase key

---

# Part 2: Install + Go Live (~3 minutes)

Everything is ready. Now just run the wizard and paste.

## Step 1: OpenClaw Onboard

```bash
openclaw onboard
```

The wizard asks for everything you prepped:
- **Auth** → "Anthropic token (paste setup-token)" → paste
- **Discord bot token** → paste
- **Server ID + channel** → paste
- **Web search** → "Brave Search" → paste API key

It creates the config and workspace automatically.

## Step 2: Store All Secrets

```bash
cat > ~/.env.secrets << 'EOF'
# Discord
DISCORD_BOT_TOKEN=your-bot-token

# GitHub (if not using gh CLI auth)
GITHUB_TOKEN=ghp_your-token

# Brave Search
BRAVE_SEARCH_API_KEY=BSA_your-key

# Vercel (optional)
VERCEL_TOKEN=your-token

# Supabase (optional)
SUPABASE_SERVICE_ROLE_KEY=your-key

# Paperclip (filled in during Phase 5)
# PAPERCLIP_API_KEY=
# COMPANY_ID=
EOF

chmod 600 ~/.env.secrets
echo 'source ~/.env.secrets' >> ~/.zshrc   # or ~/.bashrc
source ~/.env.secrets
```

## Step 3: Add Athena's Identity + Start

```bash
# Copy Athena's personality and rules from this repo
cp workspaces/athena/* ~/.openclaw/workspaces/athena/

# Start
openclaw gateway start

# Verify everything
openclaw doctor
```

## Step 4: Say Hello

Go to `#🦉〡athena` in Discord:

> Hi Athena, I'm ready to set up the system.

**She responds. You're in. No more terminal needed.**

---

# Part 3: Athena Takes Over (In Discord)

Everything below happens in Discord. You talk, Athena works.

---

## Phase 1: Who Are You?

**Athena asks:** Name, timezone, business type, biggest bottleneck.

**Athena does:** Writes `USER.md` and `MEMORY.md`. Determines agent priority order.

---

## Phase 2: Discord Channels

**Athena says:** "Create these 6 channels and give me the IDs:"

```
#🌊〡poseidon   #⚡〡icarus     #🔨〡forge
#👁️〡argus       #🛡️〡heracles   #🚨〡recovery
```

**Athena does:** Updates config with all bindings, restarts gateway, tests each channel.

---

## Phase 3: Multi-Agent Config

**Athena does (no input needed):** Creates all 7 workspace directories, copies identity files, updates config, restarts gateway, tests all agents respond in their channels.

---

## Phase 4: Paperclip Setup

**Athena does:**
1. Walks you through `paperclipai onboard --yes` if needed
2. Creates Icarus as Paperclip CEO
3. Registers all 7 office agents with correct configs
4. Sets org chart (all report to Icarus)
5. Installs Paperclip skill in each office workspace
6. Writes agent IDs to OFFICE.md

**Confirms:** Lists all agents with status.

---

## Phase 5: Projects & Goals

**Athena asks:** What projects? What's your quarterly goal?

**Athena does:** Creates briefs, task queues, Paperclip projects and goals, NIGHTLY-NOTES.md, memory directories.

---

## Phase 6: Crons & Nightly Agents

**Athena does:** Configures health checks (6am), cost tracking (Sunday 9am), memory compaction (Sunday 11pm), backups (2am), secrets scan, nightly agents per project.

---

## Phase 7: GitHub Backup

**Athena does:**
1. Creates a private GitHub repo for automated backups (`athena-backups`)
2. Configures `scripts/full-backup.sh` to auto-push on every run
3. Adds backup to the daily 2am cron
4. Verifies first backup + push succeeds

Nothing is ever lost, workspaces, agent configs, memory files, and project state all back up to GitHub automatically.

---

## Done

```
ONBOARDING COMPLETE ✅
- Claude auth: working
- Discord: 7 channels live
- 7 workspace agents + 7 office agents
- Icarus is Paperclip CEO
- [N] projects briefed
- Crons scheduled
- All credentials stored, secrets scan clean

Say "brief the office on [topic]" to start.
```

---

## If Something Goes Wrong

Athena explains what failed, suggests a fix, waits for you, retries. She never skips a phase.
