# Claude Auth Setup

Without Claude auth, nothing works. Pick one of the 3 options below.

**Most people use Option A** (setup-token from your Claude subscription). If you need usage-based API billing, use Option B.

---

## Option A: Setup Token (Claude Subscription: Recommended)

Uses your existing Claude Pro/Team/Enterprise subscription. No separate API billing.

### How to get it

```bash
# 1. Install Claude Code CLI if you don't have it
npm install -g @anthropic-ai/claude-code

# 2. Log in (opens browser, one-time)
claude auth login

# 3. Generate the setup token
claude setup-token
```

This prints a long token. Copy it.

### Wire it into OpenClaw

```bash
# Option 1: During onboard (easiest — handles everything)
openclaw onboard --auth-choice setup-token

# Option 2: Standalone (if already onboarded)
openclaw models auth setup-token --provider anthropic
# Paste when prompted

# Option 3: If you generated the token on a different machine
openclaw models auth paste-token --provider anthropic
```

### Verify

```bash
openclaw models status    # Should show anthropic models ✓
openclaw doctor           # All green
```

### Token refresh

Setup-tokens can expire. If you see "OAuth token refresh failed":

```bash
# Just re-run on any machine with Claude CLI
claude setup-token
# Then paste into the gateway host
openclaw models auth paste-token --provider anthropic
```

---

## Option B: Anthropic API Key (Usage-Based Billing)

Pay per token. Best for production workloads where you want fine-grained cost control.

### How to get it

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up / log in
3. **API Keys** → **Create Key** → copy it (starts with `sk-ant-api03-...`)
4. **Settings** → **Billing** → add credit ($10 is enough to start)

### Wire it into OpenClaw

```bash
# Option 1: During onboard
openclaw onboard
# Choose: "Anthropic API key"
# Paste your key

# Option 2: Non-interactive
openclaw onboard --anthropic-api-key "$ANTHROPIC_API_KEY"

# Option 3: Store for daemon use
cat >> ~/.openclaw/.env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-api03-YOUR-KEY-HERE
EOF
```

### Verify

```bash
openclaw models status
openclaw doctor
```

### Key rotation (advanced)

OpenClaw supports multiple keys for rate-limit resilience:
```bash
# In ~/.openclaw/.env
ANTHROPIC_API_KEY=sk-ant-api03-primary
ANTHROPIC_API_KEY_2=sk-ant-api03-backup
```
Retries with next key on 429 rate-limit errors only.

---

## Option C: Claude CLI Backend

Uses the local `claude` binary directly. Your subscription auth, no API key needed.

```bash
# Requires Claude CLI already signed in
claude auth status  # Must show: authenticated

# Wire into OpenClaw
openclaw models auth login --provider anthropic --method cli --set-default

# Or during onboard
openclaw onboard --auth-choice anthropic-cli
```

**Limitations:** Text in/out only. No OpenClaw streaming. Best for single-user personal gateway.

---

## After Auth: Enable Prompt Caching

Prompt caching cuts input costs by ~97% after the first turn. Add to your config:

```json5
// In ~/.openclaw/openclaw.json
{
  agents: {
    defaults: {
      models: {
        "anthropic/claude-sonnet-4-6": {
          params: { cacheRetention: "short" }  // 5min cache
        }
      }
    }
  }
}
```

| Setting | Duration | When to Use |
|---------|----------|-------------|
| `"short"` | 5 min | Default, good for most use |
| `"long"` | 1 hour | Deep research sessions |
| `"none"` | No cache | Bursty, low-reuse agents |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "OAuth token refresh failed" | Re-run `claude setup-token`, paste with `openclaw models auth paste-token --provider anthropic` |
| "No API key found for provider anthropic" | Auth is per-agent. Run `openclaw onboard` or paste token again. |
| "This credential is only authorized for Claude Code" | Use an API key (Option B) instead of setup-token |
| 401 errors | Key expired/revoked. Check `openclaw models status`. |
| "Rate limit" | Add a second API key, or wait. |

---

*Get auth working first. `openclaw onboard` handles most of this automatically.*
