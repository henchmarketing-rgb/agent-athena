#!/usr/bin/env node

// =============================================================================
// scripts/discord-setup.js
// =============================================================================
// Creates the 7 Athena agent channels in your Discord server, posts pinned
// intro messages, and writes channel IDs back to ~/.env.secrets.
//
// Idempotent: re-running detects existing channels by name and updates IDs
// without recreating.
//
// Usage:
//   node scripts/discord-setup.js                # interactive
//   node scripts/discord-setup.js --dry-run      # show what would happen
//   node scripts/discord-setup.js --no-pin       # skip pinning intro messages
//
// Required env (loaded from ~/.env.secrets):
//   DISCORD_BOT_TOKEN, DISCORD_GUILD_ID
// =============================================================================

const fs = require("fs");
const os = require("os");
const path = require("path");

let Client, GatewayIntentBits, ChannelType, PermissionFlagsBits;
try {
  ({ Client, GatewayIntentBits, ChannelType, PermissionFlagsBits } = require("discord.js"));
} catch {
  console.error("\n  discord.js is not installed.");
  console.error("  Install in this repo:  npm install");
  console.error("  Or globally:          npm install -g discord.js\n");
  process.exit(1);
}

const SECRETS_FILE = path.join(os.homedir(), ".env.secrets");
const DRY_RUN = process.argv.includes("--dry-run");
const SKIP_PIN = process.argv.includes("--no-pin");

// -----------------------------------------------------------------------------
// Channel definitions
// -----------------------------------------------------------------------------

const CHANNELS = [
  {
    name: "🦉〡athena",
    secretKey: "DISCORD_ATHENA_CHANNEL_ID",
    intro:
      "🦉 **Athena** | Coordinator\n\n" +
      "I route work, run onboarding, and own weekly memory compaction.\n" +
      "Brief me on a project, ask for status, or tell me what to ship.\n\n" +
      "Other channels you have:\n" +
      "🌊 #poseidon, 🪶 #icarus, ⚡ #heracles, ⚒️ #forge, 👁️ #argus, 🛡️ #recovery",
  },
  {
    name: "🌊〡poseidon",
    secretKey: "DISCORD_POSEIDON_CHANNEL_ID",
    intro:
      "🌊 **Poseidon** | Deep Research\n\n" +
      "I run multi-source research: web search, document analysis, competitive intelligence.\n" +
      "Ask me to investigate, summarise, or build a brief.",
  },
  {
    name: "🪶〡icarus",
    secretKey: "DISCORD_ICARUS_CHANNEL_ID",
    intro:
      "🪶 **Icarus** | Strategy + Paperclip CEO\n\n" +
      "I turn briefs into structured tasks for the office team.\n" +
      "I create tasks via Paperclip API, assign agents, and monitor progress.\n" +
      "I have exec access; I will ask before destructive actions.",
  },
  {
    name: "⚡〡heracles",
    secretKey: "DISCORD_HERACLES_CHANNEL_ID",
    intro:
      "⚡ **Heracles** | Night Oversight + QC\n\n" +
      "Every morning I score nightly agent runs as PASS, PARTIAL, or FAIL.\n" +
      "Missing reports auto-fail. Read my morning summary before standup.",
  },
  {
    name: "⚒️〡forge",
    secretKey: "DISCORD_FORGE_CHANNEL_ID",
    intro:
      "⚒️ **Forge** | Build + Deploy\n\n" +
      "I run builds, run tests, and deploy. I block on failing builds.\n" +
      "I have exec access. I will ask before destructive actions or production deploys.",
  },
  {
    name: "👁️〡argus",
    secretKey: "DISCORD_ARGUS_CHANNEL_ID",
    intro:
      "👁️ **Argus** | Monitoring + Health\n\n" +
      "I watch site health, cron health, session bloat, secrets exposure, and cost.\n" +
      "I escalate critical issues here and to #recovery.",
  },
  {
    name: "🛡️〡recovery",
    secretKey: "DISCORD_RECOVERY_CHANNEL_ID",
    intro:
      "🛡️ **Recovery** | Emergency Failsafe\n\n" +
      "Use this channel when an agent is unresponsive, a deploy broke production,\n" +
      "or a process is runaway.\n\n" +
      "Recovery has elevated permissions. Per SECURITY.md, restrict trigger access\n" +
      "to operators only by adding a Discord role check before going live.",
  },
];

// -----------------------------------------------------------------------------
// Secrets file helpers (read existing, merge new values)
// -----------------------------------------------------------------------------

function loadSecrets() {
  if (!fs.existsSync(SECRETS_FILE)) return {};
  const out = {};
  for (const line of fs.readFileSync(SECRETS_FILE, "utf8").split("\n")) {
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    // Strip shell-style quoting if install.sh wrote it that way.
    if (value.startsWith("'") && value.endsWith("'")) value = value.slice(1, -1);
    else if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    out[key] = value;
  }
  return out;
}

