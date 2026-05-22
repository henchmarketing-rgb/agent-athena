#!/usr/bin/env node
/**
 * site-health.js
 * Checks HTTP status of configured URLs. Posts to Discord on failure.
 * Usage: node site-health.js [--config <path>] [--quiet]
 *
 * Config file (sites.json):
 * { "sites": [{ "name": "My App", "url": "https://myapp.com" }] }
 */

const https = require('https')
const http = require('http')
const fs = require('fs')
const path = require('path')

const args = process.argv.slice(2)
const quiet = args.includes('--quiet')
const configIdx = args.indexOf('--config')
const configPath = configIdx !== -1
  ? args[configIdx + 1]
  : path.join(process.env.HOME, '.openclaw', 'workspace', 'sites.json')

const DISCORD_WEBHOOK = process.env.DISCORD_WEBHOOK_URL || null
const TIMEOUT_MS = 10000

function checkUrl(site) {
  return new Promise((resolve) => {
    const url = new URL(site.url)
    const lib = url.protocol === 'https:' ? https : http
    const start = Date.now()

    const req = lib.get(site.url, { timeout: TIMEOUT_MS }, (res) => {
      const ms = Date.now() - start
      const ok = res.statusCode >= 200 && res.statusCode < 400
      resolve({ ...site, status: res.statusCode, ms, ok })
      res.resume()
    })

    req.on('timeout', () => {
      req.destroy()
      resolve({ ...site, status: 'TIMEOUT', ms: TIMEOUT_MS, ok: false })
    })

    req.on('error', (err) => {
      resolve({ ...site, status: 'ERROR', error: err.message, ms: Date.now() - start, ok: false })
    })
  })
}

function postToDiscord(message) {
  if (!DISCORD_WEBHOOK) return
  const body = JSON.stringify({ content: message })
  const url = new URL(DISCORD_WEBHOOK)
  const options = {
    hostname: url.hostname,
    path: url.pathname + url.search,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }
  }
  const req = https.request(options)
  req.write(body)
  req.end()
}

async function main() {
  if (!fs.existsSync(configPath)) {
    console.log(`No sites.json found at ${configPath}`)
    console.log(`Create it with: { "sites": [{ "name": "My App", "url": "https://myapp.com" }] }`)
    process.exit(0)
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'))
  const sites = config.sites || []

  if (sites.length === 0) {
    console.log('No sites configured.')
    process.exit(0)
  }

  const results = await Promise.all(sites.map(checkUrl))
  const failures = results.filter(r => !r.ok)

  if (!quiet || failures.length > 0) {
    console.log(`\n🏥 Site Health — ${new Date().toISOString()}\n`)
    results.forEach(r => {
      const icon = r.ok ? '✅' : '❌'
      const status = r.status
      const ms = r.ms + 'ms'
      const err = r.error ? ` (${r.error})` : ''
      console.log(`  ${icon} ${r.name.padEnd(24)} ${String(status).padEnd(6)} ${ms}${err}`)
    })
    console.log()
  }

  if (failures.length > 0) {
    const tz = process.env.TIMEZONE || 'UTC'
    const msg = `⚠️ **Site Health Alert** — ${new Date().toLocaleString('en-GB', { timeZone: tz })} ${tz}\n` +
      failures.map(f => `❌ **${f.name}** — ${f.status}${f.error ? ': ' + f.error : ''} (${f.url})`).join('\n')

    console.log('Failures detected — posting to Discord...\n')
    postToDiscord(msg)
    process.exit(1)
  }

  if (!quiet) console.log(`All ${results.length} sites OK.\n`)
  process.exit(0)
}

main()
