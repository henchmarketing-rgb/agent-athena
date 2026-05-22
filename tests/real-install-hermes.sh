#!/usr/bin/env bash
#
# tests/real-install-hermes.sh
#
# Like tests/real-install.sh but exercises the Hermes Agent runtime path
# (Step 7 choice = 2). Stubs ONLY claude, gh, and hermes — everything else
# (npm install -g pm2, real apt-get / brew, real node, real jq) runs against
# the host like real-install.sh.
#
# Asserts:
#   - state file shows runtime=hermes + runtime_choice/runtime_install/runtime_onboard done
#   - secrets file contains ATHENA_RUNTIME=hermes
#   - workspaces are created at $HOME/.hermes/workspaces/<agent>/
#   - hermes-setup.js wrote $HOME/.hermes/cli-config.yaml
#   - hermes-setup.js wrote $HOME/.hermes/.env
#
# Usage:
#   bash tests/real-install-hermes.sh           # foreground
#   bash tests/real-install-hermes.sh -v        # verbose
#

set -euo pipefail

VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d -t athena-real-hermes.XXXXXX)"
FAKE_HOME="$SANDBOX/home"
STUB_BIN="$SANDBOX/stubs"
mkdir -p "$FAKE_HOME" "$STUB_BIN"

pass() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAILED=1; }
log()  { printf "  %s\n" "$*"; }

cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Stubs
# -----------------------------------------------------------------------------

cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  setup-token) echo "stub-setup-token-XXXXXXXXXXXXXXXX" ;;
  --version)   echo "stub-claude 0.0.0" ;;
  *)           : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/claude"

cat > "$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "api user")    echo "test-github-user" ;;
  *)             : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/gh"

# Stub `hermes`. install.sh's Hermes branch detects an existing hermes binary
# via `command -v hermes`, so this short-circuits the `git clone + bash
# setup-hermes.sh` block and lets the real `node scripts/hermes-setup.js`
# call follow-on stubs for `--version`, `cron`, `gateway`, `doctor`.
cat > "$STUB_BIN/hermes" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "stub-hermes 0.12.0" ;;
  login)     exit 0 ;;
  gateway)   exit 0 ;;
  doctor)    exit 0 ;;
  cron)      exit 0 ;;
  *)         exit 0 ;;
esac
EOF
chmod +x "$STUB_BIN/hermes"

# -----------------------------------------------------------------------------
# Scripted answers — same as real-install.sh but picks 2 (Hermes) at Step 7.
# -----------------------------------------------------------------------------

