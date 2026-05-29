#!/usr/bin/env node
/**
 * cost-tracker.js
 * Estimates per-agent API costs from session JSONL files and flags cost
 * anomalies. Optional per-project budgets sourced from BUDGETS.md.
 *
 * Usage:
 *   node cost-tracker.js                          # last 7 days, all agents
 *   node cost-tracker.js --days 30                # custom window
 *   node cost-tracker.js --budgets BUDGETS.md     # check budgets, exit 1 on breach
 *   node cost-tracker.js --json                   # machine-readable output
 */

const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const dirIdx = args.indexOf('--dir')
const daysIdx = args.indexOf('--days')
const budgetsIdx = args.indexOf('--budgets')
const jsonOutput = args.includes('--json')

const workspaceDir = dirIdx !== -1
  ? args[dirIdx + 1]
  : path.join(process.env.HOME, '.openclaw', 'workspace')
const days = daysIdx !== -1 ? parseInt(args[daysIdx + 1], 10) : 7
const budgetsPath = budgetsIdx !== -1
  ? args[budgetsIdx + 1]
  : path.join(workspaceDir, 'BUDGETS.md')

// Approximate pricing per 1M tokens (as of 2026)
const PRICING = {
  'claude-opus-4-8': { input: 5.00, output: 25.00 },
  'claude-opus-4-7': { input: 5.00, output: 25.00 },
  'claude-sonnet-4-6': { input: 3.00, output: 15.00 },
  'claude-opus-4-6': { input: 5.00, output: 25.00 },
  default: { input: 3.00, output: 15.00 }
}

const agentsDir = path.join(process.env.HOME, '.openclaw', 'agents')

if (!fs.existsSync(agentsDir)) {
  console.log(`⚠️  agents/ directory not found at: ${agentsDir}`)
  console.log(`   Cost tracking requires OpenClaw session data.`)
  process.exit(0)
}

const now = Date.now()
const cutoffMs = days * 24 * 60 * 60 * 1000

// Scan session files for token usage
const agentCosts = {}
let totalSessions = 0

function scanSessions(dir) {
  if (!fs.existsSync(dir)) return
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      scanSessions(fullPath)
    } else if (entry.name.endsWith('.jsonl')) {
      const stat = fs.statSync(fullPath)
      if (now - stat.mtimeMs > cutoffMs) continue

      totalSessions++
      try {
        const lines = fs.readFileSync(fullPath, 'utf8').split('\n').filter(Boolean)
        let agentName = 'unknown'
        let inputTokens = 0
        let outputTokens = 0
        let model = 'default'

        for (const line of lines) {
          try {
            const data = JSON.parse(line)
            if (data.agent) agentName = data.agent
            if (data.model) model = data.model
            if (data.usage) {
              inputTokens += data.usage.input_tokens || 0
              outputTokens += data.usage.output_tokens || 0
            }
          } catch (e) {
            // Skip malformed lines
          }
        }

        if (!agentCosts[agentName]) {
          agentCosts[agentName] = { sessions: 0, inputTokens: 0, outputTokens: 0, model }
        }
        agentCosts[agentName].sessions++
        agentCosts[agentName].inputTokens += inputTokens
        agentCosts[agentName].outputTokens += outputTokens
      } catch (e) {
        // Skip unreadable files
      }
    }
  }
}

scanSessions(agentsDir)

console.log(`\n💰 Cost Tracker — last ${days} days`)
console.log(`${'─'.repeat(60)}`)
console.log(`Sessions scanned: ${totalSessions}\n`)

if (Object.keys(agentCosts).length === 0) {
  console.log('No session data found with token usage.\n')
  process.exit(0)
}

let grandTotal = 0

// Sort by cost descending
const sorted = Object.entries(agentCosts).sort((a, b) => {
  const costA = estimateCost(a[1])
  const costB = estimateCost(b[1])
  return costB - costA
})

for (const [agent, data] of sorted) {
  const cost = estimateCost(data)
  grandTotal += cost
  const inputM = (data.inputTokens / 1_000_000).toFixed(2)
  const outputM = (data.outputTokens / 1_000_000).toFixed(2)

  console.log(`  ${agent}`)
  console.log(`    Sessions: ${data.sessions} | Input: ${inputM}M tokens | Output: ${outputM}M tokens`)
  console.log(`    Estimated cost: $${cost.toFixed(2)}`)
  console.log()
}

console.log(`${'─'.repeat(60)}`)
console.log(`Total estimated: $${grandTotal.toFixed(2)} over ${days} days`)
console.log(`Daily average: $${(grandTotal / days).toFixed(2)}/day`)
console.log(`Monthly projection: $${(grandTotal / days * 30).toFixed(2)}/month\n`)

