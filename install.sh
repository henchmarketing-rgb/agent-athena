#!/usr/bin/env bash

# =============================================================================
# Athena 🦉 — One Script Setup
# =============================================================================
#
# This script does everything:
#   1. Detects your OS and installs missing dependencies
#   2. Collects operator info for template substitution
#   3. Configures your model provider
#   4. Walks you through Discord bot + 7 channel IDs
#   5. Collects other credentials
#   6. Merges secrets into ~/.env.secrets (idempotent)
#   7. Picks runtime (OpenClaw or Hermes Agent), installs + onboards it
#   8. Copies workspace files with substitutions applied
#   9. Starts the gateway
#  10. Optionally installs Open Design (content studio)
#  11. Optionally installs Design Studio (Playwright + Firecrawl)
#
# After this script, go to #athena in Discord and say hello.
#
# Usage:
#   bash install.sh              # default: resume from last successful step
#   bash install.sh --reset      # wipe install state and start fresh
#   bash install.sh --no-resume  # ignore state but don't wipe it
# =============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$HOME/.athena-install-state"
SECRETS_FILE="$HOME/.env.secrets"

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

RESUME=true
for arg in "$@"; do
  case "$arg" in
    --reset)     rm -f "$STATE_FILE"; RESUME=true ;;
    --no-resume) RESUME=false ;;
    -h|--help)
      sed -n '3,28p' "$0"
      exit 0
      ;;
  esac
done

# -----------------------------------------------------------------------------
# OS detection + package manager
# -----------------------------------------------------------------------------

OS="unknown"
PKG=""
SUDO=""

case "$(uname -s)" in
  Darwin)               OS="macos" ;;
  Linux)                OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*)
    cat <<'EOF'
Athena does not currently support Windows hosts directly.

The recommended path for Windows operators:

  1. Install WSL2 (Windows Subsystem for Linux):
       https://learn.microsoft.com/windows/wsl/install

  2. Install Ubuntu (or another supported distro) inside WSL:
       wsl --install -d Ubuntu

  3. Re-run this installer FROM INSIDE the WSL shell — not from PowerShell or Git Bash:
       wsl
       cd ~ && git clone https://github.com/henchmarketing-rgb/agent-athena.git
       cd agent-athena && bash install.sh

WSL gives you a real Linux environment that all of Athena's scripts target.
Native Windows support is on the Help-wanted list — contributions welcome.
EOF
    exit 1
    ;;
  *) echo "Unsupported OS: $(uname -s). macOS or Linux required."; exit 1 ;;
esac

if [[ "$OS" == "macos" ]]; then
  if command -v brew &>/dev/null; then PKG="brew"; fi
elif [[ "$OS" == "linux" ]]; then
  if   command -v apt-get &>/dev/null; then PKG="apt"
  elif command -v dnf     &>/dev/null; then PKG="dnf"
  elif command -v yum     &>/dev/null; then PKG="yum"
  elif command -v pacman  &>/dev/null; then PKG="pacman"
  elif command -v apk     &>/dev/null; then PKG="apk"
  fi
  if [[ "$EUID" -ne 0 ]] && command -v sudo &>/dev/null; then
    SUDO="sudo"
  fi
fi

pkg_install() {
  # Install a system package with the detected manager.
  # Usage: pkg_install <package-name>
  local pkg_name="$1"
  case "$PKG" in
    brew)   brew install "$pkg_name" ;;
    apt)    $SUDO apt-get update -qq && $SUDO apt-get install -y "$pkg_name" ;;
    dnf)    $SUDO dnf install -y "$pkg_name" ;;
    yum)    $SUDO yum install -y "$pkg_name" ;;
    pacman) $SUDO pacman -S --noconfirm "$pkg_name" ;;
    apk)    $SUDO apk add "$pkg_name" ;;
    *)      return 1 ;;
  esac
}

npm_global_install() {
  # Install a global npm package, retrying with sudo on Linux EACCES.
  local pkg_name="$1"
  if npm install -g "$pkg_name" 2>/dev/null; then
    return 0
  fi
  if [[ "$OS" == "linux" && -n "$SUDO" ]]; then
    echo -e "  ${YELLOW}npm install -g failed, retrying with sudo...${RESET}"
    if $SUDO npm install -g "$pkg_name"; then
      return 0
    fi
  fi
  return 1
}

# -----------------------------------------------------------------------------
# State file: track which steps have completed so re-runs can resume
# -----------------------------------------------------------------------------

