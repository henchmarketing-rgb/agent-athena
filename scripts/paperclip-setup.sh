#!/bin/bash
# paperclip-setup.sh
# Registers all office agents in Paperclip, sets up the org chart,
# and configures Icarus as CEO.
#
# Run AFTER Paperclip is running on port 3100 and you've completed
# the basic `paperclipai onboard` setup.
#
# Usage: bash scripts/paperclip-setup.sh

set -euo pipefail

# ─── Colors ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

API_URL="${PAPERCLIP_API_URL:-http://127.0.0.1:3100}"
API_KEY="${PAPERCLIP_API_KEY:-}"

echo -e "\n${BLUE}🔨 Paperclip Agent Setup${RESET}"
echo -e "   API: $API_URL\n"

# ─── Preflight ────────────────────────────────────────
echo -e "${YELLOW}Checking Paperclip is running...${RESET}"
if ! curl -s "$API_URL/health" | grep -q '"status"'; then
  echo -e "${RED}✗ Paperclip not responding at $API_URL${RESET}"
  echo "  Start it first: pm2 start ecosystem.config.js"
  exit 1
fi
echo -e "${GREEN}✓ Paperclip is running${RESET}\n"

# ─── Get API key if not set ───────────────────────────
if [ -z "$API_KEY" ]; then
  echo -e "${YELLOW}PAPERCLIP_API_KEY not set.${RESET}"
  echo "  You can get this from the Paperclip dashboard or by running:"
  echo "  paperclipai context set --api-key <your-key>"
  read -p "  Paste your Paperclip API key: " API_KEY
  if [ -z "$API_KEY" ]; then
    echo -e "${RED}✗ API key required${RESET}"
    exit 1
  fi
fi

AUTH="Authorization: Bearer $API_KEY"

# ─── Get company ID ──────────────────────────────────
echo -e "${YELLOW}Getting company ID...${RESET}"
COMPANY_ID=$(curl -s "$API_URL/api/companies" -H "$AUTH" | jq -r '.[0].id // empty')
if [ -z "$COMPANY_ID" ]; then
  echo -e "${RED}✗ No company found. Run 'paperclipai onboard' first.${RESET}"
  exit 1
fi
echo -e "${GREEN}✓ Company: $COMPANY_ID${RESET}\n"

# ─── Workspace base path ─────────────────────────────
WORKSPACE_BASE="${HOME}/.openclaw/workspaces/office"
echo -e "${YELLOW}Office agent workspaces: $WORKSPACE_BASE${RESET}\n"

# ─── Create Icarus as CEO ────────────────────────────
echo -e "${BLUE}Setting up Icarus (CEO)...${RESET}"
ICARUS_ID=$(curl -s "$API_URL/api/companies/$COMPANY_ID/agents" -H "$AUTH" | jq -r '.[] | select(.name == "Icarus") | .id // empty')

if [ -z "$ICARUS_ID" ]; then
  ICARUS_RESPONSE=$(curl -s -X POST "$API_URL/api/companies/$COMPANY_ID/agents" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"Icarus\",
      \"role\": \"ceo\",
      \"title\": \"Strategy & Task Delegation\",
      \"capabilities\": \"Strategy, roadmaps, positioning, decision frameworks. Creates tasks and assigns to office agents.\",
      \"adapterType\": \"openclaw_gateway\",
      \"adapterConfig\": {},
      \"budgetMonthlyCents\": 10000
    }")
  ICARUS_ID=$(echo "$ICARUS_RESPONSE" | jq -r '.id // empty')
  if [ -z "$ICARUS_ID" ]; then
    echo -e "${RED}✗ Failed to create Icarus${RESET}"
    echo "$ICARUS_RESPONSE" | jq .
    exit 1
  fi
  echo -e "${GREEN}✓ Created Icarus: $ICARUS_ID${RESET}"
else
  echo -e "${GREEN}✓ Icarus exists: $ICARUS_ID${RESET}"
fi

# ─── Office agent definitions ────────────────────────
declare -A AGENTS
AGENTS[copywriter]='{"name":"Copywriter","role":"content","title":"Brand Copywriter","capabilities":"Blog posts, landing pages, email sequences, brand voice"}'
AGENTS[outreach]='{"name":"Outreach","role":"outreach","title":"Outreach Specialist","capabilities":"Cold email, LinkedIn, follow-up sequences, partnership pitches"}'
AGENTS[analytics]='{"name":"Analytics","role":"data","title":"Data Analyst","capabilities":"KPI tracking, dashboards, weekly reports, data summaries"}'
AGENTS[seo]='{"name":"SEO","role":"seo","title":"SEO Specialist","capabilities":"Keyword research, technical audits, content briefs, meta copy"}'
AGENTS[social]='{"name":"Social","role":"social","title":"Social Media Manager","capabilities":"Platform-specific posts, scheduling briefs, engagement"}'
AGENTS[ads]='{"name":"Ads","role":"advertising","title":"Paid Media Specialist","capabilities":"PPC copy, A/B variants, Meta/Google ads, landing page hooks"}'
AGENTS[visual-director]='{"name":"Visual Director","role":"design","title":"Art Director","capabilities":"Asset specs, mood boards, brand guidelines, visual QA"}'

