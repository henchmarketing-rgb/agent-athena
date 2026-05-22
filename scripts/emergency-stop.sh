#!/bin/bash
# emergency-stop.sh — Kill all agent activity immediately
#
# Use when an agent is runaway, a cron is looping, or something needs
# stopping RIGHT NOW. Safe to run multiple times.
#
# Usage: bash ~/.openclaw/workspace/scripts/emergency-stop.sh

set -uo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo ""
echo -e "${BOLD}${RED}=== EMERGENCY STOP ===${RESET}"
echo ""

# 1. Disable all openclaw crons so nothing new fires
echo -e "${BOLD}Disabling all crons...${RESET}"
if command -v openclaw &>/dev/null; then
  IDS="$(openclaw cron list --ids 2>/dev/null || true)"
  if [[ -n "$IDS" ]]; then
    echo "$IDS" | xargs -I{} openclaw cron disable {} 2>/dev/null && \
      echo -e "  ${GREEN}✓${RESET} Crons disabled" || \
      echo -e "  ${YELLOW}⚠${RESET}  Could not disable some crons — check manually"
  else
    echo "  No active crons found"
  fi
else
  echo -e "  ${YELLOW}⚠${RESET}  openclaw not on PATH"
fi

# 2. Kill all pm2 processes (nightly agents, heartbeat workers)
echo ""
echo -e "${BOLD}Stopping pm2 processes...${RESET}"
if command -v pm2 &>/dev/null; then
  pm2 stop all 2>/dev/null && \
    echo -e "  ${GREEN}✓${RESET} pm2 processes stopped" || \
    echo "  No pm2 processes running"
else
  echo "  pm2 not installed — skipping"
fi

# 3. Restart the openclaw gateway cleanly
echo ""
echo -e "${BOLD}Restarting openclaw gateway...${RESET}"
if command -v openclaw &>/dev/null; then
  openclaw gateway restart 2>/dev/null && \
    echo -e "  ${GREEN}✓${RESET} Gateway restarted" || \
    echo -e "  ${YELLOW}⚠${RESET}  Gateway restart failed — run: openclaw gateway start"
else
  echo -e "  ${YELLOW}⚠${RESET}  openclaw not on PATH"
fi

echo ""
echo -e "${BOLD}Done.${RESET} Check #recovery or #athena for status."
echo "To re-enable crons: openclaw cron enable <id>"
echo ""
