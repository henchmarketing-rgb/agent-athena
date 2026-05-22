#!/usr/bin/env node

// =============================================================================
// scripts/create-project.js
// =============================================================================
//
// Scaffolds a new project for the Athena system to manage. Creates:
//
//   ~/.openclaw/workspaces/projects/<slug>/
//     AGENT-BRIEF.md       — what the nightly agent should work on
//     GOTCHAS.md           — known failure patterns, shared across agents
//     NIGHTLY-NOTES.md     — per-project nightly run log
//     CURRENT.md           — live project state
//     CLAUDE.md            — Claude Code context for this project
//     memory/              — daily memory files
//
// Optionally registers a Paperclip "goal" (project) under the company so
// office agents can attach tasks to it. Requires Paperclip running with a
// valid PAPERCLIP_API_KEY in ~/.env.secrets.
//
// Usage:
//   node scripts/create-project.js <name>                  # interactive
//   node scripts/create-project.js <name> --no-paperclip   # local files only
//   node scripts/create-project.js <name> --repo <url>     # set repo up-front
//   node scripts/create-project.js <name> --dry-run
//
// Examples:
//   node scripts/create-project.js "Hey Susan"
//   node scripts/create-project.js my-saas --repo https://github.com/me/my-saas
// =============================================================================

const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");

const SECRETS_FILE = path.join(os.homedir(), ".env.secrets");
const PROJECTS_BASE = path.join(os.homedir(), ".openclaw/workspaces/projects");

// -----------------------------------------------------------------------------
// CLI parsing
// -----------------------------------------------------------------------------

const args = process.argv.slice(2);
const DRY_RUN = args.includes("--dry-run");
const NO_PAPERCLIP = args.includes("--no-paperclip");

function getFlag(name) {
  const i = args.indexOf(name);
  return i !== -1 ? args[i + 1] : null;
}

const REPO_URL = getFlag("--repo");
const RAW_NAME = args.find((a) => !a.startsWith("--") && a !== REPO_URL && (args.indexOf("--repo") === -1 || args.indexOf(a) !== args.indexOf("--repo") + 1));