state_get() {
  # Usage: state_get KEY [default]
  # cut returns 0 on empty input so we can't rely on `|| echo default`;
  # capture the value, then fall back if it's empty.
  local key="$1" default="${2:-}" value=""
  if [[ -f "$STATE_FILE" ]]; then
    value="$(grep -E "^${key}=" "$STATE_FILE" | tail -n1 | cut -d= -f2-)"
  fi
  if [[ -z "$value" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

state_set() {
  # Usage: state_set KEY VALUE
  local key="$1" value="$2"
  touch "$STATE_FILE"
  chmod 600 "$STATE_FILE"
  # Remove any prior line for this key, then append.
  grep -v "^${key}=" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null || true
  echo "${key}=${value}" >> "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

step_done() {
  # Usage: step_done STEP_NAME (returns 0 if completed and resume enabled)
  [[ "$RESUME" == "true" ]] && [[ "$(state_get "step_$1")" == "done" ]]
}

mark_step() {
  state_set "step_$1" "done"
}

# -----------------------------------------------------------------------------
# Secrets file: idempotent merge (preserve existing values, update changed ones)
# -----------------------------------------------------------------------------

ensure_secrets_file() {
  if [[ ! -f "$SECRETS_FILE" ]]; then
    cat > "$SECRETS_FILE" <<EOF
# Athena secrets — managed by install.sh
# Never commit this file to git.
EOF
  fi
  chmod 600 "$SECRETS_FILE"
}

set_secret() {
  # Usage: set_secret KEY VALUE
  # Skips empty values. Replaces existing keys without truncating the file.
  local key="$1" value="$2"
  [[ -z "$value" ]] && return 0
  ensure_secrets_file
  grep -v "^${key}=" "$SECRETS_FILE" > "$SECRETS_FILE.tmp" || true
  # Quote the value to handle spaces, special chars, dollar signs.
  printf '%s=%q\n' "$key" "$value" >> "$SECRETS_FILE.tmp"
  mv "$SECRETS_FILE.tmp" "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
}

read_existing_secret() {
  # Echo the value of a secret if it exists. Used to skip prompts for values
  # the user has already entered on a prior run.
  local key="$1"
  [[ ! -f "$SECRETS_FILE" ]] && return 0
  grep -E "^${key}=" "$SECRETS_FILE" | tail -n1 | cut -d= -f2- | sed 's/^"//; s/"$//'
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║           Athena 🦉                   ║"
echo "  ║   Wisdom and craft. Builds while      ║"
echo "  ║   you sleep.                          ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${RESET}"
echo ""
echo -e "  OS: ${BOLD}$OS${RESET} | Package manager: ${BOLD}${PKG:-none}${RESET}"
[[ -f "$STATE_FILE" ]] && echo -e "  Resume: ${BOLD}$RESUME${RESET} (state file: $STATE_FILE)"
echo ""
echo -e "  This script sets up your entire Athena system."
echo -e "  At the end, Athena will be alive in Discord."
echo ""
echo -e "  ${YELLOW}You'll need:${RESET}"
echo "    - A model provider account (Claude recommended)"
echo "    - A Discord account"
echo "    - ~10 minutes"
echo ""
read -r -p "  Press Enter to start (or Ctrl-C to abort)..."

# =============================================================================
# STEP 1 — Dependencies
# =============================================================================

if step_done dependencies; then
  echo -e "${GREEN}✓${RESET} Step 1 (dependencies) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 1 — Checking dependencies${RESET}"
  echo ""

  check_cmd() {
    if command -v "$1" &>/dev/null; then
      echo -e "  ${GREEN}✓${RESET} $1"
      return 0
    else
      echo -e "  ${RED}✗${RESET} $1 not found"
      return 1
    fi
  }

  check_cmd node || { echo -e "\n  Install Node.js 20+ from ${CYAN}https://nodejs.org${RESET}"; exit 1; }
  check_cmd git  || { echo -e "\n  Install git before continuing."; exit 1; }
  check_cmd npm  || { echo -e "\n  npm is required (comes with Node.js 20+)."; exit 1; }

  # Verify Node version is 20+
  NODE_MAJOR="$(node --version | sed 's/^v//' | cut -d. -f1)"
  if [[ -n "$NODE_MAJOR" && "$NODE_MAJOR" -lt 20 ]]; then
    echo -e "\n  ${RED}Node.js $NODE_MAJOR detected, but 20+ is required.${RESET}"
    echo -e "  Update from ${CYAN}https://nodejs.org${RESET} or via nvm."
    exit 1
  fi
  echo -e "  ${GREEN}✓${RESET} Node.js $NODE_MAJOR"

  # jq
  if ! command -v jq &>/dev/null; then
    echo "  Installing jq..."
    if pkg_install jq 2>/dev/null; then
      echo -e "  ${GREEN}✓${RESET} jq installed"
    else
      echo -e "  ${YELLOW}⚠${RESET}  Could not auto-install jq via $PKG."
      echo -e "     Install manually: https://jqlang.github.io/jq/download/"
    fi
  else
    echo -e "  ${GREEN}✓${RESET} jq"
  fi

  # pm2
  if ! command -v pm2 &>/dev/null; then
    echo "  Installing pm2..."
    if npm_global_install pm2; then
      echo -e "  ${GREEN}✓${RESET} pm2 installed"
    else
      echo -e "  ${YELLOW}⚠${RESET}  pm2 install failed. Try manually: ${SUDO} npm install -g pm2"
    fi
  else
    echo -e "  ${GREEN}✓${RESET} pm2"
  fi

  # gh
  if ! command -v gh &>/dev/null; then
    echo ""
    echo -e "  ${YELLOW}gh CLI not found.${RESET} Needed for nightly agents to push branches."
    echo -e "  Install: ${CYAN}https://cli.github.com${RESET}"
    if [[ -n "$PKG" ]]; then
      read -r -p "  Try auto-install via $PKG? (y/n): " install_gh
      if [[ "$install_gh" == "y" ]]; then
        case "$PKG" in
          brew) pkg_install gh ;;
          apt)  pkg_install gh ;;
          dnf)  pkg_install gh ;;
          *)    echo -e "  ${YELLOW}gh not in default $PKG repo. Install manually.${RESET}" ;;
        esac
      fi
    fi
  fi

  # Claude Code CLI
  if ! command -v claude &>/dev/null; then
    echo "  Installing Claude Code CLI..."
    if npm_global_install @anthropic-ai/claude-code; then
      echo -e "  ${GREEN}✓${RESET} claude CLI installed"
    else
      echo -e "  ${RED}✗${RESET} claude CLI install failed. Install manually: npm install -g @anthropic-ai/claude-code"
      exit 1
    fi
  else
    echo -e "  ${GREEN}✓${RESET} claude CLI"
  fi

  # Runtime binary (openclaw or hermes) is installed in Step 7 after the
  # operator picks which runtime they want.

  echo ""
  echo -e "  ${GREEN}Base dependencies ready. Runtime binary installs in Step 7.${RESET}"
  mark_step dependencies
fi

# =============================================================================
# STEP 2 — Operator Info (used to substitute template placeholders)
# =============================================================================

if step_done operator_info; then
  echo -e "${GREEN}✓${RESET} Step 2 (operator info) already completed. Skipping."
  OPERATOR_NAME="$(state_get operator_name)"
  OPERATOR_FULL_NAME="$(state_get operator_full_name)"
  OPERATOR_PREFERRED="$(state_get operator_preferred)"
  OPERATOR_GITHUB="$(state_get operator_github)"
  OPERATOR_TIMEZONE="$(state_get operator_timezone)"
  OPERATOR_DISCORD_HANDLE="$(state_get operator_discord_handle)"
  BUSINESS_NAME="$(state_get business_name)"
else
  echo ""
  echo -e "${BOLD}Step 2 — About you${RESET}"
  echo ""
  echo "  These details fill in templates so your workspace files describe you, not [OPERATOR_NAME]."
  echo ""

  read -r -p "  Operator name (short — what agents will call you, e.g. 'Alex'): " OPERATOR_NAME
  read -r -p "  Full name (e.g. 'Alex Smith'): " OPERATOR_FULL_NAME
  read -r -p "  Preferred name (what you go by, default: $OPERATOR_NAME): " OPERATOR_PREFERRED
  OPERATOR_PREFERRED="${OPERATOR_PREFERRED:-$OPERATOR_NAME}"
  read -r -p "  Your GitHub username: " OPERATOR_GITHUB
  read -r -p "  Timezone offset from UTC (e.g. '+7' for Bangkok, '-5' for EST, '0' for UTC): " OPERATOR_TIMEZONE
  read -r -p "  Discord handle (e.g. 'alex#1234' or '@alex'): " OPERATOR_DISCORD_HANDLE
  read -r -p "  Business / project name (e.g. 'Acme Co.', or just your name): " BUSINESS_NAME

  # Normalize timezone so it always carries an explicit sign.
  case "$OPERATOR_TIMEZONE" in
    -*) OPERATOR_TIMEZONE="-${OPERATOR_TIMEZONE#-}" ;;
    +*) OPERATOR_TIMEZONE="+${OPERATOR_TIMEZONE#+}" ;;
    "") OPERATOR_TIMEZONE="+0" ;;
    *)  OPERATOR_TIMEZONE="+${OPERATOR_TIMEZONE}" ;;
  esac

  state_set operator_name "$OPERATOR_NAME"
  state_set operator_full_name "$OPERATOR_FULL_NAME"
  state_set operator_preferred "$OPERATOR_PREFERRED"
  state_set operator_github "$OPERATOR_GITHUB"
  state_set operator_timezone "$OPERATOR_TIMEZONE"
  state_set operator_discord_handle "$OPERATOR_DISCORD_HANDLE"
  state_set business_name "$BUSINESS_NAME"

  set_secret OPERATOR_NAME "$OPERATOR_NAME"
  set_secret OPERATOR_GITHUB "$OPERATOR_GITHUB"

  echo ""
  echo -e "  ${GREEN}✓${RESET} Recorded."
  mark_step operator_info
