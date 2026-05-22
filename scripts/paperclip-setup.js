#!/usr/bin/env node

// =============================================================================
// scripts/paperclip-setup.js
// =============================================================================
//
// Idempotent Paperclip setup. Replaces the legacy paperclip-setup.sh:
//   - Verifies Paperclip is running on PAPERCLIP_API_URL
//   - Reads PAPERCLIP_API_KEY (env, ~/.env.secrets, or --api-key)
//   - Gets or selects the company ID
//   - Creates Icarus (CEO) if missing — match by name
//   - Creates the 7 office agents if missing — match by name
//   - Installs the paperclip skill into each office workspace if missing
//   - Writes agent IDs back to ~/.env.secrets so other tooling can consume
//
// Usage:
//   node scripts/paperclip-setup.js                  # uses env / secrets
//   node scripts/paperclip-setup.js --api-key XXX    # explicit
//   node scripts/paperclip-setup.js --dry-run        # show plan, no writes
//   node scripts/paperclip-setup.js --no-skill       # skip skill install
// =============================================================================

const fs = require("fs");
const os = require("os");
const path = require("path");

const SECRETS_FILE = path.join(os.homedir(), ".env.secrets");
const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");
const NO_SKILL = args.includes("--no-skill");

const explicitKeyIndex = args.indexOf("--api-key");
const explicitKey = explicitKeyIndex !== -1 ? args[explicitKeyIndex + 1] : null;

// -----------------------------------------------------------------------------
// Office agent definitions (match the .sh script's roster)
// -----------------------------------------------------------------------------

const OFFICE_AGENTS = [
  { key: "copywriter",      name: "Copywriter",      role: "content",     title: "Brand Copywriter",       capabilities: "Blog posts, landing pages, email sequences, brand voice" },
  { key: "outreach",        name: "Outreach",        role: "outreach",    title: "Outreach Specialist",    capabilities: "Cold email, LinkedIn, follow-up sequences, partnership pitches" },
  { key: "analytics",       name: "Analytics",       role: "data",        title: "Data Analyst",           capabilities: "KPI tracking, dashboards, weekly reports, data summaries" },
  { key: "seo",             name: "SEO",             role: "seo",         title: "SEO Specialist",         capabilities: "Keyword research, technical audits, content briefs, meta copy" },
  { key: "social",          name: "Social",          role: "social",      title: "Social Media Manager",   capabilities: "Platform-specific posts, scheduling briefs, engagement" },
  { key: "ads",             name: "Ads",             role: "advertising", title: "Paid Media Specialist",  capabilities: "PPC copy, A/B variants, Meta/Google ads, landing page hooks" },
  { key: "visual-director", name: "Visual Director", role: "design",      title: "Art Director",           capabilities: "Asset specs, mood boards, brand guidelines, visual QA" },
];

// -----------------------------------------------------------------------------
// Secrets file helpers
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
  const quoted = `'${String(value).replace(/'/g, "'\\''")}'`;
  lines.push(`${key}=${quoted}`);
  fs.writeFileSync(SECRETS_FILE, lines.join("\n").replace(/\n+$/, "") + "\n", { mode: 0o600 });
}

// -----------------------------------------------------------------------------
// Paperclip API client
// -----------------------------------------------------------------------------

class PaperclipClient {
  constructor(baseUrl, apiKey) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
    this.apiKey = apiKey;
  }

  async request(method, urlPath, body) {
    const url = `${this.baseUrl}${urlPath}`;
    const init = {
      method,
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
    };
    if (body !== undefined) init.body = JSON.stringify(body);

    const res = await fetch(url, init);
    const text = await res.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch { /* not json */ }
    if (!res.ok) {
      const msg = (json && (json.message || json.error)) || text || res.statusText;
      throw new Error(`${method} ${urlPath} → HTTP ${res.status}: ${msg}`);
    }
    return json;
  }

  health()                              { return this.request("GET",  "/health"); }
  listCompanies()                       { return this.request("GET",  "/api/companies"); }
  listAgents(companyId)                 { return this.request("GET",  `/api/companies/${companyId}/agents`); }
  createAgent(companyId, agentBody)     { return this.request("POST", `/api/companies/${companyId}/agents`, agentBody); }
}

// -----------------------------------------------------------------------------
// Skill installation (mirrors the .sh logic)
// -----------------------------------------------------------------------------

function findSkillSource() {
  const candidates = [
    path.join(os.homedir(), "Apps/paperclip/skills/paperclip"),
    "/tmp/paperclip/skills/paperclip",
    path.join(os.homedir(), ".openclaw/skills/paperclip"),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c) && fs.statSync(c).isDirectory()) return c;
  }
  return null;
}

function copyDirRecursive(src, dst) {
  if (!fs.existsSync(dst)) fs.mkdirSync(dst, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(s, d);
    } else {
      fs.copyFileSync(s, d);
    }
  }
}

