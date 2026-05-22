#!/usr/bin/env node
/**
 * weekly-compaction.js
 * Compacts daily memory files (memory/YYYY-MM-DD.md) older than 7 days
 * into weekly summaries in memory/archive/.
 * Usage: node weekly-compaction.js [--dir /path/to/workspace] [--days 7] [--dry-run]
 */

const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const dirIdx = args.indexOf('--dir')
const daysIdx = args.indexOf('--days')
const dryRun = args.includes('--dry-run')

const workspaceDir = dirIdx !== -1
  ? args[dirIdx + 1]
  : path.join(process.env.HOME, '.openclaw', 'workspace')
const maxAgeDays = daysIdx !== -1 ? parseInt(args[daysIdx + 1], 10) : 7

const memoryDir = path.join(workspaceDir, 'memory')
const archiveDir = path.join(memoryDir, 'archive')

if (!fs.existsSync(memoryDir)) {
  console.log(`⚠️  memory/ directory not found at: ${memoryDir}`)
  process.exit(0)
}

// Ensure archive directory exists
if (!dryRun && !fs.existsSync(archiveDir)) {
  fs.mkdirSync(archiveDir, { recursive: true })
}

const now = new Date()
const cutoff = new Date(now)
cutoff.setDate(cutoff.getDate() - maxAgeDays)

// Find daily files matching YYYY-MM-DD.md
const dailyFiles = fs.readdirSync(memoryDir)
  .filter(f => /^\d{4}-\d{2}-\d{2}\.md$/.test(f))
  .map(f => ({
    name: f,
    date: new Date(f.replace('.md', '')),
    path: path.join(memoryDir, f)
  }))
  .filter(f => f.date < cutoff)
  .sort((a, b) => a.date - b.date)

if (dailyFiles.length === 0) {
  console.log(`✅ No daily files older than ${maxAgeDays} days to compact.`)
  process.exit(0)
}

// Group by ISO week
const weeks = {}
for (const file of dailyFiles) {
  const d = file.date
  const jan1 = new Date(d.getFullYear(), 0, 1)
  const weekNum = Math.ceil(((d - jan1) / 86400000 + jan1.getDay() + 1) / 7)
  const weekKey = `${d.getFullYear()}-W${String(weekNum).padStart(2, '0')}`
  if (!weeks[weekKey]) weeks[weekKey] = []
  weeks[weekKey].push(file)
}

console.log(`\n📦 Weekly Compaction`)
console.log(`   Workspace: ${workspaceDir}`)
console.log(`   Files older than: ${maxAgeDays} days`)
console.log(`   Files to compact: ${dailyFiles.length}`)
if (dryRun) console.log(`   Mode: DRY RUN (no changes)`)
console.log()

let compacted = 0
let archived = 0

for (const [weekKey, files] of Object.entries(weeks)) {
  const archivePath = path.join(archiveDir, `${weekKey}.md`)
  const dateRange = `${files[0].name.replace('.md', '')} to ${files[files.length - 1].name.replace('.md', '')}`

  console.log(`  ${weekKey} (${files.length} files: ${dateRange})`)

  // Merge daily files into weekly summary
  let merged = `# Weekly Summary — ${weekKey}\n`
  merged += `> Compacted from ${files.length} daily files (${dateRange})\n\n`

  for (const file of files) {
    const content = fs.readFileSync(file.path, 'utf8').trim()
    if (content) {
      merged += `## ${file.name.replace('.md', '')}\n\n${content}\n\n---\n\n`
    }
  }

  if (!dryRun) {
    fs.writeFileSync(archivePath, merged)
    archived++

    // Remove compacted daily files
    for (const file of files) {
      fs.unlinkSync(file.path)
      compacted++
    }
    console.log(`    → Archived to ${archivePath}`)
    console.log(`    → Removed ${files.length} daily files`)
  } else {
    console.log(`    → Would archive to ${archivePath}`)
    console.log(`    → Would remove ${files.length} daily files`)
  }
}

console.log(`\n${dryRun ? 'Would compact' : 'Compacted'} ${compacted} files into ${Object.keys(weeks).length} weekly archives.\n`)