fi

# =============================================================================
# STEP 3 — Model Provider
# =============================================================================

if step_done model_provider; then
  echo -e "${GREEN}✓${RESET} Step 3 (model provider) already completed. Skipping."
  SELECTED_MODEL="$(state_get selected_model)"
  provider_choice="$(state_get provider_choice)"
  anthropic_auth_choice="$(state_get anthropic_auth_choice)"
else
  echo ""
  echo -e "${BOLD}Step 3 — Choose your model provider${RESET}"
  echo ""
  echo "  Athena runs on any OpenAI-compatible model."
  echo "  Claude is the recommended setup, most powerful in production."
  echo ""
  echo "    1) Anthropic (Claude), recommended"
  echo "    2) OpenAI (GPT-4)"
  echo "    3) Google (Gemini)"
  echo "    4) Ollama (local)"
  echo "    5) Custom (any OpenAI-compatible endpoint)"
  echo ""
  read -r -p "  Enter 1-5: " provider_choice

  anthropic_auth_choice=""
  ANTHROPIC_API_KEY=""
  OPENAI_API_KEY=""
  GEMINI_API_KEY=""
  OLLAMA_BASE_URL=""
  CUSTOM_BASE_URL=""
  CUSTOM_API_KEY=""

  case "$provider_choice" in
    1)
      echo ""
      echo -e "  ${BOLD}Anthropic auth method:${RESET}"
      echo "    1) Setup-token (uses your Claude subscription, recommended)"
      echo "    2) API key (usage-based billing)"
      echo ""
      read -r -p "  Enter 1 or 2: " anthropic_auth_choice

      if [[ "$anthropic_auth_choice" == "1" ]]; then
        echo ""
        echo -e "  Generating setup-token. Copy the token that appears below."
        echo -e "  You'll paste it into the OpenClaw onboard wizard in Step 7."
        echo ""
        claude setup-token || {
          echo -e "  ${YELLOW}⚠${RESET}  setup-token generation failed. Try logging in: claude login"
          exit 1
        }
        echo ""
        echo -e "  ${GREEN}✓${RESET} Token generated."
      else
        echo ""
        read -r -s -p "  Paste your Anthropic API key: " ANTHROPIC_API_KEY
        echo ""
      fi
      SELECTED_MODEL="anthropic/claude-sonnet-4-6"
      ;;
    2)
      echo ""
      read -r -s -p "  Paste your OpenAI API key: " OPENAI_API_KEY
      echo ""
      read -r -p "  Model string (default: openai/gpt-4o): " SELECTED_MODEL
      SELECTED_MODEL="${SELECTED_MODEL:-openai/gpt-4o}"
      ;;
    3)
      echo ""
      read -r -s -p "  Paste your Google Gemini API key: " GEMINI_API_KEY
      echo ""
      read -r -p "  Model string (default: google/gemini-2.0-flash): " SELECTED_MODEL
      SELECTED_MODEL="${SELECTED_MODEL:-google/gemini-2.0-flash}"
      ;;
    4)
      echo ""
      read -r -p "  Ollama base URL (default: http://localhost:11434): " OLLAMA_BASE_URL
      OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
      read -r -p "  Model string (e.g. ollama/llama3): " SELECTED_MODEL
      [[ -z "$SELECTED_MODEL" ]] && { echo -e "  ${RED}Model required.${RESET}"; exit 1; }
      ;;
    5)
      echo ""
      read -r -p "  Base URL (e.g. https://api.together.xyz/v1): " CUSTOM_BASE_URL
      read -r -s -p "  API key: " CUSTOM_API_KEY
      echo ""
      read -r -p "  Model string (e.g. together/meta-llama-3-70b): " SELECTED_MODEL
      [[ -z "$SELECTED_MODEL" ]] && { echo -e "  ${RED}Model required.${RESET}"; exit 1; }
      ;;
    *)
      echo -e "  ${RED}Invalid choice. Defaulting to Anthropic.${RESET}"
      SELECTED_MODEL="anthropic/claude-sonnet-4-6"
      provider_choice="1"
      anthropic_auth_choice="1"
      ;;
  esac

  echo "$SELECTED_MODEL" > "$REPO_DIR/config/model.conf"
  state_set selected_model "$SELECTED_MODEL"
  state_set provider_choice "$provider_choice"
  state_set anthropic_auth_choice "$anthropic_auth_choice"

  set_secret ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
  set_secret OPENAI_API_KEY    "$OPENAI_API_KEY"
  set_secret GEMINI_API_KEY    "$GEMINI_API_KEY"
  set_secret OLLAMA_BASE_URL   "$OLLAMA_BASE_URL"
  set_secret CUSTOM_BASE_URL   "$CUSTOM_BASE_URL"
  set_secret CUSTOM_API_KEY    "$CUSTOM_API_KEY"

  echo ""
  echo -e "  ${GREEN}✓${RESET} Model: $SELECTED_MODEL"
  mark_step model_provider
fi

# =============================================================================
# STEP 4 — Discord Bot + 7 channel IDs
# =============================================================================

