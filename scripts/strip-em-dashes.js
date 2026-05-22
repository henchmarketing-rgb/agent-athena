#!/usr/bin/env node

// scripts/strip-em-dashes.js
//
// Replaces em-dash-as-clause-separator (` — `) with commas, colons, or periods
// in markdown files, while leaving code blocks, hyphens, and date ranges alone.
//
// Rules applied (in order, only OUTSIDE fenced code blocks):
//   1. "^[bullet] **Name** — desc"  → "^[bullet] **Name**: desc"
//   2. "^#+ X — Y"                  → "^#+ X: Y"
//   3. "Step N — Y" anywhere       → "Step N: Y"
//   4. " — " (space-em-space)       → ", "
//
// Usage: node scripts/strip-em-dashes.js <file> [<file> ...]
// Pass --dry-run to print counts without writing.

const fs = require("fs");

const files = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const DRY = process.argv.includes("--dry-run");

if (files.length === 0) {
  console.error("usage: node scripts/strip-em-dashes.js <file> [<file> ...] [--dry-run]");
  process.exit(2);
}

const EM = "—"; // —

for (const file of files) {
  if (!fs.existsSync(file)) {
    console.error(`skip: ${file} not found`);
    continue;
  }
  const original = fs.readFileSync(file, "utf8");
  let inCode = false;
  let replaced = 0;
  const lines = original.split("\n").map((line) => {
    if (line.trim().startsWith("```")) {
      inCode = !inCode;
      return line;
    }
    if (inCode) return line;

    let next = line;

    // 1. Bullet "term — def" → "term: def"
    next = next.replace(
      /^(\s*[-*+]\s+\*\*[^*]+\*\*)\s+—\s+/,
      (m, p1) => { replaced++; return `${p1}: `; }
    );

    // 2. Heading "## X — Y" → "## X: Y"
    next = next.replace(
      /^(#{1,6}\s+[^—\n]+?)\s+—\s+/,
      (m, p1) => { replaced++; return `${p1}: `; }
    );

    // 3. "Step N — Y" anywhere on the line
    next = next.replace(
      /(\bStep\s+\d+)\s+—\s+/g,
      (m, p1) => { replaced++; return `${p1}: `; }
    );

    // 4. Generic "X — Y" → "X, Y"
    next = next.replace(
      / — /g,
      () => { replaced++; return ", "; }
    );

    return next;
  });

  const output = lines.join("\n");
  console.log(`${file}: ${replaced} replacements`);
  if (!DRY && output !== original) {
    fs.writeFileSync(file, output);
  }
}