if (!RAW_NAME) {
  console.error("\n  usage: node scripts/create-project.js <name> [--repo <url>] [--no-paperclip] [--dry-run]\n");
  process.exit(2);
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

function slugify(s) {
  return s.toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

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

function writeFile(p, content) {
  if (DRY_RUN) {
    console.log(`  [dry-run] would write ${p} (${content.length} bytes)`);
    return;
  }
  if (fs.existsSync(p)) {
    console.log(`  • ${path.basename(p)} already exists, leaving untouched`);
    return;
  }
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, content);
  console.log(`  + wrote ${p}`);
}

// -----------------------------------------------------------------------------
// Templates
// -----------------------------------------------------------------------------

function tplAgentBrief({ name, slug, repo, today }) {
  return `# AGENT-BRIEF.md — ${name}

> Per-project instructions for the nightly agent.
> Update this file weekly; the nightly agent reads it on every run.

## Project
- **Name:** ${name}
- **Slug:** ${slug}
- **Repo:** ${repo || "(set this once you have a repo)"}
- **Stack:** [language, framework, deploy target]
- **Live URL:** [if applicable]

## What the nightly agent should work on

${"`<- replace this block with real instructions ->`"}

Examples:
- Pick the highest-priority unticked item from \`TASK-QUEUE.md\` in the repo
- Run accessibility audit and open issues for failures
- Update dependencies and check the build still passes

## Constraints
- **Branch:** Always work on \`nightly/YYYY-MM-DD\` (never main)
- **Build must pass before commit.** Use whatever the repo's build command is.
- **No destructive operations** (drop tables, delete files, force-push) without explicit operator approval

## What "done" looks like
- A pushed branch \`nightly/YYYY-MM-DD\` with the work
- A short report posted to Discord #heracles describing what changed and any issues
- Status updated in this project's \`CURRENT.md\`

## Created
${today}
`;
}

function tplGotchas({ name }) {
  return `# GOTCHAS.md — ${name}

> Known failure patterns. The nightly agent reads this BEFORE touching anything.
> Append new lessons here as they're discovered.

## Format

\`\`\`
### YYYY-MM-DD — <one-line summary>
- **What broke:** <description>
- **Why:** <root cause>
- **How to avoid:** <rule for future runs>
\`\`\`

## Examples (replace with real ones)

### 2026-01-15 — Build fails on Node 18
- **What broke:** \`npm run build\` errors with "engine not satisfied"
- **Why:** package.json requires Node 20+
- **How to avoid:** check engines field; use nvm to switch before building.
`;
}

function tplNightlyNotes({ name }) {
  return `# NIGHTLY-NOTES.md — ${name}

> Cross-project shared memory. Append entries when something is worth other agents knowing.
> Format: dated, agent-name, project, finding.

## Format
\`\`\`
### YYYY-MM-DD — <agent>
- **What I found:** <one or two sentences>
- **Relevant to:** <other projects, or "all">
- **Why it matters:** <one sentence>
\`\`\`
`;
}

function tplCurrent({ name, today }) {
  return `# CURRENT.md — ${name}

## Status
[working / paused / broken / in-build]

## Active work
- [date] — [what's in flight]

## Recent shipped
- [date] — [what shipped]

## Blockers
- [date] — [blocker]

## Last updated
${today}
`;
}

function tplClaude({ name, slug }) {
  return `# CLAUDE.md — ${name}

You are working inside the ${name} project workspace.

## Always read first
1. \`AGENT-BRIEF.md\` — what to work on
2. \`GOTCHAS.md\` — known failure patterns
3. \`CURRENT.md\` — current state
4. \`NIGHTLY-NOTES.md\` — last 7 days of cross-agent notes

## Project slug
\`${slug}\` — use this when creating Paperclip tasks scoped to this project.

## Branch convention
- All nightly work goes on \`nightly/YYYY-MM-DD\`
- Never push to main
- One PR per nightly branch
`;
}

// -----------------------------------------------------------------------------
// Paperclip integration (optional)
// -----------------------------------------------------------------------------

async function ensurePaperclipGoal({ name, slug }) {
  const env = { ...process.env, ...loadSecrets() };
  const apiUrl = env.PAPERCLIP_API_URL || "http://127.0.0.1:3100";
  const apiKey = env.PAPERCLIP_API_KEY;
  const companyId = env.PAPERCLIP_COMPANY_ID;

  if (!apiKey || !companyId) {
    console.log("  ⚠  Paperclip not configured (need PAPERCLIP_API_KEY and PAPERCLIP_COMPANY_ID).");
    console.log("     Run scripts/paperclip-setup.js first, or pass --no-paperclip.");
    return null;
  }

  const headers = { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" };

  // Check if a goal with this title already exists.
  let existing = null;
  try {
    const res = await fetch(`${apiUrl}/api/companies/${companyId}/goals`, { headers });
    if (res.ok) {
      const list = await res.json();
      existing = Array.isArray(list) ? list.find((g) => g.title === name) : null;
    }
  } catch { /* listing might not be supported; we'll just try to create */ }

  if (existing) {
    console.log(`  • Paperclip goal exists: ${existing.id}`);
    return existing;
  }
  if (DRY_RUN) {
    console.log("  [dry-run] would create Paperclip goal:", name);
    return null;
  }

  const res = await fetch(`${apiUrl}/api/companies/${companyId}/goals`, {
    method: "POST",
    headers,
    body: JSON.stringify({ title: name, slug, status: "active" }),
  });
  if (!res.ok) {
    const text = await res.text();
    console.log(`  ⚠  Could not create Paperclip goal (HTTP ${res.status}): ${text.slice(0, 120)}`);
    return null;
  }
  const goal = await res.json();
  console.log(`  + Paperclip goal created: ${goal.id}`);
  return goal;
}

// -----------------------------------------------------------------------------
// Main
// -----------------------------------------------------------------------------

(async () => {
  const name = RAW_NAME;
  const slug = slugify(name);
  if (!slug) {
    console.error(`\n  Project name '${name}' produced an empty slug after sanitisation.`);
    console.error("  Use a name with at least one alphanumeric character.\n");
    process.exit(2);
  }
  const today = new Date().toISOString().slice(0, 10);
  const projectDir = path.join(PROJECTS_BASE, slug);

  console.log(`\n  Creating project: ${name}`);
  console.log(`  Slug:             ${slug}`);
  console.log(`  Path:             ${projectDir}`);
  if (REPO_URL) console.log(`  Repo:             ${REPO_URL}`);
  if (DRY_RUN)  console.log(`  Mode:             dry-run\n`);
  else console.log("");

  // Scaffold files
  writeFile(path.join(projectDir, "AGENT-BRIEF.md"),    tplAgentBrief({ name, slug, repo: REPO_URL, today }));
  writeFile(path.join(projectDir, "GOTCHAS.md"),        tplGotchas({ name }));
  writeFile(path.join(projectDir, "NIGHTLY-NOTES.md"),  tplNightlyNotes({ name }));
  writeFile(path.join(projectDir, "CURRENT.md"),        tplCurrent({ name, today }));
  writeFile(path.join(projectDir, "CLAUDE.md"),         tplClaude({ name, slug }));

  if (!DRY_RUN) {
    fs.mkdirSync(path.join(projectDir, "memory"), { recursive: true });
    console.log(`  + memory/ directory`);
  }

  // Optional: register Paperclip goal
  if (!NO_PAPERCLIP) {
    console.log(`\n  Registering Paperclip goal...`);
    const goal = await ensurePaperclipGoal({ name, slug });
    if (goal && goal.id) {
      setSecret(`PAPERCLIP_GOAL_${slug.toUpperCase().replace(/-/g, "_")}_ID`, goal.id);
    }
  }

  console.log(`\n  ✅ Project '${name}' scaffolded.`);
  console.log(`     Edit ${projectDir}/AGENT-BRIEF.md to brief the nightly agent.`);
  console.log(`     Tell Athena in Discord:  "I added a new project: ${name}"\n`);
})().catch((err) => {
  console.error(`\n  Error: ${err.message || err}\n`);
  process.exit(1);
});