if step_done discord; then
  echo -e "${GREEN}✓${RESET} Step 4 (Discord) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 4 — Discord Bot${RESET}"
  echo ""

  read -r -p "  Do you already have a Discord bot created? (y/n): " has_bot

  if [[ "$has_bot" != "y" ]]; then
    echo ""
    echo -e "  ${BOLD}Create your Discord bot:${RESET}"
    echo "  1. Open: ${CYAN}https://discord.com/developers/applications${RESET}"
    echo "  2. New Application, name it Athena"
    echo "  3. Bot tab > Reset Token > copy the token"
    echo "  4. Bot tab > Enable:"
    echo "     - Message Content Intent"
    echo "     - Server Members Intent"
    echo "     (Presence Intent is NOT needed.)"
    echo "  5. OAuth2 > URL Generator:"
    echo "     Scopes: bot"
    echo "     Permissions: Send Messages, Read Messages, Read Message History, Add Reactions"
    echo "  6. Copy invite URL > open it > add bot to your server"
    echo ""
    echo -e "  ${YELLOW}You also need 7 Discord channels (we'll prompt for IDs):${RESET}"
    echo "    #🦉〡athena    #🌊〡poseidon    #🪶〡icarus"
    echo "    #⚡〡heracles  #⚒️〡forge       #👁️〡argus"
    echo "    #🛡️〡recovery"
    echo ""
    echo "  Or run scripts/discord-setup.js after install to auto-create them."
    echo ""
    read -r -p "  Press Enter when bot + channels exist..."
  fi

  echo ""
  read -r -s -p "  Paste your Discord Bot Token: " DISCORD_TOKEN
  echo ""

  echo -e "  ${BOLD}Discord IDs${RESET}"
  echo "  Enable Developer Mode: User Settings > Advanced > Developer Mode."
  echo "  Right-click items in Discord to copy IDs."
  echo ""

  read -r -p "  Server (Guild) ID: " GUILD_ID
  read -r -p "  Your Discord User ID (right-click your name, copy ID): " DISCORD_USER_ID
  echo ""
  echo "  Channel IDs (right-click each channel in your server, Copy Channel ID):"
  read -r -p "    #athena   ID: " ATHENA_CHANNEL_ID
  read -r -p "    #poseidon ID (or Enter to skip): " POSEIDON_CHANNEL_ID
  read -r -p "    #icarus   ID (or Enter to skip): " ICARUS_CHANNEL_ID
  read -r -p "    #heracles ID (or Enter to skip): " HERACLES_CHANNEL_ID
  read -r -p "    #forge    ID (or Enter to skip): " FORGE_CHANNEL_ID
  read -r -p "    #argus    ID (or Enter to skip): " ARGUS_CHANNEL_ID
  read -r -p "    #recovery ID (or Enter to skip): " RECOVERY_CHANNEL_ID

  set_secret DISCORD_BOT_TOKEN          "$DISCORD_TOKEN"
  set_secret DISCORD_GUILD_ID           "$GUILD_ID"
  set_secret DISCORD_USER_ID            "$DISCORD_USER_ID"
  set_secret DISCORD_ATHENA_CHANNEL_ID  "$ATHENA_CHANNEL_ID"
  set_secret DISCORD_POSEIDON_CHANNEL_ID "$POSEIDON_CHANNEL_ID"
  set_secret DISCORD_ICARUS_CHANNEL_ID   "$ICARUS_CHANNEL_ID"
  set_secret DISCORD_HERACLES_CHANNEL_ID "$HERACLES_CHANNEL_ID"
  set_secret DISCORD_FORGE_CHANNEL_ID    "$FORGE_CHANNEL_ID"
  set_secret DISCORD_ARGUS_CHANNEL_ID    "$ARGUS_CHANNEL_ID"
  set_secret DISCORD_RECOVERY_CHANNEL_ID "$RECOVERY_CHANNEL_ID"

  state_set discord_user_id "$DISCORD_USER_ID"
  mark_step discord
fi

# =============================================================================
# STEP 5 — Other Credentials
# =============================================================================

if step_done other_credentials; then
  echo -e "${GREEN}✓${RESET} Step 5 (other credentials) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 5 — Additional Credentials${RESET}"
  echo "  Press Enter to skip any of these."
  echo ""

  echo -e "  ${BOLD}🐙 GitHub${RESET}"
  GITHUB_USERNAME=""
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} Already authenticated via gh CLI"
    GITHUB_USERNAME=$(gh api user -q .login 2>/dev/null || echo "")
    [[ -n "$GITHUB_USERNAME" ]] && set_secret GITHUB_USERNAME "$GITHUB_USERNAME"
  else
    echo "  Run 'gh auth login' after this script, or paste a token now."
    echo -e "  Get one: ${CYAN}https://github.com/settings/tokens${RESET} (repo scope)"
    read -r -p "  GitHub PAT (or Enter to skip): " GITHUB_TOKEN
    set_secret GITHUB_TOKEN "$GITHUB_TOKEN"
  fi

  echo ""
  echo -e "  ${BOLD}🔍 Brave Search API Key${RESET} ${YELLOW}(free tier: 2k queries/month)${RESET}"
  echo -e "  Sign up: ${CYAN}https://brave.com/search/api/${RESET}"
  read -r -p "  Brave Search API Key (or Enter): " BRAVE_API_KEY
  set_secret BRAVE_SEARCH_API_KEY "$BRAVE_API_KEY"

  echo ""
  echo -e "  ${BOLD}▲ Vercel Token${RESET} ${YELLOW}(optional)${RESET}"
  echo -e "  Get: ${CYAN}https://vercel.com/account/tokens${RESET}"
  read -r -p "  Vercel Token (or Enter): " VERCEL_TOKEN
  set_secret VERCEL_TOKEN "$VERCEL_TOKEN"

  echo ""
  echo -e "  ${BOLD}🔥 Firecrawl API Key${RESET} ${YELLOW}(free tier: 500 credits/month)${RESET}"
  echo -e "  Sign up: ${CYAN}https://firecrawl.dev${RESET}"
  echo "  Required for agent web scraping and search."
  read -r -s -p "  Firecrawl API Key (or Enter): " FIRECRAWL_API_KEY
  echo ""
  set_secret FIRECRAWL_API_KEY "$FIRECRAWL_API_KEY"

  echo ""
  echo -e "  ${BOLD}🚨 Alerting webhook${RESET} ${YELLOW}(optional)${RESET}"
  echo "  External heartbeat / incident endpoint. If pings stop, the service alerts you."
  echo -e "  Free options:  ${CYAN}https://healthchecks.io${RESET} (single-URL, fail/success ping)"
  echo -e "                 ${CYAN}https://uptimerobot.com${RESET} (Better Stack works too)"
  read -r -p "  Alert webhook URL (or Enter to skip): " ALERT_WEBHOOK_URL
  set_secret ALERT_WEBHOOK_URL "$ALERT_WEBHOOK_URL"

  echo ""
  echo -e "  ${BOLD}🌐 Browser Harness${RESET} ${YELLOW}(optional)${RESET}"
  echo "  Lets agents post to social, access dashboards, scrape logged-in content."
  echo "  Setup: launch Chrome with --remote-debugging-port=9222"
  read -r -p "  Chrome remote debugging port (e.g. 9222, or Enter): " CDP_PORT
  if [[ -n "$CDP_PORT" ]]; then
    set_secret CHROME_CDP_PORT "$CDP_PORT"
    set_secret CHROME_CDP_URL "http://localhost:$CDP_PORT"
  fi

  set_secret ATHENA_REPO "$REPO_DIR"

  mark_step other_credentials
fi

# =============================================================================
# STEP 6 — Wire secrets into shell profile
# =============================================================================

