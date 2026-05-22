#!/bin/bash
# gen-current.sh — Write CURRENT.md from real system state
#
# Captures: openclaw gateway status, active crons, pm2 process list,
# recent git commits. Run nightly or on demand to keep CURRENT.md fresh.
#
# Usage: bash ~/.openclaw/workspace/scripts/gen-current.sh [output-path]
# Default output: ~/.openclaw/workspace/CURRENT.md

set -uo pipefail

OUTPUT="${1:-$HOME/.openclaw/workspace/CURRENT.md}"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M %Z')"

{
  echo "# CURRENT.md — System State"
  echo ""
  echo "_Generated: ${GENERATED_AT}_"
  echo ""

  # Gateway status
  echo "## Gateway"
  echo '```'
  if command -v openclaw &>/dev/null; then
    openclaw gateway status 2>&1 || echo "gateway status unavailable"
  else
    echo "openclaw not on PATH"
  fi
  echo '```'
  echo ""

  # Active crons
  echo "## Crons"
  echo '```'
  if command -v openclaw &>/dev/null; then
    openclaw cron list 2>&1 || echo "no crons configured"
  else
    echo "openclaw not on PATH"
  fi
  echo '```'
  echo ""

  # pm2 processes
  echo "## pm2 Processes"
  echo '```'
  if command -v pm2 &>/dev/null; then
    pm2 list --no-color 2>&1 || echo "no pm2 processes"
  else
    echo "pm2 not installed"
  fi
  echo '```'
  echo ""

  # Recent commits across known repos
  echo "## Recent Commits"
  for repo in \
    "$HOME/Apps/athena" \
    "$HOME/Apps/hermes-agent"; do
    if [[ -d "$repo/.git" ]]; then
      echo "### $(basename "$repo")"
      echo '```'
      git -C "$repo" log --oneline -5 2>/dev/null || echo "git error"
      echo '```'
    fi
  done
  echo ""

  # Disk usage snapshot
  echo "## Disk Usage"
  echo '```'
  du -sh "$HOME/.openclaw" 2>/dev/null || echo "n/a"
  du -sh "$HOME/athena-backups" 2>/dev/null || true
  echo '```'

} > "$OUTPUT"

echo "Written to $OUTPUT"
