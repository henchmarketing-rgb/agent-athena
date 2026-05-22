#!/usr/bin/env node
/**
 * secrets-check.js
 * Scans markdown files in a directory for exposed credentials.
 * Usage: node secrets-check.js [--dir <path>] [--strict]
 */

const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const strict = args.includes('--strict')
const dirIndex = args.indexOf('--dir')
const scanDir = dirIndex !== -1 ? args[dirIndex + 1] : (process.env.HOME + '/.openclaw/workspace')

// Patterns that look like exposed credentials
const PATTERNS = [
  { name: 'Anthropic API key',     regex: /sk-ant-[a-zA-Z0-9\-_]{20,}/g },
  { name: 'OpenAI API key',        regex: /sk-[a-zA-Z0-9]{20,}/g },
  { name: 'Slack bot token',       regex: /xoxb-[0-9]+-[a-zA-Z0-9]+/g },
  { name: 'Slack user token',      regex: /xoxp-[0-9]+-[a-zA-Z0-9]+/g },
  { name: 'GitHub PAT (classic)',  regex: /ghp_[a-zA-Z0-9]{36}/g },
  { name: 'GitHub PAT (fine)',     regex: /github_pat_[a-zA-Z0-9_]{80,}/g },
  { name: 'AWS access key',        regex: /AKIA[0-9A-Z]{16}/g },
  { name: 'Discord bot token',     regex: /[MN][a-zA-Z0-9]{23}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}/g },
  { name: 'JWT token',             regex: /eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g },
  { name: 'Supabase service key',  regex: /eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g },
  { name: 'Vercel token',          regex: /[a-zA-Z0-9]{24,}/ , contexts: ['vercel', 'VERCEL_TOKEN'] },
  { name: 'Raw password in var',   regex: /(?:password|passwd|secret|token)\s*[=:]\s*["']?[a-zA-Z0-9!@#$%^&*]{8,}["']?/gi },
]

// File extensions to scan
const SCAN_EXTENSIONS = ['.md', '.txt', '.json', '.env', '.sh', '.js', '.ts']

// Files/dirs to skip
const SKIP = ['.git', 'node_modules', '.env.secrets', 'secrets-check.js']

let findings = []
let scanned = 0

function scanFile(filePath) {
  const ext = path.extname(filePath)
  if (!SCAN_EXTENSIONS.includes(ext)) return

  const content = fs.readFileSync(filePath, 'utf8')
  const lines = content.split('\n')
  scanned++

  lines.forEach((line, i) => {
    // Skip lines that are clearly just references/examples
    if (line.includes('~/.env.secrets') && !line.match(/=\s*[a-zA-Z0-9]{20,}/)) return
    if (line.includes('[PLACEHOLDER]') || line.includes('your-key-here') || line.includes('______')) return
    if (line.trim().startsWith('#') && !strict) return // skip comments unless strict

    PATTERNS.forEach(pattern => {
      const matches = line.match(pattern.regex)
      if (matches) {
        findings.push({
          file: filePath,
          line: i + 1,
          pattern: pattern.name,
          preview: line.trim().slice(0, 80)
        })
      }
    })
  })
}

function walkDir(dir) {
  if (!fs.existsSync(dir)) return
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    if (SKIP.includes(entry.name)) continue
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      walkDir(fullPath)
    } else {
      scanFile(fullPath)
    }
  }
}

console.log(`\n🔍 Scanning: ${scanDir}\n`)
walkDir(scanDir)

if (findings.length === 0) {
  console.log(`✅ CLEAN — scanned ${scanned} files, no exposed credentials found.\n`)
  process.exit(0)
} else {
  console.log(`⚠️  FOUND ${findings.length} potential credential(s) in ${scanned} files:\n`)
  findings.forEach(f => {
    console.log(`  ${f.file}:${f.line}`)
    console.log(`  Type: ${f.pattern}`)
    console.log(`  Line: ${f.preview}`)
    console.log()
  })
  console.log(`Run with --strict to also scan comment lines.\n`)
  process.exit(1)
}