if step_done shell_profile; then
  echo -e "${GREEN}✓${RESET} Step 6 (shell profile) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 6 — Saving credentials${RESET}"
  echo ""
  ensure_secrets_file
  echo -e "  ${GREEN}✓${RESET} ~/.env.secrets ready (chmod 600)"

  SHELL_PROFILE=""
  case "${SHELL:-}" in
    *zsh*)  SHELL_PROFILE="$HOME/.zshrc" ;;
    *bash*) SHELL_PROFILE="$HOME/.bashrc" ;;
  esac

  if [[ -n "$SHELL_PROFILE" ]]; then
    if ! grep -q "source.*\.env\.secrets" "$SHELL_PROFILE" 2>/dev/null; then
      {
        echo ""
        echo "# Athena: load API tokens for agent shells (added by install.sh)"
        echo "[ -f ~/.env.secrets ] && set -a && source ~/.env.secrets && set +a"
      } >> "$SHELL_PROFILE"
      echo -e "  ${GREEN}✓${RESET} Wired ~/.env.secrets into $SHELL_PROFILE"
      echo -e "     ${YELLOW}Note: this means new shells will load these tokens automatically.${RESET}"
    fi
  fi

  # Source for the rest of this run, but tolerate quoting weirdness.
  set -a
  # shellcheck disable=SC1090
  source "$SECRETS_FILE" 2>/dev/null || echo -e "  ${YELLOW}⚠${RESET}  Could not source $SECRETS_FILE; check for malformed lines."
  set +a

  mark_step shell_profile
fi

# =============================================================================
# STEP 7 — Runtime Setup (OpenClaw OR Hermes Agent)
# =============================================================================
#
# Athena ships with two runtime adapters:
#
#   1) OpenClaw (default, recommended)
#      - Multi-channel multi-agent topology
#      - One Discord bot routes to 14 channels, each with its own persona
#      - Live multi-agent chat: talk to any of the 14 personas in their channel
#      - Native Athena topology
#
#   2) Hermes Agent
#      - Single-profile self-improving agent
#      - Athena is the active persona; the other 13 (Poseidon, Icarus, Forge,
#        Argus, Heracles, Recovery, office team) load as Hermes skills that
#        Athena dispatches via cron + Paperclip
#      - One Discord bot, one active persona, autonomous orchestration
#      - Honest tradeoff: you don't get 14 distinct Discord channels — you get
#        one self-improving Athena that runs the full team via cron + delegation
#
# See docs/RUNTIME-ADAPTERS.md for the full comparison.
# Adapter manifests at config/runtime/{openclaw,hermes}.json.

if step_done runtime_choice; then
  RUNTIME="$(state_get runtime "openclaw")"
  echo -e "${GREEN}✓${RESET} Step 7a (runtime choice: $RUNTIME) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 7 — Choose your runtime${RESET}"
  echo ""
  echo "  Athena runs on either:"
  echo ""
  echo -e "    1) ${BOLD}OpenClaw${RESET} (default, recommended)"
  echo "       14-channel multi-agent Discord topology. Native Athena."
  echo ""
  echo -e "    2) ${BOLD}Hermes Agent${RESET}"
  echo "       Single self-improving agent with personas as autonomous skills."
  echo ""
  echo "  See docs/RUNTIME-ADAPTERS.md for the full comparison."
  echo ""
  read -r -p "  Enter 1 or 2 [default 1]: " runtime_choice

  case "$runtime_choice" in
    2|hermes|Hermes) RUNTIME="hermes" ;;
    *)               RUNTIME="openclaw" ;;
  esac

  state_set runtime "$RUNTIME"
  set_secret ATHENA_RUNTIME "$RUNTIME"
  echo -e "  ${GREEN}✓${RESET} Runtime: $RUNTIME"
  mark_step runtime_choice
fi

# ---------------------------------------------------------------------------
# Step 7b — Install the chosen runtime binary
# ---------------------------------------------------------------------------

if step_done runtime_install; then
  echo -e "${GREEN}✓${RESET} Step 7b (runtime install) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 7b — Installing $RUNTIME${RESET}"
  echo ""

  case "$RUNTIME" in
    openclaw)
      if ! command -v openclaw &>/dev/null; then
        echo "  Installing OpenClaw..."
        if npm_global_install openclaw; then
          echo -e "  ${GREEN}✓${RESET} openclaw installed"
        else
          echo -e "  ${RED}✗${RESET} openclaw install failed. Install manually: npm install -g openclaw"
          exit 1
        fi
      else
        echo -e "  ${GREEN}✓${RESET} openclaw already on PATH"
      fi
      ;;
    hermes)
      HERMES_REPO="$HOME/Apps/hermes-agent"
      if ! command -v hermes &>/dev/null; then
        echo "  Cloning nousresearch/hermes-agent to $HERMES_REPO..."
        mkdir -p "$HOME/Apps"
        if [[ -d "$HERMES_REPO/.git" ]]; then
          git -C "$HERMES_REPO" pull --ff-only 2>/dev/null || \
            echo -e "  ${YELLOW}⚠${RESET}  Could not fast-forward. Update manually: cd $HERMES_REPO && git pull"
        else
          if ! git clone --depth 1 https://github.com/nousresearch/hermes-agent.git "$HERMES_REPO" 2>&1 | tail -3; then
            echo -e "  ${RED}✗${RESET} Hermes clone failed. Check network."
            exit 1
          fi
        fi
        echo "  Running setup-hermes.sh (this installs Python deps via uv or pip)..."
        if ! (cd "$HERMES_REPO" && bash setup-hermes.sh 2>&1 | tail -10); then
          echo -e "  ${YELLOW}⚠${RESET}  setup-hermes.sh did not complete cleanly."
          echo -e "  Activate the venv and re-run manually: source $HERMES_REPO/.venv/bin/activate"
        fi
        # Add a shim so `hermes` is on PATH for this session.
        if [[ -x "$HERMES_REPO/hermes" ]]; then
          export PATH="$HERMES_REPO:$PATH"
          set_secret HERMES_REPO "$HERMES_REPO"
        fi
      else
        echo -e "  ${GREEN}✓${RESET} hermes already on PATH"
      fi
      ;;
  esac

  mark_step runtime_install
fi

# ---------------------------------------------------------------------------
# Step 7c — Onboard / configure the chosen runtime
# ---------------------------------------------------------------------------

