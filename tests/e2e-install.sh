#!/usr/bin/env bash
#
# tests/e2e-install.sh
#
# End-to-end test for install.sh that runs in a fully sandboxed environment:
#
#   - $HOME points at a temp directory (no real ~/.env.secrets touched)
#   - $PATH front-loads stub binaries for claude, openclaw, npm, gh, brew,
#     apt-get, dnf, yum, pacman, apk (all return success without doing anything)
#   - Inputs are scripted via heredoc and fed to bash on stdin
#   - On exit, the script asserts:
#       * $HOME/.env.secrets exists with all expected secrets
#       * $HOME/.athena-install-state has all step_* keys = "done"
#       * $HOME/.openclaw/workspaces/athena/USER.md has substituted placeholders
#       * No raw [PLACEHOLDER] tokens remain in any workspace file
#       * Re-running install.sh exits cleanly without re-prompting (resume path)
#       * --reset wipes state and forces re-prompt
#
# Usage:
#   bash tests/e2e-install.sh           # run, fail-fast on assertion miss
#   bash tests/e2e-install.sh -v        # verbose — show install.sh output
#   bash tests/e2e-install.sh --keep    # keep the sandbox dir for inspection
#

set -euo pipefail

VERBOSE=false
KEEP=false
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
    --keep)       KEEP=true ;;
    -h|--help)    sed -n '3,28p' "$0"; exit 0 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d -t athena-e2e.XXXXXX)"
FAKE_HOME="$SANDBOX/home"
STUB_BIN="$SANDBOX/stubs"
mkdir -p "$FAKE_HOME" "$STUB_BIN"

log()  { printf "  %s\n" "$*"; }
pass() { printf "  \033[32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAILED=1; }

cleanup() {
  if [[ "$KEEP" == "true" ]]; then
    log "sandbox preserved at: $SANDBOX"
  else
    rm -rf "$SANDBOX"
  fi
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Stub external commands
# -----------------------------------------------------------------------------

write_stub() {
  local name="$1"
  shift
  cat > "$STUB_BIN/$name" <<EOF
#!/usr/bin/env bash
# stub for $name in e2e test
$*
EOF
  chmod +x "$STUB_BIN/$name"
}

write_stub claude '
case "$1" in
  setup-token) echo "stub-setup-token-XXXXXXXXXXXXXXXX" ;;
  *)           : ;;
esac
exit 0
'

write_stub openclaw '
case "$1" in
  doctor)         exit 0 ;;
  gateway)        exit 0 ;;
  onboard)        exit 0 ;;
  models)         exit 0 ;;
  *)              exit 0 ;;
esac
'

write_stub npm '
# Pretend any npm install -g succeeded.
case "$1" in
  install) exit 0 ;;
  *)       exit 0 ;;
esac
'

write_stub gh '
case "$1 $2" in
  "auth status")  exit 0 ;;
  "api user")     echo "test-github-user" ;;
  *)              : ;;
esac
exit 0
'

# Linux package managers — return success even on macOS so the dep-install
# branch is exercised end-to-end without needing the real package manager.
write_stub apt-get  'exit 0'
write_stub dnf      'exit 0'
write_stub yum      'exit 0'
write_stub pacman   'exit 0'
write_stub apk      'exit 0'

# Pre-mark dependencies as present so install.sh doesn't try to install them.
# We do this by stubbing the `command -v` checks: install.sh uses `command -v
# <bin>`, which uses PATH. Stub the binaries:
write_stub jq    'exit 0'
write_stub pm2   'exit 0'
write_stub node  '
case "$1" in
  --version) echo "v20.11.0" ;;
  --check)   exit 0 ;;
  *)         exit 0 ;;
esac
'
write_stub git   'exit 0'
write_stub npx   'exit 0'

# -----------------------------------------------------------------------------
# Run install.sh against the sandbox
# -----------------------------------------------------------------------------