scripted_answers() {
  printf '%s\n' \
    "y"                              `# banner: press enter` \
    "Jordan"                         `# operator: short name` \
    "Jordan Lee"                     `# operator: full name` \
    "Jo"                             `# operator: preferred name` \
    "jordanlee"                      `# operator: github user` \
    "+7"                             `# operator: timezone` \
    "alex#1234"                      `# operator: discord handle` \
    "Smith Co."                      `# operator: business name` \
    "1"                              `# provider: 1=Anthropic` \
    "2"                              `# anthropic auth: 2=API key` \
    "sk-ant-stub-1234567890"         `# anthropic api key` \
    "y"                              `# discord: already have a bot?` \
    "fake-discord-bot-token-12345"   `# discord: bot token` \
    "99999999999999"                 `# discord: guild id` \
    "111222333444"                   `# discord: your user id` \
    "1001"                           `# discord: athena channel` \
    "1002"                           `# discord: poseidon channel` \
    "1003"                           `# discord: icarus channel` \
    "1004"                           `# discord: heracles channel` \
    "1005"                           `# discord: forge channel` \
    "1006"                           `# discord: argus channel` \
    "1007"                           `# discord: recovery channel` \
    ""                               `# step5: brave api key (skip)` \
    ""                               `# step5: vercel token (skip)` \
    "firecrawl-stub-key"             `# step5: firecrawl api key` \
    ""                               `# step5: alert webhook url (skip)` \
    ""                               `# step5: chrome cdp port (skip)` \
    "2"                              `# step7: runtime choice (2=Hermes)` \
    "n"                              `# step10: install open design?` \
    "n"                              `# step11: install design studio?`
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

OS="$(uname -s)"
log "running install.sh (Hermes runtime) with real deps on $OS"
log "sandbox: $SANDBOX"
INSTALL_LOG="$SANDBOX/install.log"
FAILED=0

export HOME="$FAKE_HOME"
export PATH="$STUB_BIN:$PATH"

set +e
if [[ "$VERBOSE" == "true" ]]; then
  scripted_answers | bash "$REPO_DIR/install.sh" 2>&1 | tee "$INSTALL_LOG"
else
  scripted_answers | bash "$REPO_DIR/install.sh" > "$INSTALL_LOG" 2>&1
fi
INSTALL_EXIT=$?
set -e

if [[ $INSTALL_EXIT -ne 0 ]]; then
  fail "install.sh exited $INSTALL_EXIT"
  log "last 40 lines of install.log:"
  tail -n 40 "$INSTALL_LOG" | sed 's/^/    /'
else
  pass "install.sh exited 0 with Hermes runtime"
fi

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

SECRETS="$FAKE_HOME/.env.secrets"
if [[ -f "$SECRETS" ]]; then pass "secrets file at $SECRETS"; else fail "secrets file missing"; fi

if grep -q "^ATHENA_RUNTIME=hermes$" "$SECRETS" 2>/dev/null; then
  pass "ATHENA_RUNTIME=hermes recorded"
else
  fail "ATHENA_RUNTIME=hermes missing from secrets"
fi

STATE="$FAKE_HOME/.athena-install-state"
if [[ -f "$STATE" ]]; then pass "state file at $STATE"; else fail "state file missing"; fi

if grep -q "^runtime=hermes$" "$STATE" 2>/dev/null; then
  pass "state runtime=hermes"
else
  fail "state runtime=hermes missing"
fi

for step in dependencies operator_info model_provider discord other_credentials \
            shell_profile runtime_choice runtime_install runtime_onboard \
            workspaces gateway open_design design_studio; do
  if grep -q "^step_${step}=done$" "$STATE" 2>/dev/null; then
    pass "step done: $step"
  else
    fail "step missing or not done: $step"
  fi
done

# Workspace under Hermes home
WORKSPACE="$FAKE_HOME/.hermes/workspaces/athena"
if [[ -d "$WORKSPACE" ]]; then
  pass "athena workspace at $WORKSPACE"
  if grep -q "Alex" "$WORKSPACE/USER.md" 2>/dev/null && ! grep -q "\[OPERATOR_NAME\]" "$WORKSPACE/USER.md" 2>/dev/null; then
    pass "USER.md substitution applied"
  else
    fail "USER.md substitution missing"
  fi
else
  fail "athena workspace dir not at $WORKSPACE"
fi

# hermes-setup.js outputs
HERMES_CFG="$FAKE_HOME/.hermes/cli-config.yaml"
HERMES_ENV="$FAKE_HOME/.hermes/.env"
if [[ -f "$HERMES_CFG" ]]; then
  pass "cli-config.yaml at $HERMES_CFG"
  if grep -q "system_prompt:" "$HERMES_CFG" && grep -q "SOUL.md" "$HERMES_CFG"; then
    pass "cli-config.yaml references SOUL.md system_prompt"
  else
    fail "cli-config.yaml missing system_prompt block"
  fi
else
  fail "cli-config.yaml missing"
fi
if [[ -f "$HERMES_ENV" ]]; then
  pass ".env at $HERMES_ENV"
  if grep -q "^DISCORD_BOT_TOKEN=" "$HERMES_ENV"; then
    pass ".env has DISCORD_BOT_TOKEN"
  else
    fail ".env missing DISCORD_BOT_TOKEN"
  fi
else
  fail ".env missing"
fi

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------

if [[ "${FAILED:-0}" -eq 0 ]]; then
  echo ""
  printf "  \033[1;32m✅ HERMES E2E PASSED\033[0m\n"
  exit 0
else
  echo ""
  printf "  \033[1;31m❌ HERMES E2E FAILED\033[0m\n"
  log "install.log retained for inspection at: $INSTALL_LOG (sandbox $SANDBOX)"
  exit 1
fi