if step_done runtime_onboard; then
  echo -e "${GREEN}✓${RESET} Step 7c (runtime onboard) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 7c — Onboarding $RUNTIME${RESET}"
  echo ""

  case "$RUNTIME" in
    openclaw)
      if [[ "${provider_choice:-}" == "1" ]]; then
        echo "  Running the OpenClaw onboard wizard."
        echo "  It will ask for auth and Discord details, paste what you've prepared."
        echo ""
        if [[ "${anthropic_auth_choice:-}" == "1" ]]; then
          echo -e "  ${YELLOW}When asked: choose 'Anthropic token (paste setup-token)'${RESET}"
          echo -e "  ${YELLOW}Paste the setup-token from Step 3.${RESET}"
        else
          echo -e "  ${YELLOW}When asked: choose 'Anthropic API key'${RESET}"
        fi
        echo ""
        read -r -p "  Press Enter to launch openclaw onboard..."
        set +e
        openclaw onboard
        ONBOARD_EXIT=$?
        set -e
      else
        echo "  Running OpenClaw onboard (skipping Anthropic auth, you have your provider configured)."
        echo -e "  ${YELLOW}If asked for an Anthropic token or API key, press Enter to skip.${RESET}"
        echo ""
        read -r -p "  Press Enter to launch openclaw onboard..."
        set +e
        ONBOARD_HELP="$(openclaw onboard --help 2>&1 || true)"
        if echo "$ONBOARD_HELP" | grep -q -- "--skip-auth"; then
          openclaw onboard --skip-auth
        elif echo "$ONBOARD_HELP" | grep -q -- "--provider"; then
          openclaw onboard --provider "${SELECTED_MODEL%%/*}"
        else
          openclaw onboard
        fi
        ONBOARD_EXIT=$?
        set -e
      fi

      if [[ $ONBOARD_EXIT -ne 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠${RESET}  openclaw onboard exited with code $ONBOARD_EXIT."
        echo -e "  Re-run this script (it will resume here): bash install.sh"
        exit $ONBOARD_EXIT
      fi
      ;;
    hermes)
      echo "  Configuring Hermes Athena profile via scripts/hermes-setup.js..."
      echo ""
      set +e
      node "$REPO_DIR/scripts/hermes-setup.js" --no-cron
      ONBOARD_EXIT=$?
      set -e
      if [[ $ONBOARD_EXIT -ne 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠${RESET}  hermes-setup.js exited with code $ONBOARD_EXIT."
        echo -e "  Re-run this script (it will resume here): bash install.sh"
        exit $ONBOARD_EXIT
      fi
      ;;
  esac

  mark_step runtime_onboard
fi

# =============================================================================
# STEP 8 — Workspace files (with template substitution)
# =============================================================================

if step_done workspaces; then
  echo -e "${GREEN}✓${RESET} Step 8 (workspaces) already completed. Skipping."
  WORKSPACE_BASE="$(state_get workspace_base "$HOME/.openclaw/workspaces")"
  ATHENA_WORKSPACE="$WORKSPACE_BASE/athena"
else
  echo ""
  echo -e "${BOLD}Step 8 — Setting up workspaces${RESET}"
  echo ""

  case "${RUNTIME:-openclaw}" in
    hermes)   WORKSPACE_BASE="$HOME/.hermes/workspaces" ;;
    openclaw|*) WORKSPACE_BASE="$HOME/.openclaw/workspaces" ;;
  esac
  ATHENA_WORKSPACE="$WORKSPACE_BASE/athena"

  # Fall back to the legacy single-workspace path if openclaw onboard used it.
  if [[ "${RUNTIME:-openclaw}" == "openclaw" && ! -d "$ATHENA_WORKSPACE" && -d "$HOME/.openclaw/workspace" ]]; then
    ATHENA_WORKSPACE="$HOME/.openclaw/workspace"
    WORKSPACE_BASE="$(dirname "$ATHENA_WORKSPACE")"
  fi
  mkdir -p "$ATHENA_WORKSPACE"
  state_set workspace_base "$WORKSPACE_BASE"

  # ---------------------------------------------------------------------------
  # Substitution: replace [PLACEHOLDER] tokens with operator info.
  # ---------------------------------------------------------------------------

  # Escape replacement-side metacharacters so user input never breaks sed.
  # Pipe `|` is our delimiter; `&` is the match-back, `\` escapes; newlines
  # would terminate the s command. Strip the latter, escape the rest.
  sed_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//|/\\|}"
    s="${s//&/\\&}"
    s="${s//$'\n'/ }"
    printf '%s' "$s"
  }

  apply_substitutions() {
    # Usage: apply_substitutions <file> <agent_name>
    # Edits the file in place. Safe to run on any file.
    local file="$1" agent_name="${2:-}"
    [[ ! -f "$file" ]] && return 0

    local op_name op_full op_pref op_gh op_tz op_handle op_biz op_user
    op_name="$(sed_escape "${OPERATOR_NAME:-}")"
    op_full="$(sed_escape "${OPERATOR_FULL_NAME:-}")"
    op_pref="$(sed_escape "${OPERATOR_PREFERRED:-}")"
    op_gh="$(sed_escape "${OPERATOR_GITHUB:-}")"
    op_tz="$(sed_escape "${OPERATOR_TIMEZONE:-+0}")"
    op_handle="$(sed_escape "${OPERATOR_DISCORD_HANDLE:-}")"
    op_biz="$(sed_escape "${BUSINESS_NAME:-}")"
    op_user="$(sed_escape "${DISCORD_USER_ID:-}")"

    local tmp; tmp="$(mktemp)"
    # POSIX sed differs between BSD (macOS) and GNU. Use a temp file pattern.
    # GMT pattern accepts +X and -X so negative offsets (e.g. EST) work too.
    sed \
      -e "s|\[OPERATOR_NAME\]|${op_name}|g" \
      -e "s|\[Full Name\]|${op_full}|g" \
      -e "s|\[PREFERRED_NAME\]|${op_pref}|g" \
      -e "s|\[GITHUB_USERNAME\]|${op_gh}|g" \
      -e "s|\[username\]|${op_gh}|g" \
      -e "s|GMT[+-]\[X\]|GMT${op_tz}|g" \
      -e "s|\[TIMEZONE\]|UTC${op_tz}|g" \
      -e "s|\[DISCORD_USER_ID\]|${op_user}|g" \
      -e "s|\[handle\]|${op_handle}|g" \
      -e "s|\[BUSINESS_NAME\]|${op_biz}|g" \
      -e "s|\[Name\]|${op_name}|g" \
      "$file" > "$tmp"

    if [[ -n "$agent_name" ]]; then
      local agent_esc; agent_esc="$(sed_escape "$agent_name")"
      local tmp2; tmp2="$(mktemp)"
      # Accept both `[AGENT NAME]` (space) and `[AGENT_NAME]` (underscore).
      sed \
        -e "s|\[AGENT NAME\]|${agent_esc}|g" \
        -e "s|\[AGENT_NAME\]|${agent_esc}|g" \
        "$tmp" > "$tmp2"
      mv "$tmp2" "$tmp"
    fi

    mv "$tmp" "$file"
  }

  copy_with_substitutions() {
    # Usage: copy_with_substitutions <src> <dst> <agent_name>
    # Backs up the destination if it already exists and differs.
    local src="$1" dst="$2" agent_name="${3:-}"
    [[ ! -f "$src" ]] && return 0
    if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
      cp "$dst" "${dst}.bak.$(date +%s)" 2>/dev/null || true
    fi
    cp "$src" "$dst"
    apply_substitutions "$dst" "$agent_name"
  }

  # Athena workspace
  echo "  Copying Athena workspace files..."
  for file in SOUL.md IDENTITY.md AGENTS.md MEMORY.md CURRENT.md HEARTBEAT.md CLAUDE.md USER.md GOTCHAS.md NIGHTLY-NOTES.md OFFICE.md AGENT-ROSTER.md; do
    copy_with_substitutions "$REPO_DIR/workspaces/athena/$file" "$ATHENA_WORKSPACE/$file" "Athena"
  done
  echo -e "  ${GREEN}✓${RESET} Athena workspace at $ATHENA_WORKSPACE"

  # Other workspace agents
  for agent in poseidon icarus forge argus heracles recovery; do
    AGENT_WORKSPACE="$WORKSPACE_BASE/$agent"
    if [[ -d "$REPO_DIR/workspaces/$agent" ]]; then
      mkdir -p "$AGENT_WORKSPACE"
      AGENT_NAME_TITLE="$(echo "$agent" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
      for file in SOUL.md IDENTITY.md AGENTS.md MEMORY.md CURRENT.md HEARTBEAT.md CLAUDE.md GOTCHAS.md; do
        copy_with_substitutions "$REPO_DIR/workspaces/$agent/$file" "$AGENT_WORKSPACE/$file" "$AGENT_NAME_TITLE"
      done
      # Forge ships with a build queue file the others don't have.
      if [[ "$agent" == "forge" ]]; then
        copy_with_substitutions "$REPO_DIR/workspaces/forge/TASK-QUEUE.md" "$AGENT_WORKSPACE/TASK-QUEUE.md" "Forge"
      fi
      echo -e "  ${GREEN}✓${RESET} $agent workspace"
    fi
  done

  # Office team workspaces (Paperclip heartbeat workers, not Discord agents).
  # Office agents need SOUL/IDENTITY/AGENTS/CLAUDE per CLAUDE.md spec, plus
  # MEMORY/CURRENT when present so heartbeats have somewhere to write state.
  mkdir -p "$WORKSPACE_BASE/office"
  for office_agent in copywriter outreach analytics seo social ads visual-director; do
    OFFICE_WORKSPACE="$WORKSPACE_BASE/office/$office_agent"
    if [[ -d "$REPO_DIR/workspaces/office/$office_agent" ]]; then
      mkdir -p "$OFFICE_WORKSPACE"
      OFFICE_TITLE="$(echo "$office_agent" | awk '{
        n=split($0,a,"-"); out="";
        for (i=1;i<=n;i++) out=out (i>1?" ":"") toupper(substr(a[i],1,1)) substr(a[i],2);
        print out
      }')"
      for file in SOUL.md IDENTITY.md AGENTS.md CLAUDE.md MEMORY.md CURRENT.md; do
        copy_with_substitutions \
          "$REPO_DIR/workspaces/office/$office_agent/$file" \
          "$OFFICE_WORKSPACE/$file" \
          "$OFFICE_TITLE"
      done
      echo -e "  ${GREEN}✓${RESET} office/$office_agent workspace"
    fi
  done

  # Athena skills
  if [[ -d "$REPO_DIR/workspaces/athena/skills" ]]; then
    mkdir -p "$ATHENA_WORKSPACE/skills"
    cp -r "$REPO_DIR/workspaces/athena/skills/." "$ATHENA_WORKSPACE/skills/"
    echo -e "  ${GREEN}✓${RESET} Athena skills"
  fi

  # Extra Athena template that doesn't ship in workspaces/athena/.
  if [[ -f "$REPO_DIR/templates/BUDGETS.md" ]]; then
    copy_with_substitutions "$REPO_DIR/templates/BUDGETS.md" "$ATHENA_WORKSPACE/BUDGETS.md" "Athena"
  fi
  echo -e "  ${GREEN}✓${RESET} Templates copied with placeholders substituted"

  mkdir -p "$ATHENA_WORKSPACE/memory/archive"
  echo -e "  ${GREEN}✓${RESET} Memory directories"

  mark_step workspaces
