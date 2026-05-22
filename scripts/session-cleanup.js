#!/usr/bin/env node
/**
 * session-cleanup.js
 * Lists and optionally purges old or oversized OpenClaw session files.
 * Usage: node session-cleanup.js [--purge] [--days <n>] [--max-mb <n>]
 */

const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')

const args = process.argv.slice(2)
const purge = args.includes('--purge')
const daysIdx = args.indexOf('--days')
const mbIdx = args.indexOf('--max-mb')
const maxAgeDays = daysIdx !== -1 ? parseInt(args[daysIdx + 1]) : 7
const maxMb = mbIdx !== -1 ? parseInt(args[mbIdx + 1]) : 50

const SESSION_DIRS = [
  path.join(process.env.HOME, '.openclaw', 'agents'),
]

const now = Date.now()
const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000
const maxBytes = maxMb * 1024 * 1024

let flagged = []
let total = 0

function scanDir(dir) {
  if (!fs.existsSync(dir)) return
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      scanDir(fullPath)
    } else if (entry.name.endsWith('.jsonl') || entry.name.endsWith('.json')) {
      total++
      const stat = fs.statSync(fullPath)
      const ageDays = (now - stat.mtimeMs) / (24 * 60 * 60 * 1000)
      const sizeMb = stat.size / (1024 * 1024)

      const reasons = []
      if (ageDays > maxAgeDays) reasons.push(`${ageDays.toFixed(0)} days old`)
      if (stat.size > maxBytes) reasons.push(`${sizeMb.toFixed(1)}MB`)

      if (reasons.length > 0) {
        flagged.push({ path: fullPath, reasons, sizeMb, ageDays })
      }
    }
  }
}

console.log(`\n🧹 Session Cleanup`)
console.log(`   Max age: ${maxAgeDays} days | Max size: ${maxMb}MB`)
if (purge) console.log(`   Mode: PURGE (will delete flagged files)`)
console.log()

SESSION_DIRS.forEach(scanDir)

if (flagged.length === 0) {
  console.log(`✅ Clean — ${total} session files checked, none flagged.\n`)
  process.exit(0)
}

console.log(`⚠️  ${flagged.length} session files flagged (out of ${total}):\n`)
flagged.forEach(f => {
  console.log(`  ${f.path}`)
  console.log(`  → ${f.reasons.join(', ')}`)
  if (purge) {
    fs.unlinkSync(f.path)
    console.log(`  → DELETED`)
  }
  console.log()
})

if (!purge) {
  console.log(`Run with --purge to delete flagged files.\n`)
} else {
  console.log(`Deleted ${flagged.length} files.\n`)
}