# ─── Register each office agent ──────────────────────
echo -e "\n${BLUE}Registering office agents...${RESET}\n"

CREATED=0
EXISTING=0

for AGENT_KEY in "${!AGENTS[@]}"; do
  AGENT_JSON="${AGENTS[$AGENT_KEY]}"
  AGENT_NAME=$(echo "$AGENT_JSON" | jq -r '.name')

  # Check if already exists
  EXISTING_ID=$(curl -s "$API_URL/api/companies/$COMPANY_ID/agents" -H "$AUTH" | jq -r --arg name "$AGENT_NAME" '.[] | select(.name == $name) | .id // empty')

  if [ -n "$EXISTING_ID" ]; then
    echo -e "  ${GREEN}✓${RESET} $AGENT_NAME — exists ($EXISTING_ID)"
    EXISTING=$((EXISTING + 1))
    continue
  fi

  # Create agent with adapter config pointing to workspace
  RESPONSE=$(curl -s -X POST "$API_URL/api/companies/$COMPANY_ID/agents" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "$(echo "$AGENT_JSON" | jq --arg icarus "$ICARUS_ID" --arg cwd "$WORKSPACE_BASE/$AGENT_KEY" '. + {
      "reportsTo": $icarus,
      "adapterType": "claude_local",
      "adapterConfig": {
        "cwd": $cwd,
        "model": "claude-sonnet-4-6",
        "dangerouslySkipPermissions": false,
        "maxTurnsPerRun": 20,
        "timeoutSec": 300
      },
      "budgetMonthlyCents": 5000
    }')")

  NEW_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
  if [ -n "$NEW_ID" ]; then
    echo -e "  ${GREEN}✓${RESET} $AGENT_NAME — created ($NEW_ID)"
    CREATED=$((CREATED + 1))
  else
    echo -e "  ${RED}✗${RESET} $AGENT_NAME — failed"
    echo "    $(echo "$RESPONSE" | jq -r '.message // .error // "unknown error"')"
  fi
done

echo -e "\n  Created: $CREATED | Already existed: $EXISTING\n"

# ─── Write agent IDs to OFFICE.md ────────────────────
echo -e "${BLUE}Fetching agent IDs for OFFICE.md...${RESET}"
ALL_AGENTS=$(curl -s "$API_URL/api/companies/$COMPANY_ID/agents" -H "$AUTH")

echo ""
echo "──────────────────────────────────────────────"
echo "  Copy these IDs into your OFFICE.md template:"
echo "──────────────────────────────────────────────"
echo ""
echo "## Paperclip"
echo "- Company ID: $COMPANY_ID"
echo "- API Base: $API_URL/api"
echo ""
echo "## Agent IDs"
echo "$ALL_AGENTS" | jq -r '.[] | "- \(.name) (\(.role)): \(.id)"'
echo ""
echo "## Icarus (CEO): $ICARUS_ID"
echo "──────────────────────────────────────────────"

# ─── Install paperclip skill in workspaces ───────────
echo -e "\n${BLUE}Installing paperclip skill in office workspaces...${RESET}"

PAPERCLIP_SKILL_SRC=""
# Check common locations for the paperclip skill
for SKILL_PATH in \
  "$HOME/Apps/paperclip/skills/paperclip" \
  "/tmp/paperclip/skills/paperclip" \
  "$HOME/.openclaw/skills/paperclip"; do
  if [ -d "$SKILL_PATH" ]; then
    PAPERCLIP_SKILL_SRC="$SKILL_PATH"
    break
  fi
done

if [ -n "$PAPERCLIP_SKILL_SRC" ]; then
  for AGENT_KEY in "${!AGENTS[@]}"; do
    SKILL_DEST="$WORKSPACE_BASE/$AGENT_KEY/skills/paperclip"
    if [ ! -d "$SKILL_DEST" ]; then
      mkdir -p "$SKILL_DEST"
      cp -r "$PAPERCLIP_SKILL_SRC"/* "$SKILL_DEST/"
      echo -e "  ${GREEN}✓${RESET} $AGENT_KEY — skill installed"
    else
      echo -e "  ${GREEN}✓${RESET} $AGENT_KEY — skill already installed"
    fi
  done
else
  echo -e "  ${YELLOW}⚠ Paperclip skill not found. Install manually:${RESET}"
  echo "    cp -r /path/to/paperclip/skills/paperclip ~/.openclaw/workspaces/office/[agent]/skills/"
fi

# ─── Summary ─────────────────────────────────────────
echo -e "\n${GREEN}✅ Paperclip setup complete!${RESET}"
echo ""
echo "Next steps:"
echo "  1. Copy the agent IDs above into your OFFICE.md in each workspace"
echo "  2. Set PAPERCLIP_API_KEY and COMPANY_ID in ~/.env.secrets"
echo "  3. Test: curl $API_URL/api/companies/$COMPANY_ID/agents -H \"$AUTH\" | jq '.[] | .name'"
echo "  4. Create a company goal in Paperclip dashboard"
echo "  5. Tell Icarus to brief the office — tasks will flow through Paperclip"
echo ""