function setSecret(key, value) {
  if (DRY_RUN) {
    console.log(`  [dry-run] would set ${key}=${value}`);
    return;
  }
  let lines = [];
  if (fs.existsSync(SECRETS_FILE)) {
    lines = fs.readFileSync(SECRETS_FILE, "utf8").split("\n").filter((l) => !l.startsWith(`${key}=`));
  } else {
    lines = ["# Athena secrets — managed by install.sh", "# Never commit this file to git.", ""];
  }
  // Quote with single quotes; escape any single quotes in the value.
  const quoted = `'${String(value).replace(/'/g, "'\\''")}'`;
  lines.push(`${key}=${quoted}`);
  fs.writeFileSync(SECRETS_FILE, lines.join("\n").replace(/\n+$/, "") + "\n", { mode: 0o600 });
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------

(async () => {
  const env = { ...process.env, ...loadSecrets() };
  const token = env.DISCORD_BOT_TOKEN;
  const guildId = env.DISCORD_GUILD_ID;

  if (!token) {
    console.error("\n  DISCORD_BOT_TOKEN not found in ~/.env.secrets or env.");
    console.error("  Run install.sh to set it up.\n");
    process.exit(1);
  }
  if (!guildId) {
    console.error("\n  DISCORD_GUILD_ID not found in ~/.env.secrets or env.");
    console.error("  Run install.sh to set it up.\n");
    process.exit(1);
  }

  console.log("\n  Connecting to Discord...");

  const client = new Client({ intents: [GatewayIntentBits.Guilds] });

  client.once("ready", async () => {
    try {
      const guild = await client.guilds.fetch(guildId);
      console.log(`  ✓ Connected. Server: ${guild.name}\n`);

      const allChannels = await guild.channels.fetch();

      for (const def of CHANNELS) {
        // Match on the visible channel name, ignoring leading emoji separators.
        const existing = allChannels.find((c) => c && c.name === def.name);

        let channel;
        if (existing) {
          console.log(`  • ${def.name} exists (id ${existing.id})`);
          channel = existing;
        } else if (DRY_RUN) {
          console.log(`  [dry-run] would create channel: ${def.name}`);
          continue;
        } else {
          console.log(`  + creating ${def.name}...`);
          channel = await guild.channels.create({
            name: def.name,
            type: ChannelType.GuildText,
          });
          console.log(`    created (id ${channel.id})`);
        }

        // Persist the channel ID so install.sh / openclaw config picks it up.
        setSecret(def.secretKey, channel.id);

        // Post pinned intro message if the channel has no pins yet.
        if (!SKIP_PIN && !DRY_RUN) {
          try {
            const pins = await channel.messages.fetchPinned();
            if (pins.size === 0) {
              const msg = await channel.send(def.intro);
              await msg.pin().catch((e) => {
                console.log(`    (could not pin: ${e.message})`);
              });
              console.log(`    posted + pinned intro`);
            } else {
              console.log(`    intro already pinned, skipping`);
            }
          } catch (e) {
            console.log(`    intro skipped: ${e.message}`);
          }
        }
      }

      console.log("\n  ✅ Discord setup complete.");
      console.log(`  Channel IDs written to ${SECRETS_FILE}`);
      console.log("  Restart the gateway to pick up changes:  openclaw gateway restart\n");
    } catch (err) {
      console.error(`\n  Error: ${err.message}\n`);
      console.error("  Common causes:");
      console.error("  - Bot is not in your server (re-run the OAuth invite URL)");
      console.error("  - Bot lacks 'Manage Channels' permission");
      console.error("  - DISCORD_GUILD_ID is wrong\n");
      process.exitCode = 1;
    } finally {
      client.destroy();
    }
  });

  client.on("error", (err) => {
    console.error(`\n  Discord client error: ${err.message}\n`);
    process.exitCode = 1;
    client.destroy();
  });

  await client.login(token);
})().catch((err) => {
  // Catch login failures (bad token, network) so Node doesn't surface a noisy
  // UnhandledPromiseRejection. Common causes: token revoked, expired, malformed.
  const msg = err && err.message ? err.message : String(err);
  console.error(`\n  Discord setup failed: ${msg}`);
  if (msg.toLowerCase().includes("token")) {
    console.error("  Likely cause: invalid or revoked bot token.");
    console.error("  Reset the token at https://discord.com/developers/applications,");
    console.error("  then update DISCORD_BOT_TOKEN in ~/.env.secrets.\n");
  } else {
    console.error("  Common causes: network, bot not in server, missing 'Manage Channels' permission.\n");
  }
  process.exit(1);
});
