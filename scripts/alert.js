#!/usr/bin/env node

// =============================================================================
// scripts/alert.js
// =============================================================================
//
// Heartbeat-style alerting endpoint adapter. Pings an external monitoring
// service (UptimeRobot, Healthchecks.io, Better Stack, Pingdom — anything
// with a webhook URL) so an external alarm fires if Athena stops sending
// signals.
//
// Two modes:
//   1. Heartbeat:  --heartbeat <name>
//      Emits a "still alive" ping. Used by Argus on every poll, and by
//      Heracles after the morning summary posts. If pings stop, the
//      external service alerts the operator.
//
//   2. Incident:   --incident <severity> --message "<text>"
//      Posts a fail signal. Used by Heracles when a nightly run scores FAIL,
//      by Argus on CRITICAL.
//
// Configuration: set ALERT_WEBHOOK_URL in ~/.env.secrets. Format:
//   - Healthchecks.io:    https://hc-ping.com/<uuid>
//   - UptimeRobot:        https://heartbeat.uptimerobot.com/<id>
//   - Better Stack:       https://uptime.betterstack.com/api/v1/heartbeat/<token>
//   - Custom:             any URL that accepts POST/GET on heartbeat
//
// Per-component endpoints (optional, overrides ALERT_WEBHOOK_URL):
//   ALERT_WEBHOOK_ARGUS, ALERT_WEBHOOK_HERACLES, ALERT_WEBHOOK_FORGE
//
// Usage:
//   node scripts/alert.js --heartbeat argus
//   node scripts/alert.js --heartbeat heracles
//   node scripts/alert.js --incident critical --message "Site down: heysusan.online"
//   node scripts/alert.js --self-test     # post a test heartbeat
// =============================================================================

const fs = require("fs");
const os = require("os");
const path = require("path");

const SECRETS_FILE = path.join(os.homedir(), ".env.secrets");
const args = process.argv.slice(2);

function getFlag(name) {
  const i = args.indexOf(name);
  return i !== -1 ? args[i + 1] : null;
}

const HEARTBEAT_NAME = getFlag("--heartbeat");
const INCIDENT_SEVERITY = getFlag("--incident");
const MESSAGE = getFlag("--message") || "";
const SELF_TEST = args.includes("--self-test");

// Load secrets
function loadSecrets() {
  if (!fs.existsSync(SECRETS_FILE)) return {};
  const out = {};
  for (const line of fs.readFileSync(SECRETS_FILE, "utf8").split("\n")) {
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (value.startsWith("'") && value.endsWith("'")) value = value.slice(1, -1);
    else if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    out[key] = value;
  }
  return out;
}

function pickWebhook(name, env) {
  if (name) {
    const perComponent = env[`ALERT_WEBHOOK_${name.toUpperCase()}`];
    if (perComponent) return perComponent;
  }
  return env.ALERT_WEBHOOK_URL;
}

(async () => {
  const env = { ...process.env, ...loadSecrets() };

  if (SELF_TEST) {
    const url = env.ALERT_WEBHOOK_URL;
    if (!url) {
      console.error("ALERT_WEBHOOK_URL not set in ~/.env.secrets. Set one to run a self-test.");
      process.exit(1);
    }
    console.log(`Self-test → ${url}`);
    const res = await fetch(url, { method: "POST", body: "athena-alert self-test" });
    console.log(`HTTP ${res.status}`);
    process.exit(res.ok ? 0 : 1);
  }

  if (HEARTBEAT_NAME) {
    const url = pickWebhook(HEARTBEAT_NAME, env);
    if (!url) {
      // Heartbeat without a webhook is a no-op — the alerting is opt-in,
      // so a missing config is not an error.
      process.exit(0);
    }
    try {
      const res = await fetch(url, { method: "GET" });
      if (!res.ok) {
        console.error(`Heartbeat ${HEARTBEAT_NAME} HTTP ${res.status}`);
        process.exit(1);
      }
    } catch (err) {
      console.error(`Heartbeat ${HEARTBEAT_NAME} failed: ${err.message}`);
      process.exit(1);
    }
    process.exit(0);
  }

  if (INCIDENT_SEVERITY) {
    const url = pickWebhook(null, env);
    if (!url) {
      console.error("ALERT_WEBHOOK_URL not set; cannot deliver incident alert.");
      process.exit(2);
    }
    const sev = INCIDENT_SEVERITY.toLowerCase();
    if (!["low", "medium", "high", "critical"].includes(sev)) {
      console.error("--incident severity must be one of: low, medium, high, critical");
      process.exit(2);
    }
    // Most heartbeat services treat a /fail or /<status_code>/<message> path
    // as an incident. Healthchecks.io: GET /<uuid>/fail. We post the message
    // as the body so it appears in the alert email.
    const failUrl = url.replace(/\/?$/, "") + "/fail";
    const body = `[${sev.toUpperCase()}] ${MESSAGE || "(no message)"}`;
    try {
      const res = await fetch(failUrl, { method: "POST", body });
      if (!res.ok) {
        // Some providers don't have a /fail endpoint; fall back to plain POST.
        await fetch(url, { method: "POST", body });
      }
    } catch (err) {
      console.error(`Incident alert failed: ${err.message}`);
      process.exit(1);
    }
    process.exit(0);
  }

  console.error("usage: node scripts/alert.js --heartbeat <name>");
  console.error("       node scripts/alert.js --incident <severity> --message '<text>'");
  console.error("       node scripts/alert.js --self-test");
  process.exit(2);
})().catch((err) => {
  console.error(`Error: ${err.message || err}`);
  process.exit(1);
});
