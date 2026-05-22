#!/usr/bin/env bash
#
# tests/real-install.sh
#
# Like tests/e2e-install.sh but stubs ONLY the credential-requiring binaries
# (claude, openclaw). Everything else — apt-get, brew, npm install -g pm2,
# real Node/git/jq/gh — runs for real.
#
# This is the proper fresh-box smoke test. Designed to run on:
#   - GitHub Actions ubuntu-latest (catches real apt-get + sudo + npm -g)
#   - GitHub Actions macos-latest (catches real brew + real npm -g)
#
# Stubs:
#   - claude: stubs `claude setup-token` (prevents real Anthropic auth flow)
#   - openclaw: stubs `openclaw onboard` (interactive), `gateway`, `doctor`
#
# Asserts the same things tests/e2e-install.sh does plus:
#   - npm install -g actually completed for non-stubbed packages (pm2)
#   - jq is real after apt-get / brew installed it
#
# Usage:
#   bash tests/real-install.sh           # foreground
#   bash tests/real-install.sh -v        # verbose
#

set -euo pipefail

VERBOSE=false
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d -t athena-real.XXXXXX)"
FAKE_HOME="$SANDBOX/home"
STUB_BIN="$SANDBOX/stubs"
mkdir -p "$FAKE_HOME" "$STUB_BIN"

pass() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAILED=1; }
log()  { printf "  %s\n" "$*"; }

cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Stubs — only claude and openclaw, the credential/interactive ones
# -----------------------------------------------------------------------------

cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
# stub: claude
case "$1" in
  setup-token) echo "stub-setup-token-XXXXXXXXXXXXXXXX" ;;
  --version)   echo "stub-claude 0.0.0" ;;
  *)           : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/claude"

cat > "$STUB_BIN/openclaw" <<'EOF'
#!/usr/bin/env bash
# stub: openclaw
case "$1" in
  doctor)   exit 0 ;;
  gateway)  exit 0 ;;
  onboard)  exit 0 ;;
  models)   exit 0 ;;
  --version) echo "stub-openclaw 0.0.0" ;;
  *)        exit 0 ;;
esac
EOF
chmod +x "$STUB_BIN/openclaw"

# Stub gh too: the sandbox uses a fresh fake HOME, so real `gh auth status`
# will fail (no auth file there) and trigger an extra GITHUB_TOKEN prompt
# that shifts every subsequent scripted input by one position.
cat > "$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
# stub: gh — pretend authed in the sandbox
case "$1 $2" in
  "auth status") exit 0 ;;
  "api user")    echo "test-github-user" ;;
  *)             : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/gh"

# -----------------------------------------------------------------------------
# Scripted input — same prompt sequence as install.sh
# -----------------------------------------------------------------------------

scripted_answers() {
  printf '%s\n' \
    "y"                              `# banner press enter` \
    "Jordan"                         `# operator: short name` \
    "Jordan Lee"                     `# operator: full name` \
    "Jo"                             `# operator: preferred name` \
    "jordanlee"                      `# operator: github user` \
    "+7"                             `# operator: timezone` \
    "alex#1234"                      `# operator: discord handle` \
    "Smith Co."                      `# operator: business name` \
    "1"                              `# provider: 1=Anthropic` \
    "1"                              `# anthropic auth: 1=setup-token` \
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
    "1"                              `# step7: runtime choice (1=OpenClaw)` \
    ""                               `# step7c: press enter for onboard` \
    "n"                              `# step10: install open design?` \
    "n"                              `# step11: install design studio?`
}

# -----------------------------------------------------------------------------
# Run install.sh
# -----------------------------------------------------------------------------
#
# We prepend $STUB_BIN to PATH so install.sh's `command -v claude` and
# `command -v openclaw` find our stubs and skip the global-npm-install path
# for those. Everything else (npm install -g pm2, apt-get install jq, etc.)
# runs for real against the host.

OS="$(uname -s)"
log "running install.sh with real deps on $OS"
log "sandbox: $SANDBOX"
INSTALL_LOG="$SANDBOX/install.log"
FAILED=0

# Note: we DO NOT use `env -i` here — we want install.sh to see the real PATH
# so apt-get / brew / npm work.
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
  pass "install.sh exited 0 with real dependencies"
fi

# -----------------------------------------------------------------------------
# Assertions — same as e2e plus real-dep checks
# -----------------------------------------------------------------------------

SECRETS="$FAKE_HOME/.env.secrets"
if [[ -f "$SECRETS" ]]; then pass "secrets file at $SECRETS"; else fail "secrets file missing"; fi

for key in DISCORD_BOT_TOKEN DISCORD_ATHENA_CHANNEL_ID DISCORD_RECOVERY_CHANNEL_ID \
           FIRECRAWL_API_KEY ATHENA_REPO OPERATOR_NAME OPERATOR_GITHUB; do
  if grep -q "^${key}=" "$SECRETS" 2>/dev/null; then
    pass "secret present: $key"
  else
    fail "secret missing: $key"
  fi
done

STATE="$FAKE_HOME/.athena-install-state"
if [[ -f "$STATE" ]]; then pass "state file at $STATE"; else fail "state file missing"; fi

for step in dependencies operator_info model_provider discord other_credentials \
            shell_profile runtime_choice runtime_install runtime_onboard \
            workspaces gateway open_design design_studio; do
  if grep -q "^step_${step}=done$" "$STATE" 2>/dev/null; then
    pass "step done: $step"
  else
    fail "step missing or not done: $step"
  fi
done

# Real-dep specific assertions
WORKSPACE="$FAKE_HOME/.openclaw/workspaces/athena"
if [[ -d "$WORKSPACE" ]]; then
  pass "athena workspace exists"
  if grep -q "Alex" "$WORKSPACE/USER.md" && ! grep -q "\[OPERATOR_NAME\]" "$WORKSPACE/USER.md"; then
    pass "USER.md substitution applied"
  else
    fail "USER.md substitution failed"
  fi
fi

# Verify npm-installable global tools were either pre-existing or got installed
# (install.sh doesn't fail if npm install -g fails, but logs ⚠ — check log)
if grep -q "pm2 install failed" "$INSTALL_LOG" || grep -q "claude CLI install failed" "$INSTALL_LOG" || grep -q "openclaw install failed" "$INSTALL_LOG"; then
  fail "one or more npm install -g paths failed (see install.log)"
else
  pass "npm install -g path completed for missing dependencies"
fi

# Verify jq is present after the install (was either pre-installed or just installed)
if command -v jq &>/dev/null; then
  pass "jq is present (pre-existing or installed by install.sh)"
else
  fail "jq missing — pkg_install path failed"
fi

# -----------------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------------

echo ""
if [[ $FAILED -eq 0 ]]; then
  printf "  \033[1;32m✅ REAL-INSTALL PASSED on %s\033[0m\n" "$OS"
  exit 0
else
  printf "  \033[1;31m❌ REAL-INSTALL FAILED on %s\033[0m  (sandbox: %s)\n" "$OS" "$SANDBOX"
  trap - EXIT  # keep sandbox for debugging
  exit 1
fi
