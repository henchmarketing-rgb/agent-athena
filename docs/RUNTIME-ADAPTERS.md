# Runtime Adapters

Athena runs on either of the two main open-source agent runtimes: **OpenClaw** or **Hermes Agent**. Both deliver the full Athena value (14 personas, escalation pipeline, nightly automation, Paperclip office team). They differ in **how** that team shows up in front of you.

You pick at install time. Re-run `bash install.sh --reset` to switch later.

---

## Quick comparison

| | OpenClaw (default) | Hermes Agent |
|---|---|---|
| Topology | Multi-agent, multi-channel | Single-profile, multi-persona |
| Discord | One bot, 14 channels — each channel = one persona | One bot, one active persona — Athena fronts |
| Conversation style | Live multi-agent chat | Autonomous orchestration |
| Other personas | Always-on, always-listening in their channel | Loaded as skills, dispatched by Athena via cron + Paperclip |
| Self-improvement | Manual | Hermes generates new skills from experience |
| Stack | Node.js | Python |
| Install | `npm install -g openclaw` | `git clone` + `setup-hermes.sh` (uses uv) |
| Home dir | `~/.openclaw/` | `~/.hermes/` |
| Workspaces | `~/.openclaw/workspaces/<agent>/` | `~/.hermes/workspaces/<agent>/` |
| Cron | `openclaw cron add` | `hermes cron add` |
| LLM routing | Direct provider (Anthropic / OpenAI / Google / Ollama / custom) | OpenRouter by default (one key, many models) |
| License (runtime) | OpenClaw license | MIT |

The workspace `.md` files (`SOUL.md`, `IDENTITY.md`, `AGENTS.md`, `MEMORY.md`, `CURRENT.md`, `HEARTBEAT.md`, `CLAUDE.md`) are **runtime-agnostic**. The same content drives the same persona on both runtimes.

---

## When to pick OpenClaw

You want:

- A live, multi-agent Discord experience where you can DM each persona in their channel and they respond independently
- Conversational delegation ("Argus, check the sites" in #argus, "Forge, build me a feature" in #forge)
- The full 14-channel social model — visibility into what each agent is doing in their own dedicated thread
- A Node.js stack that integrates cleanly with the rest of the Athena tooling

This is the default. It's the topology Athena was designed around.

## When to pick Hermes Agent

You want:

- A single self-improving agent that grows new skills from experience
- Autonomous-first orchestration — Athena runs the team via cron + Paperclip, you don't talk to each persona directly
- One Discord channel and one inbox to monitor instead of fourteen
- OpenRouter routing (one API key for every major model, easy to swap mid-session)
- A Python stack you can extend with the broader Hermes plugin ecosystem (200+ skills, model providers, MCP server, plugin system)

Hermes is also the right choice if you're already running it and want to add Athena's persona framework + escalation pipeline + Paperclip office team without changing runtime.

---

## What stays identical

Regardless of runtime:

- The 14-persona team (Athena, Poseidon, Icarus, Forge, Argus, Heracles, Recovery + 7 office agents)
- Workspace `.md` content (`SOUL.md`, `IDENTITY.md`, `AGENTS.md`, `MEMORY.md`, `CURRENT.md`, `HEARTBEAT.md`, `CLAUDE.md`)
- Paperclip task layer (office team task assignment + heartbeat)
- The escalation contract (Argus → Heracles → Recovery → Athena)
- Nightly pipeline patterns (`scripts/nightly-report.js`, `site-health.js`, `session-cleanup.js`, `weekly-compaction.js`, `cost-tracker.js`)
- Operator tools (`scripts/create-project.js`, `discord-setup.js`, `paperclip-setup.js`)
- Documentation, security model, license

The runtime adapter is a thin layer that translates Athena's pipeline into the chosen runtime's CLI surface and storage layout.

---

## What's different per runtime

### OpenClaw

- One Discord bot multiplexes across 14 channels via channel-level `systemPrompt` overrides in `~/.openclaw/openclaw.json`
- Each persona has a dedicated channel; channel ID → persona binding lives in `~/.env.secrets`
- `openclaw gateway start` spawns one process serving all 14 personas
- `openclaw cron add` registers nightly jobs against the same gateway

### Hermes

- One Hermes profile at `~/.hermes/` runs Athena as the active persona
- `~/.hermes/cli-config.yaml` references the Athena workspace `.md` files as the system prompt
- The other 13 personas live as workspace dirs that Athena dispatches to via cron jobs (`hermes cron add --workdir ~/.hermes/workspaces/poseidon ...`) or via Paperclip task assignment
- Discord routing: one bot, one active persona at a time. The other personas surface their work via posts FROM Athena, references in nightly reports, or Paperclip task updates
- Multi-profile is supported but optional: `node scripts/hermes-setup.js --persona poseidon` swaps which persona is active. For full 14-channel parity, run multiple Hermes profiles via `HERMES_HOME`

---

## Switching runtimes

Re-run install:

```bash
cd ~/Apps/agent-athena
bash install.sh --reset
# Pick a different runtime at Step 7
```

`--reset` wipes `~/.athena-install-state` but leaves `~/.env.secrets` intact (your Discord tokens, API keys, channel IDs are preserved). Workspaces under the old runtime's home dir stay too — copy them over manually if needed:

```bash
# Going OpenClaw → Hermes
cp -r ~/.openclaw/workspaces/* ~/.hermes/workspaces/

# Going Hermes → OpenClaw
cp -r ~/.hermes/workspaces/* ~/.openclaw/workspaces/
```

---

## Adapter manifests

Each runtime has a JSON manifest under `config/runtime/` that documents the binary, install method, command surface, and required env vars:

- [`config/runtime/openclaw.json`](../config/runtime/openclaw.json)
- [`config/runtime/hermes.json`](../config/runtime/hermes.json)

These are read by `install.sh` and `scripts/hermes-setup.js` to drive the integration. Adding a third runtime in the future means: write a manifest, write a setup script, add an `install.sh` Step 7 case.

---

## FAQ

**Can I run both runtimes side-by-side?**
Yes, but it's not the default. Both runtimes share the same `~/.env.secrets` so they can both bind to the same Discord bot — but Discord won't route messages to two listening processes deterministically. In practice, run one at a time.

**Does Paperclip work on Hermes?**
Yes. Paperclip is runtime-agnostic. The 7 office agents are registered against Paperclip's API regardless of runtime, and they execute via heartbeat polling. `scripts/paperclip-setup.js` is the same on both paths.

**Will the workspace `.md` files I edit on OpenClaw work on Hermes?**
Yes. The content is identical. Only the location differs (`~/.openclaw/workspaces/` vs `~/.hermes/workspaces/`). `bash install.sh --reset` and pick the other runtime; the install copies workspaces into the new home dir.

**Which runtime is more stable?**
OpenClaw is the original Athena topology — most testing, most field use. Hermes Agent v0.12+ is production-ready but newer to Athena. Both pass our CI fresh-box install tests on Ubuntu and macOS.

**Will Athena keep working when OpenClaw or Hermes update?**
The adapter manifests pin minimum versions. Breaking upstream changes would surface in the install tests first; we'd update the adapter, ship a new Athena release. Workspace `.md` files (the actual Athena product) are unaffected.
