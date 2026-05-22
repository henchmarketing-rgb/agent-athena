#!/bin/bash

# =============================================================================
# Athena 🦉 — Model Switcher
# =============================================================================
# Switch the active LLM provider and model across all agents.
#
# Usage:
#   bash scripts/switch-model.sh                    # interactive
#   bash scripts/switch-model.sh anthropic/claude-sonnet-4-6  # direct
# =============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_CONF="$REPO_DIR/config/model.conf"
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"

# --- helpers ------------------------------------------------------------------

current_model() {
  if [[ -f "$MODEL_CONF" ]]; then
    cat "$MODEL_CONF"
  else
    echo "anthropic/claude-sonnet-4-6"
  fi
}

write_model() {
  local model="$1"
  mkdir -p "$(dirname "$MODEL_CONF")"
  echo "$model" > "$MODEL_CONF"
}

patch_openclaw_json() {
  local model="$1"
  if [[ ! -f "$OPENCLAW_JSON" ]]; then
    echo -e "  ${YELLOW}Warning:${RESET} $OPENCLAW_JSON not found — skipping config patch."
    echo -e "  Update your openclaw.json manually: set all agent model fields to: $model"
    return
  fi
  if ! command -v jq &> /dev/null; then
    echo -e "  ${RED}Error:${RESET} jq is required to patch openclaw.json. Install it: brew install jq"
    exit 1
  fi
  jq --arg model "$model" '
    .agents |= with_entries(
      if (.value | type) == "object" and (.value | has("model"))
      then .value.model = $model
      else .
      end
    )
  ' "$OPENCLAW_JSON" > "${OPENCLAW_JSON}.tmp"
  if [[ -s "${OPENCLAW_JSON}.tmp" ]]; then
    mv "${OPENCLAW_JSON}.tmp" "$OPENCLAW_JSON"
  else
    echo -e "  ${RED}Error:${RESET} Patch produced empty output — original openclaw.json preserved."
    rm -f "${OPENCLAW_JSON}.tmp"
    return 1
  fi
  echo -e "  ${GREEN}✓${RESET} Updated all agents in openclaw.json to: $model"
}

restart_gateway() {
  echo -e "  Restarting gateway..."
  if timeout 30 openclaw gateway restart; then
    echo -e "  ${GREEN}✓${RESET} Gateway restarted"
  else
    echo -e "  ${YELLOW}Warning:${RESET} Gateway restart failed or timed out."
    echo -e "  Restart manually: ${CYAN}openclaw gateway restart${RESET}"
  fi
}

do_anthropic_auth() {
  echo ""
  echo -e "  ${BOLD}Anthropic auth:${RESET}"
  echo "    1) Setup-token (uses your Claude subscription — recommended)"
  echo "    2) API key (usage-based billing)"
  echo ""
  read -p "  Enter 1 or 2: " auth_choice
  if [[ "$auth_choice" == "1" ]]; then
    echo ""
    echo -e "  Generating setup-token..."
    claude setup-token
    echo ""
    openclaw models auth setup-token --provider anthropic
  elif [[ "$auth_choice" == "2" ]]; then
    echo ""
    read -s -p "  Paste your Anthropic API key: " api_key
    echo ""
    echo "$api_key" | openclaw models auth paste-token --provider anthropic
  fi
}

do_openai_auth() {
  echo ""
  read -s -p "  Paste your OpenAI API key: " api_key
  echo ""
  echo "$api_key" | openclaw models auth paste-token --provider openai
}

do_gemini_auth() {
  echo ""
  read -s -p "  Paste your Google Gemini API key: " api_key
  echo ""
  echo "$api_key" | openclaw models auth paste-token --provider google
}

do_ollama_auth() {
  echo ""
  read -p "  Ollama base URL (default: http://localhost:11434): " base_url
  base_url="${base_url:-http://localhost:11434}"
  openclaw models auth login --provider ollama --base-url "$base_url"
}

do_custom_auth() {
  echo ""
  read -p "  Base URL (e.g. https://api.together.xyz/v1): " base_url
  read -s -p "  API key: " api_key
  echo ""
  echo "$api_key" | openclaw models auth paste-token --provider custom --base-url "$base_url"
}

SELECTED_MODEL=""

provider_menu() {
  echo ""
  echo -e "${BOLD}Choose a model provider:${RESET}"
  echo "  1) Anthropic (Claude) — recommended"
  echo "  2) OpenAI (GPT-4)"
  echo "  3) Google (Gemini)"
  echo "  4) Ollama (local)"
  echo "  5) Custom (any OpenAI-compatible endpoint)"
  echo ""
  read -p "  Enter 1–5: " provider_choice

  case "$provider_choice" in
    1)
      do_anthropic_auth
      read -p "  Model string (default: anthropic/claude-sonnet-4-6): " model_str
      SELECTED_MODEL="${model_str:-anthropic/claude-sonnet-4-6}"
      ;;
    2)
      do_openai_auth
      read -p "  Model string (default: openai/gpt-4o): " model_str
      SELECTED_MODEL="${model_str:-openai/gpt-4o}"
      ;;
    3)
      do_gemini_auth
      read -p "  Model string (default: google/gemini-2.0-flash): " model_str
      SELECTED_MODEL="${model_str:-google/gemini-2.0-flash}"
      ;;
    4)
      do_ollama_auth
      read -p "  Model string (e.g. ollama/llama3): " model_str
      if [[ -z "$model_str" ]]; then
        echo -e "  ${RED}Error:${RESET} Model string is required for Ollama."
        exit 1
      fi
      SELECTED_MODEL="$model_str"
      ;;
    5)
      do_custom_auth
      read -p "  Model string (e.g. together/meta-llama-3-70b): " model_str
      if [[ -z "$model_str" ]]; then
        echo -e "  ${RED}Error:${RESET} Model string is required for custom provider."
        exit 1
      fi
      SELECTED_MODEL="$model_str"
      ;;
    *)
      echo -e "  ${RED}Invalid choice.${RESET}"
      exit 1
      ;;
  esac
}

# --- main ---------------------------------------------------------------------

echo ""
echo -e "${BOLD}${CYAN}Athena 🦉 — Model Switcher${RESET}"
echo ""
echo -e "  Current model: ${CYAN}$(current_model)${RESET}"
echo ""

# Direct arg mode
if [[ -n "$1" ]]; then
  SELECTED_MODEL="$1"
  echo -e "  Switching to: ${CYAN}$SELECTED_MODEL${RESET}"
  echo ""
  echo -e "  ${YELLOW}Note:${RESET} Direct mode skips auth setup."
  echo -e "  If switching providers, make sure credentials are configured first:"
  echo -e "  Run ${CYAN}openclaw models auth${RESET} or use interactive mode: ${CYAN}bash scripts/switch-model.sh${RESET}"
  echo ""
else
  # Interactive mode
  provider_menu
fi

echo ""
# Preflight: check jq is available before writing anything
if [[ -f "$OPENCLAW_JSON" ]] && ! command -v jq &> /dev/null; then
  echo -e "  ${RED}Error:${RESET} jq is required to patch openclaw.json. Install it: brew install jq"
  exit 1
fi
write_model "$SELECTED_MODEL"
echo -e "  ${GREEN}✓${RESET} model.conf updated: $SELECTED_MODEL"

patch_openclaw_json "$SELECTED_MODEL"
restart_gateway

echo ""
echo -e "${GREEN}Done.${RESET} All agents now running on: ${CYAN}$SELECTED_MODEL${RESET}"
echo ""