fi

# =============================================================================
# STEP 9 — Start Gateway
# =============================================================================

if step_done gateway; then
  echo -e "${GREEN}✓${RESET} Step 9 (gateway) already completed. Skipping."
  GATEWAY_OK=true
else
  echo ""
  echo -e "${BOLD}Step 9 — Starting the gateway${RESET}"
  echo ""

  GATEWAY_OK=false
  case "${RUNTIME:-openclaw}" in
    hermes)
      RUNTIME_BIN="hermes"
      GATEWAY_START_CMD=(hermes gateway start)
      GATEWAY_RUN_CMD=(hermes gateway start --background)
      DOCTOR_CMD=(hermes doctor)
      ;;
    openclaw|*)
      RUNTIME_BIN="openclaw"
      GATEWAY_START_CMD=(openclaw gateway start)
      GATEWAY_RUN_CMD=(openclaw gateway run)
      DOCTOR_CMD=(openclaw doctor)
      ;;
  esac

  echo "  Starting $RUNTIME_BIN gateway..."
  set +e
  if "${GATEWAY_START_CMD[@]}"; then
    GATEWAY_OK=true
  else
    echo -e "  ${YELLOW}⚠${RESET}  '${GATEWAY_START_CMD[*]}' failed, trying background mode..."
    "${GATEWAY_RUN_CMD[@]}" &
    sleep 4
  fi
  set -e

  # Poll the runtime's doctor for liveness (gateway boot takes time).
  for _ in 1 2 3 4 5; do
    if "${DOCTOR_CMD[@]}" &>/dev/null; then
      GATEWAY_OK=true
      break
    fi
    sleep 2
  done

  if [[ "$GATEWAY_OK" == "true" ]]; then
    echo -e "  ${GREEN}✓${RESET} Gateway is running and healthy"
    mark_step gateway
  else
    echo -e "  ${YELLOW}⚠${RESET}  Gateway may not be running. Diagnose: ${DOCTOR_CMD[*]}"
    echo -e "  Then start manually: ${GATEWAY_START_CMD[*]}"
    echo -e "  ${YELLOW}Everything else is configured. Re-run this script to retry the gateway.${RESET}"
  fi
fi

# =============================================================================
# STEP 10 — Content Studio (Open Design)  (optional)
# =============================================================================
#
# Open Design (https://github.com/nexu-io/open-design) is the OSS alternative
# to Claude Design. Local-first, BYOK, drives any installed coding-agent CLI
# with 19 composable Skills + 71 design systems. Athena uses it to generate
# social cards, blog posts, decks, landing pages, and product visuals from
# a single prompt.
#
# We clone to ~/Apps/open-design and pnpm install. Heavier than Design
# Studio: pulls a Next.js app + better-sqlite3. Fully optional.
#

