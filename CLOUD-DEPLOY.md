# Cloud Deployment Guide
> Run your agent 24/7, not just when your laptop is open.

By default OpenClaw runs on your local machine. This is fine for getting started, but it means:
- Nightly crons only fire if your machine is on and awake
- You can only interact when your laptop is accessible
- Crashes or sleeps break agent continuity

Moving to a cloud VPS solves all three. Your agent runs independently, costs ~$5/month, and you interact via Discord from anywhere.

## Three deployment options

| Option | Cost | Setup time | Ops burden | Pick if… |
|---|---|---|---|---|
| **A — Hetzner VPS** | ~$5/mo | 30 min | You manage updates | You want full control, cheapest reliable always-on |
| **B — Fly.io** | $0–$5/mo | 10 min | None | You want zero infra, free tier works for one operator |
| **C — Render.com** | $0–$7/mo | 10 min | None | You prefer a GitHub-blueprint flow over CLI |

Templates for B and C live in `deploy/`:
- [`deploy/fly.toml`](./deploy/fly.toml) — copy to repo root, edit app name, `fly deploy`
- [`deploy/render.yaml`](./deploy/render.yaml) — Render dashboard reads it on Blueprint connect

---

## Option A: Hetzner VPS (recommended)

**Best for:** Full control, cheapest, most reliable for always-on workloads.
**Cost:** ~€4.51/mo (CX22: 2 vCPU, 4GB RAM, 40GB SSD)

### 1. Create the server

1. Sign up at [hetzner.com](https://hetzner.com)
2. Create a new server: **Ubuntu 24.04**, **CX22** (smallest viable size)
3. Add your SSH public key during creation
4. Note the server IP

### 2. Install Docker

```bash
ssh root@YOUR_SERVER_IP

# Install Docker
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin

# Verify
docker --version
```

### 3. Deploy OpenClaw

```bash
# Create persistent state directories
mkdir -p /data/.openclaw /data/workspace

# Clone OpenClaw (for docker-compose.yml)
git clone https://github.com/openclaw/openclaw /opt/openclaw
cd /opt/openclaw

# Create environment file
cat > .env << 'EOF'
ANTHROPIC_API_KEY=your-anthropic-key-here
DISCORD_TOKEN=your-discord-bot-token-here
OPENCLAW_STATE_DIR=/data/.openclaw
OPENCLAW_WORKSPACE_DIR=/data/workspace
GEMINI_API_KEY=your-gemini-key-here
# Add other API keys as needed
EOF

chmod 600 .env

# Start
docker compose up -d
```

### 4. Verify it's running

```bash
docker compose logs -f   # Watch logs
curl localhost:18789/health   # Should return {"status":"ok"}
```

### 5. Set up workspace sync

```bash
cd /data/workspace
git clone https://github.com/YOUR_ORG/your-workspace-repo.git .
```

Add a cron to auto-pull updates:
```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * cd /data/workspace && git pull --ff-only origin main 2>/dev/null") | crontab -
```

### 6. Persist across reboots

```bash
# Auto-start on server reboot
docker compose enable   # or: systemctl enable docker
cd /opt/openclaw && docker compose up -d
```

---

## Option B: Render (one-click deploy)

**Best for:** Minimal setup, no server management.
**Cost:** $7/mo Starter (free tier has cold starts, not suitable for always-on)

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/openclaw/openclaw)

1. Click the button above
2. Fill in environment variables (Anthropic key, Discord token, etc.)
3. Deploy, Render handles everything else

**Note:** Free tier spins down after inactivity. Upgrade to Starter ($7/mo) for always-on.

---

## Option C: Fly.io

**Best for:** Low-latency, global edge deployment.
**Cost:** ~$5/mo

```bash
# Install flyctl
brew install flyctl
fly auth login

# Deploy from openclaw repo
git clone https://github.com/openclaw/openclaw
cd openclaw
fly launch
fly secrets set ANTHROPIC_API_KEY=your-key DISCORD_TOKEN=your-token
fly deploy
```

---

## After deploying

### Update Discord bot routing

Your Discord bot token is the same, no change needed. The bot connects to Discord, OpenClaw connects to Discord. Discord is the bridge. Both work simultaneously.

If you want to **only** use the cloud gateway (not your local Mac):
- Stop the local gateway: `openclaw gateway stop`
- Cloud gateway handles all messages

