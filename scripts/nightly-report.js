#!/usr/bin/env node
/**
 * nightly-report.js
 * Reads NIGHTLY-NOTES.md and prints a formatted summary grouped by date.
 * Usage: node nightly-report.js [--days 7] [--path /custom/path/NIGHTLY-NOTES.md]
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const daysIdx = args.indexOf('--days');
const pathIdx = args.indexOf('--path');

const days = daysIdx !== -1 ? parseInt(args[daysIdx + 1], 10) : 7;
const notesPath = pathIdx !== -1
  ? args[pathIdx + 1]
  : path.join(process.env.HOME, '.openclaw', 'workspace', 'NIGHTLY-NOTES.md');

if (!fs.existsSync(notesPath)) {
  console.log(`⚠️  NIGHTLY-NOTES.md not found at: ${notesPath}`);
  process.exit(0);
}

const content = fs.readFileSync(notesPath, 'utf8');
const lines = content.split('\n');

// Parse entries — look for date headers (## YYYY-MM-DD) and collect blocks
const entries = [];
let currentDate = null;
let currentBlock = [];

for (const line of lines) {
  const dateMatch = line.match(/^##\s+(\d{4}-\d{2}-\d{2})/);
  if (dateMatch) {
    if (currentDate && currentBlock.length) {
      entries.push({ date: currentDate, lines: currentBlock });
    }
    currentDate = dateMatch[1];
    currentBlock = [];
  } else if (currentDate) {
    currentBlock.push(line);
  }
}
if (currentDate && currentBlock.length) {
  entries.push({ date: currentDate, lines: currentBlock });
}

// Filter to last N days
const cutoff = new Date();
cutoff.setDate(cutoff.getDate() - days);

const filtered = entries.filter(e => new Date(e.date) >= cutoff);

if (filtered.length === 0) {
  console.log(`No nightly entries in the last ${days} days.`);
  process.exit(0);
}

console.log(`\n📋 Nightly Report — last ${days} days\n${'─'.repeat(50)}`);

for (const entry of filtered.reverse()) {
  console.log(`\n📅 ${entry.date}`);
  const text = entry.lines.join('\n').trim();
  if (text) {
    console.log(text);
  } else {
    console.log('  (no content)');
  }
}

console.log(`\n${'─'.repeat(50)}\n${filtered.length} date(s) found.\n`);