# Scripted answers, one per `read` prompt in install.sh.
# Step 1: dependencies (no prompts)
# Step 2: operator info — 7 prompts
# Step 3: model provider — 2 prompts (provider 1=Anthropic, auth 1=setup-token)
# Step 4: discord — 9 prompts (has-bot=y, token, guild, user, 7 channels)
# Step 5: other creds — 5 prompts (skip GH, brave, vercel, firecrawl, cdp)
# Step 7: openclaw onboard — 1 enter-to-continue
# Step 9: design studio — 1 (n)
# Initial banner enter

scripted_answers() {
  # Each line maps to one read prompt in install.sh, in order.
  # Comments after # describe what the prompt is asking.
  printf '%s\n' \
    "y"                              `# banner: Press Enter` \
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
    "1"                              `# step7: runtime choice (1=OpenClaw default)` \
    ""                               `# step7c: press enter for onboard` \
    "n"                              `# step10: install open design?` \
    "n"                              `# step11: install design studio?`
}

ENV=(
  "HOME=$FAKE_HOME"
  "PATH=$STUB_BIN:/usr/bin:/bin"
  "SHELL=/bin/bash"
)

log "running install.sh in sandbox: $SANDBOX"
INSTALL_LOG="$SANDBOX/install.log"
FAILED=0

set +e
if [[ "$VERBOSE" == "true" ]]; then
  scripted_answers | env -i "${ENV[@]}" bash "$REPO_DIR/install.sh" 2>&1 | tee "$INSTALL_LOG"
else
  scripted_answers | env -i "${ENV[@]}" bash "$REPO_DIR/install.sh" > "$INSTALL_LOG" 2>&1
fi
INSTALL_EXIT=$?
set -e

if [[ $INSTALL_EXIT -ne 0 ]]; then
  fail "install.sh exited with code $INSTALL_EXIT"
  log "last 30 lines of install.log:"
  tail -n 30 "$INSTALL_LOG"
else
  pass "install.sh ran to completion (exit 0)"
fi

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

# Secrets file
SECRETS="$FAKE_HOME/.env.secrets"
if [[ -f "$SECRETS" ]]; then
  pass "secrets file created at $SECRETS"
  for key in DISCORD_BOT_TOKEN DISCORD_GUILD_ID DISCORD_USER_ID \
             DISCORD_ATHENA_CHANNEL_ID DISCORD_POSEIDON_CHANNEL_ID \
             DISCORD_ICARUS_CHANNEL_ID DISCORD_HERACLES_CHANNEL_ID \
             DISCORD_FORGE_CHANNEL_ID DISCORD_ARGUS_CHANNEL_ID \
             DISCORD_RECOVERY_CHANNEL_ID FIRECRAWL_API_KEY \
             ATHENA_REPO OPERATOR_NAME OPERATOR_GITHUB; do
    if grep -q "^${key}=" "$SECRETS"; then
      pass "secret present: $key"
    else
      fail "secret missing: $key"
    fi
  done
else
  fail "secrets file not created"
fi

# State file
STATE="$FAKE_HOME/.athena-install-state"
if [[ -f "$STATE" ]]; then
  pass "state file created at $STATE"
  for step in dependencies operator_info model_provider discord \
              other_credentials shell_profile \
              runtime_choice runtime_install runtime_onboard \
              workspaces gateway open_design design_studio; do
    if grep -q "^step_${step}=done$" "$STATE"; then
      pass "step done: $step"
    else
      fail "step missing or not done: $step"
    fi
  done
else
  fail "state file not created"
fi

# Workspace files exist with substitutions applied
WORKSPACE_BASE="$FAKE_HOME/.openclaw/workspaces"
if [[ -d "$WORKSPACE_BASE/athena" ]]; then
  pass "athena workspace dir created"
else
  fail "athena workspace dir missing"
fi