If you want **both** running (local + cloud):
- Not recommended, messages will be handled by whichever responds first

### Sync workspace files

The cloud server and your Mac share the same workspace via git (your workspace repo).

**Mac → Cloud:** Make changes locally, `git push`, cloud pulls automatically (via cron)
**Cloud → Mac:** `git pull` on your Mac after any nightly run that wrote files

### Migrate your crons

Crons are stored in `~/.openclaw/cron/jobs.json`. Copy this to the cloud:

```bash
scp ~/.openclaw/cron/jobs.json root@YOUR_SERVER_IP:/data/.openclaw/cron/jobs.json
```

Then restart the cloud gateway to pick them up.

---

## Security notes

- Never put API keys in `git`, use environment variables on the server
- Use a gateway token (`openclaw gateway token`) if exposing the control port
- Keep your cloud server updated: `apt update && apt upgrade`
- The VPS should run OpenClaw only, no personal accounts, no browser, no passwords

---

## Costs summary

| Provider | Monthly cost | Cold starts | Setup time |
|----------|-------------|-------------|------------|
| Hetzner CX22 | ~$4.50 | None | 20 min |
| Render Starter | $7.00 | None | 5 min |
| Fly.io | ~$5.00 | None | 15 min |
| Render Free | $0 | Yes (breaks nightlies) | 5 min |

**Recommendation:** Hetzner for cost+control, Render Starter for ease.

---

## Option B: Fly.io (template)

`deploy/fly.toml` is a ready-to-use Fly Machines template. It provisions:
- One shared-CPU VM (1 GB RAM) in the region you pick
- A 3 GB persistent volume mounted at `/data`, with `HOME=/data/home` so `~/.openclaw` survives deploys
- HTTPS termination on port 443 with auto-redirect from 80
- Auto-restart on machine boot, no auto-stop on idle (we want 24/7)

Setup:

```bash
brew install flyctl                       # or: curl -L https://fly.io/install.sh | sh
fly auth login

cp deploy/fly.toml fly.toml               # local copy you can edit
# Edit fly.toml: replace <your-app-name> with a unique name
fly apps create <your-app-name>
fly volumes create athena_data --region <region> --size 3

# Set the secrets — these mirror ~/.env.secrets:
fly secrets set DISCORD_BOT_TOKEN="..."
fly secrets set ANTHROPIC_API_KEY="..."   # or your model provider's key
fly secrets set BRAVE_SEARCH_API_KEY="..."
fly secrets set GITHUB_TOKEN="ghp_..."
fly secrets set DISCORD_GUILD_ID="..."
fly secrets set DISCORD_ATHENA_CHANNEL_ID="..."
# ... and the other 6 channel IDs
fly secrets set ALERT_WEBHOOK_URL="https://hc-ping.com/<uuid>"

fly deploy
fly logs                                  # watch the gateway boot
```

The `release_command` runs `bash install.sh --resume` on every deploy, so workspace files + state file get refreshed.

## Option C: Render.com (template)

`deploy/render.yaml` is a Render Blueprint. Push your fork to GitHub, then in the Render dashboard: **New → Blueprint → connect repo**. Render reads `render.yaml` and provisions the web service + persistent disk.

Set the same environment variables in the Render dashboard (or via the Render API). The blueprint marks each one as `sync: false` so they're never committed to git.

Free tier sleeps after 15 min idle — fine for testing, breaks nightlies. Upgrade to Starter ($7/mo) for 24/7.

---

## Real-time alerting (any deployment)

Set `ALERT_WEBHOOK_URL` in your secrets (any of the cloud options above support env vars). Use `scripts/alert.js`:

```bash
# Heartbeat — Argus + Heracles call this on each cycle
node scripts/alert.js --heartbeat argus
node scripts/alert.js --heartbeat heracles

# Incident — fires when something goes wrong
node scripts/alert.js --incident critical --message "Site down: example.com"
```

Free providers that work out of the box:
- **Healthchecks.io** — `https://hc-ping.com/<uuid>`. POST/GET pings the heartbeat; appending `/fail` registers an incident.
- **UptimeRobot heartbeat** — `https://heartbeat.uptimerobot.com/<id>`.
- **Better Stack heartbeat** — `https://uptime.betterstack.com/api/v1/heartbeat/<token>`.

If pings stop, the service alerts you (email / Slack / SMS / push, your choice).