if step_done open_design; then
  echo -e "${GREEN}✓${RESET} Step 10 (Open Design / content studio) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 10 — Content Studio (Open Design)${RESET} ${YELLOW}(optional, recommended)${RESET}"
  echo ""
  echo "  Open Design is the OSS alternative to Claude Design. Drives your"
  echo "  existing Claude / Codex / Gemini CLI to generate social cards,"
  echo "  blog posts, decks, landing pages, and product visuals from a"
  echo "  single prompt, picking from 71 brand-grade design systems."
  echo ""
  echo "  Repo:        https://github.com/nexu-io/open-design"
  echo "  Install path: \$HOME/Apps/open-design"
  echo "  Disk usage:   ~500MB after pnpm install"
  echo "  Dev server:   pnpm dev:all (daemon :7456 + web :3000)"
  echo ""
  read -r -p "  Install Open Design? (y/n): " install_open_design

  if [[ "$install_open_design" == "y" ]]; then
    OD_DIR="$HOME/Apps/open-design"
    mkdir -p "$HOME/Apps"

    if [[ -d "$OD_DIR/.git" ]]; then
      echo "  Existing checkout at $OD_DIR, pulling latest..."
      git -C "$OD_DIR" pull --ff-only 2>/dev/null || \
        echo -e "  ${YELLOW}⚠${RESET}  Could not fast-forward. Update manually: cd $OD_DIR && git pull"
    else
      echo "  Cloning nexu-io/open-design to $OD_DIR..."
      if ! git clone --depth 1 https://github.com/nexu-io/open-design.git "$OD_DIR" 2>&1 | tail -3; then
        echo -e "  ${YELLOW}⚠${RESET}  Clone failed. Check network or clone manually:"
        echo "     git clone https://github.com/nexu-io/open-design.git $OD_DIR"
      fi
    fi

    if [[ -d "$OD_DIR" ]]; then
      # Open Design pins pnpm via packageManager and needs Node 20-22.
      # Activate corepack so the right pnpm version is on PATH.
      if command -v corepack &>/dev/null; then
        corepack enable 2>/dev/null || true
      else
        echo -e "  ${YELLOW}⚠${RESET}  corepack not found; pnpm activation may fail"
      fi

      echo "  Running pnpm install (this may take a few minutes)..."
      if (cd "$OD_DIR" && pnpm install 2>&1 | tail -5); then
        echo -e "  ${GREEN}✓${RESET} Open Design installed"
        echo ""
        echo -e "  ${BOLD}Start it with:${RESET}"
        echo "    cd $OD_DIR && pnpm dev:all"
        echo "  Then open http://localhost:3000"
      else
        echo -e "  ${YELLOW}⚠${RESET}  pnpm install failed. Run manually: cd $OD_DIR && pnpm install"
        echo "     If pnpm itself is missing: corepack enable && corepack prepare pnpm@latest --activate"
      fi

      set_secret OPEN_DESIGN_PATH "$OD_DIR"
    fi
  else
    echo "  Skipped. Install later with: git clone https://github.com/nexu-io/open-design.git \$HOME/Apps/open-design && cd \$HOME/Apps/open-design && pnpm install"
  fi

  mark_step open_design
fi

# =============================================================================
# STEP 11 — Design Studio (Playwright + Firecrawl)  (optional)
# =============================================================================

if step_done design_studio; then
  echo -e "${GREEN}✓${RESET} Step 11 (design studio) already completed. Skipping."
else
  echo ""
  echo -e "${BOLD}Step 11 — Design Studio${RESET} ${YELLOW}(optional)${RESET}"
  echo ""
  echo "  Lower-level utilities — separate from Open Design (Step 10):"
  echo "    - Playwright: browser automation + screenshots"
  echo "    - Firecrawl CLI: web scraping + search"
  echo ""
  read -r -p "  Install Design Studio? (y/n): " install_design_studio

  if [[ "$install_design_studio" == "y" ]]; then
    echo ""
    echo "  Installing Playwright..."
    if npm_global_install playwright; then
      echo -e "  ${GREEN}✓${RESET} Playwright installed"
      echo "  Installing Chromium (may take several minutes)..."
      if npx --yes playwright install chromium; then
        echo -e "  ${GREEN}✓${RESET} Chromium installed"
      else
        echo -e "  ${YELLOW}⚠${RESET}  Chromium install failed; run 'npx playwright install chromium' manually"
      fi
    else
      echo -e "  ${YELLOW}⚠${RESET}  Playwright install failed; run '$SUDO npm install -g playwright' manually"
    fi

    echo "  Installing Firecrawl CLI..."
    if npm_global_install firecrawl-cli; then
      echo -e "  ${GREEN}✓${RESET} Firecrawl CLI installed"
    else
      echo -e "  ${YELLOW}⚠${RESET}  Firecrawl CLI install failed; package may not be on npm"
    fi

    echo ""
    echo -e "  ${GREEN}✓${RESET} Design Studio ready. Use /creative in Discord."
  else
    echo "  Skipped. You can run install.sh again later to add it."
  fi

  mark_step design_studio
fi

# =============================================================================
# DONE
# =============================================================================

echo ""
if [[ "$GATEWAY_OK" == "true" ]]; then
  echo -e "${BOLD}${GREEN}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║   ✅ Athena is ready!                     ║"
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${RESET}"
else
  echo -e "${BOLD}${YELLOW}"
  echo "  ╔═══════════════════════════════════════════╗"
  echo "  ║   ⚠  Almost ready, fix the gateway       ║"
  if [[ "${RUNTIME:-openclaw}" == "hermes" ]]; then
    echo "  ║   Run: hermes gateway start               ║"
  else
    echo "  ║   Run: openclaw gateway start             ║"
  fi
  echo "  ╚═══════════════════════════════════════════╝"
  echo -e "${RESET}"
fi
echo ""
echo -e "  ${BOLD}Go to Discord, find #🦉〡athena, type:${RESET}"
echo ""
echo -e "    ${CYAN}Hi Athena, I'm ready to set up the system.${RESET}"
echo ""
echo "  Athena walks you through the rest:"
echo "    > Set up remaining Discord channels (or run scripts/discord-setup.js)"
echo "    > Configure all agents"
echo "    > Set up Paperclip + office team"
echo "    > Brief your projects"
echo "    > Configure nightly automation"
echo ""
echo -e "  ${YELLOW}You won't need to touch the terminal again.${RESET}"
echo ""
echo "  To re-run this script, just run: bash install.sh (it will resume)"
echo "  To start over: bash install.sh --reset"
echo ""