# Verify a file was substituted: USER.md should contain "Alex" and not "[OPERATOR_NAME]"
USER_MD="$WORKSPACE_BASE/athena/USER.md"
if [[ -f "$USER_MD" ]]; then
  if grep -q "Alex" "$USER_MD" && ! grep -q "\[OPERATOR_NAME\]" "$USER_MD"; then
    pass "USER.md substitution applied"
  else
    fail "USER.md substitution failed (still has placeholders or missing 'Alex')"
    log "  USER.md head:"; head -10 "$USER_MD" | sed 's/^/    /'
  fi
  if grep -q "GMT+7" "$USER_MD"; then
    pass "USER.md timezone substituted to GMT+7"
  else
    fail "USER.md timezone not substituted (expected GMT+7)"
  fi
fi

# No raw placeholders should remain anywhere in workspaces
LEFTOVER="$(find "$WORKSPACE_BASE" -name '*.md' -print0 2>/dev/null | \
            xargs -0 grep -lE "\[(OPERATOR_NAME|AGENT NAME|Full Name|PREFERRED_NAME|GITHUB_USERNAME|DISCORD_USER_ID|BUSINESS_NAME)\]|GMT\+\[X\]" 2>/dev/null || true)"
if [[ -z "$LEFTOVER" ]]; then
  pass "no leftover placeholders in any workspace .md file"
else
  fail "placeholders left in:"
  echo "$LEFTOVER" | sed 's/^/    /'
fi

# Other agent workspaces should also exist
for agent in poseidon icarus forge argus heracles recovery; do
  if [[ -d "$WORKSPACE_BASE/$agent" ]]; then
    pass "agent workspace exists: $agent"
  else
    fail "agent workspace missing: $agent"
  fi
done

# -----------------------------------------------------------------------------
# Resume test: run install.sh again — it should skip everything
# -----------------------------------------------------------------------------

log "testing --resume (re-run with existing state)"
RESUME_LOG="$SANDBOX/resume.log"
set +e
echo "" | env -i "${ENV[@]}" bash "$REPO_DIR/install.sh" > "$RESUME_LOG" 2>&1
RESUME_EXIT=$?
set -e

# On a fully-completed state, re-run hits the banner Press-Enter prompt and the
# initial "About you" banner, then skips every step. Exit should be 0.
SKIP_COUNT=$(grep -c "already completed. Skipping." "$RESUME_LOG" || echo 0)
if [[ $RESUME_EXIT -eq 0 && $SKIP_COUNT -ge 9 ]]; then
  pass "resume skipped $SKIP_COUNT completed steps (exit 0)"
else
  fail "resume failed (exit $RESUME_EXIT, $SKIP_COUNT skips)"
  log "last 20 lines:"; tail -n 20 "$RESUME_LOG" | sed 's/^/    /'
fi

# -----------------------------------------------------------------------------
# Reset test: --reset wipes state file
# -----------------------------------------------------------------------------

log "testing --reset (wipe state and exit early)"
# We pipe an empty line (banner) then EOF — the script will start Step 1
# but exit when read fails. We just want to confirm state file was deleted.
set +e
echo "" | env -i "${ENV[@]}" bash "$REPO_DIR/install.sh" --reset >/dev/null 2>&1 || true
set -e

if [[ ! -f "$STATE" ]]; then
  pass "--reset removed state file"
else
  # Banner echo would prevent re-arming. Re-check: state file should still be
  # missing OR the new run started rebuilding it. We check the test below by
  # confirming the operator_info step needs to reprompt.
  if ! grep -q "step_operator_info=done" "$STATE" 2>/dev/null; then
    pass "--reset cleared step state (state file may exist but step_* are unset)"
  else
    fail "--reset did not clear state"
  fi
fi

# -----------------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------------

echo ""
if [[ $FAILED -eq 0 ]]; then
  printf "  \033[1;32m✅ E2E PASSED\033[0m\n"
  exit 0
else
  printf "  \033[1;31m❌ E2E FAILED\033[0m  (sandbox: %s)\n" "$SANDBOX"
  KEEP=true
  exit 1
fi