// Flag anomalies
if (grandTotal / days > 10) {
  console.log(`⚠️  WARNING: Daily spend exceeds $10/day. Review agent session lengths.\n`)
}

// =============================================================================
// Per-project budget check (optional)
// =============================================================================
//
// BUDGETS.md format — one project per line:
//   <project-slug>: <monthly-cap-in-USD>   # comment
//   hey-susan: 80
//   ironclad:  50
//
// We map session paths under ~/.openclaw/agents/<agent>/sessions/<project>/...
// to projects when the project slug appears in the path. If your sessions
// don't carry the project slug, set the slug in the session JSONL via
// `{"project": "<slug>"}` log lines.
// =============================================================================

const budgets = parseBudgets(budgetsPath)
const projectSpend = {}

if (Object.keys(budgets).length > 0) {
  // Re-scan, this time grouping by project slug
  scanSessionsForProjects(agentsDir)

  console.log(`\n📊 Per-project budgets — ${budgetsPath}`)
  console.log(`${'─'.repeat(60)}`)

  let breaches = 0
  for (const [project, cap] of Object.entries(budgets)) {
    const spent = projectSpend[project] || 0
    const monthly = (spent / days) * 30
    const pct = cap > 0 ? Math.round((monthly / cap) * 100) : 0
    const flag = monthly > cap ? '🚨' : (monthly > cap * 0.8 ? '⚠️ ' : '✓ ')
    console.log(`  ${flag} ${project.padEnd(24)} ${pct.toString().padStart(3)}%  $${monthly.toFixed(2).padStart(7)} / $${cap.toFixed(2)} cap (monthly projection)`)
    if (monthly > cap) breaches++
  }

  if (breaches > 0) {
    console.log(`\n  ${breaches} project(s) over budget. Triage in #icarus.\n`)
    if (!jsonOutput) process.exitCode = 1
  } else {
    console.log()
  }
}

if (jsonOutput) {
  const report = {
    days,
    sessionsScanned: totalSessions,
    perAgent: agentCosts,
    perProject: projectSpend,
    budgets,
    grandTotal,
    dailyAverage: grandTotal / days,
    monthlyProjection: (grandTotal / days) * 30,
  }
  console.log('\n--- JSON ---')
  console.log(JSON.stringify(report, null, 2))
}

// =============================================================================
// Helpers
// =============================================================================

function estimateCost(data) {
  const pricing = PRICING[data.model] || PRICING.default
  return (data.inputTokens / 1_000_000 * pricing.input) + (data.outputTokens / 1_000_000 * pricing.output)
}

function parseBudgets(filepath) {
  if (!fs.existsSync(filepath)) return {}
  const out = {}
  for (const line of fs.readFileSync(filepath, 'utf8').split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith('<!--')) continue
    const m = trimmed.match(/^([a-z0-9][a-z0-9-]+):\s*\$?([0-9]+(?:\.[0-9]+)?)/i)
    if (m) {
      out[m[1].toLowerCase()] = parseFloat(m[2])
    }
  }
  return out
}

function scanSessionsForProjects(dir) {
  if (!fs.existsSync(dir)) return
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      scanSessionsForProjects(fullPath)
    } else if (entry.name.endsWith('.jsonl')) {
      const stat = fs.statSync(fullPath)
      if (now - stat.mtimeMs > cutoffMs) continue
      try {
        const lines = fs.readFileSync(fullPath, 'utf8').split('\n').filter(Boolean)
        let project = inferProjectFromPath(fullPath)
        let inputTokens = 0
        let outputTokens = 0
        let model = 'default'
        for (const line of lines) {
          try {
            const data = JSON.parse(line)
            if (data.project) project = data.project.toLowerCase()
            if (data.model) model = data.model
            if (data.usage) {
              inputTokens += data.usage.input_tokens || 0
              outputTokens += data.usage.output_tokens || 0
            }
          } catch { /* skip */ }
        }
        if (project) {
          projectSpend[project] = (projectSpend[project] || 0) + estimateCost({
            inputTokens, outputTokens, model
          })
        }
      } catch { /* skip */ }
    }
  }
}

function inferProjectFromPath(filepath) {
  // ~/.openclaw/agents/<agent>/sessions/<project>/<id>.jsonl  →  <project>
  const parts = filepath.split(path.sep)
  const sessIdx = parts.lastIndexOf('sessions')
  if (sessIdx >= 0 && sessIdx + 1 < parts.length - 1) {
    return parts[sessIdx + 1].toLowerCase()
  }
  return null
}