function installSkillForAgent(skillSrc, agentKey, workspaceBase) {
  const dest = path.join(workspaceBase, agentKey, "skills/paperclip");
  if (fs.existsSync(dest)) {
    console.log(`  • ${agentKey}: skill already installed`);
    return false;
  }
  if (DRY_RUN) {
    console.log(`  [dry-run] would copy ${skillSrc} → ${dest}`);
    return true;
  }
  copyDirRecursive(skillSrc, dest);
  console.log(`  + ${agentKey}: skill installed`);
  return true;
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------

(async () => {
  const env = { ...process.env, ...loadSecrets() };
  const apiUrl = env.PAPERCLIP_API_URL || "http://127.0.0.1:3100";
  const apiKey = explicitKey || env.PAPERCLIP_API_KEY;

  console.log(`\n  Paperclip Agent Setup`);
  console.log(`  API: ${apiUrl}`);
  if (DRY_RUN) console.log(`  Mode: dry-run (no writes)\n`);
  else console.log("");

  if (!apiKey) {
    console.error("  PAPERCLIP_API_KEY not set.");
    console.error("  Pass via --api-key, or set PAPERCLIP_API_KEY in ~/.env.secrets.");
    console.error("  Get one from your Paperclip dashboard or `paperclipai context show`.\n");
    process.exit(1);
  }

  const client = new PaperclipClient(apiUrl, apiKey);

  // Preflight
  try {
    await client.health();
    console.log("  ✓ Paperclip is running");
  } catch (e) {
    console.error(`  ✗ Paperclip not responding: ${e.message}`);
    console.error("  Start it: pm2 start ecosystem.config.js  (then re-run this script)\n");
    process.exit(1);
  }

  // Company
  const companies = await client.listCompanies();
  if (!Array.isArray(companies) || companies.length === 0) {
    console.error("  ✗ No company found in Paperclip. Run 'paperclipai onboard' first.\n");
    process.exit(1);
  }
  const company = companies[0];
  const companyId = company.id;
  console.log(`  ✓ Company: ${company.name || companyId} (${companyId})`);
  setSecret("PAPERCLIP_COMPANY_ID", companyId);

  // Existing agents
  const existing = await client.listAgents(companyId);
  const byName = new Map(existing.map((a) => [a.name, a]));

  // Icarus (CEO)
  let icarus = byName.get("Icarus");
  if (icarus) {
    console.log(`  • Icarus exists (${icarus.id})`);
  } else if (DRY_RUN) {
    console.log("  [dry-run] would create Icarus (CEO)");
    icarus = { id: "DRY-RUN-ICARUS-ID" };
  } else {
    icarus = await client.createAgent(companyId, {
      name: "Icarus",
      role: "ceo",
      title: "Strategy & Task Delegation",
      capabilities: "Strategy, roadmaps, positioning, decision frameworks. Creates tasks and assigns to office agents.",
      adapterType: "openclaw_gateway",
      adapterConfig: {},
      budgetMonthlyCents: 10000,
    });
    console.log(`  + Icarus created (${icarus.id})`);
  }
  setSecret("PAPERCLIP_ICARUS_AGENT_ID", icarus.id);

  // Office agents
  const workspaceBase = path.join(os.homedir(), ".openclaw/workspaces/office");
  console.log(`\n  Office agents (workspaces: ${workspaceBase})`);

  let created = 0;
  let kept = 0;
  for (const def of OFFICE_AGENTS) {
    let agent = byName.get(def.name);
    if (agent) {
      console.log(`  • ${def.name}: exists (${agent.id})`);
      kept++;
    } else if (DRY_RUN) {
      console.log(`  [dry-run] would create ${def.name}`);
      agent = { id: `DRY-RUN-${def.key.toUpperCase()}-ID` };
      created++;
    } else {
      agent = await client.createAgent(companyId, {
        name: def.name,
        role: def.role,
        title: def.title,
        capabilities: def.capabilities,
        reportsTo: icarus.id,
        adapterType: "claude_local",
        adapterConfig: {
          cwd: path.join(workspaceBase, def.key),
          model: "claude-sonnet-4-6",
          dangerouslySkipPermissions: false,
          maxTurnsPerRun: 20,
          timeoutSec: 300,
        },
        budgetMonthlyCents: 5000,
      });
      console.log(`  + ${def.name}: created (${agent.id})`);
      created++;
    }
    setSecret(`PAPERCLIP_${def.key.toUpperCase().replace(/-/g, "_")}_AGENT_ID`, agent.id);
  }

  console.log(`\n  Result: ${created} created, ${kept} already existed`);

  // Skill install
  if (NO_SKILL) {
    console.log("\n  --no-skill: skipping paperclip skill installation");
  } else {
    console.log("\n  Installing paperclip skill into office workspaces...");
    const skillSrc = findSkillSource();
    if (!skillSrc) {
      console.log("  ⚠  Paperclip skill source not found. Install manually:");
      console.log("     cp -r /path/to/paperclip/skills/paperclip ~/.openclaw/workspaces/office/[agent]/skills/");
    } else {
      console.log(`  Source: ${skillSrc}`);
      let installs = 0;
      for (const def of OFFICE_AGENTS) {
        if (installSkillForAgent(skillSrc, def.key, workspaceBase)) installs++;
      }
      console.log(`  Skill: installed in ${installs}, already-present in ${OFFICE_AGENTS.length - installs}`);
    }
  }

  console.log("\n  ✅ Paperclip setup complete.");
  console.log(`     Company ID, Icarus ID, and agent IDs written to ${SECRETS_FILE}`);
  console.log("     Restart the OpenClaw gateway to pick up changes:  openclaw gateway restart\n");
})().catch((err) => {
  console.error(`\n  Error: ${err.message || err}\n`);
  process.exit(1);
});
