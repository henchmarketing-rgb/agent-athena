#!/bin/bash
# full-backup.sh — backup OpenClaw workspace, sessions, and config
# Auto-pushes to GitHub so nothing is ever lost.
# Usage: bash full-backup.sh [--no-push]

set -e

BACKUP_ROOT="$HOME/athena-backups"
BACKUP_REPO="$BACKUP_ROOT/repo"
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M")
KEEP=10  # local backup copies to keep
NO_PUSH=false

if [[ "$1" == "--no-push" ]]; then
  NO_PUSH=true
fi

echo "🗄  Athena Backup — $TIMESTAMP"
echo ""

# ─── Local backup ────────────────────────────────────
DEST="$BACKUP_ROOT/local/$TIMESTAMP"
mkdir -p "$DEST"

# Backup all workspaces
if [ -d "$HOME/.openclaw/workspaces" ]; then
  rsync -a --quiet "$HOME/.openclaw/workspaces/" "$DEST/workspaces/"
  echo "  ✓ workspaces"
elif [ -d "$HOME/.openclaw/workspace" ]; then
  rsync -a --quiet "$HOME/.openclaw/workspace/" "$DEST/workspace/"
  echo "  ✓ workspace"
fi

# Backup agents (sessions)
if [ -d "$HOME/.openclaw/agents" ]; then
  rsync -a --quiet --exclude="*.tmp" "$HOME/.openclaw/agents/" "$DEST/agents/"
  echo "  ✓ agents/sessions"
fi

# Backup openclaw config
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  cp "$HOME/.openclaw/openclaw.json" "$DEST/openclaw.json"
  echo "  ✓ openclaw.json"
fi

# Backup PM2 ecosystem config
for ECOPATH in "$HOME/Apps/paperclip/ecosystem.config.js" "$HOME/.openclaw/ecosystem.config.js"; do
  if [ -f "$ECOPATH" ]; then
    cp "$ECOPATH" "$DEST/ecosystem.config.js"
    echo "  ✓ ecosystem.config.js"
    break
  fi
done

# Size summary
TOTAL=$(du -sh "$DEST" 2>/dev/null | cut -f1)
echo ""
echo "  Local: $TOTAL → $DEST"

# Prune old local backups
cd "$BACKUP_ROOT/local"
BACKUP_COUNT=$(ls -1d */ 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -gt "$KEEP" ]; then
  TO_DELETE=$(ls -1dt */ | tail -n +"$((KEEP + 1))")
  for DIR in $TO_DELETE; do
    rm -rf "$DIR"
    echo "  🗑  Pruned local: $DIR"
  done
fi

# ─── GitHub backup ───────────────────────────────────
if [[ "$NO_PUSH" == "true" ]]; then
  echo ""
  echo "  ⏭  Skipping GitHub push (--no-push)"
  echo ""
  echo "✅ Local backup complete."
  exit 0
fi

echo ""
echo "  Pushing to GitHub..."

# Initialize backup repo if it doesn't exist
if [ ! -d "$BACKUP_REPO/.git" ]; then
  echo "  Setting up backup repository..."
  mkdir -p "$BACKUP_REPO"
  cd "$BACKUP_REPO"
  git init
  echo "# Athena Backups" > README.md
  echo "Automated backups of workspace files, agent configs, and memory." >> README.md
  echo "" >> README.md
  echo "**Do not store secrets here.** Secrets live in ~/.env.secrets only." >> README.md
  git add README.md
  git commit -m "init: athena backup repo"

  echo ""
  echo "  ⚠️  Backup repo created at: $BACKUP_REPO"
  echo "  You need to create a GitHub repo and set the remote:"
  echo ""
  echo "    cd $BACKUP_REPO"
  echo "    gh repo create athena-backups --private --source=. --push"
  echo ""
  echo "  Or manually:"
  echo "    git remote add origin git@github.com:YOUR_USERNAME/athena-backups.git"
  echo "    git push -u origin main"
  echo ""
  echo "  After that, backups auto-push on every run."
  echo ""
  echo "✅ Local backup complete. Set up GitHub remote for auto-push."
  exit 0
fi

cd "$BACKUP_REPO"

# Sync latest backup into the repo (overwrites previous)
rsync -a --delete --quiet "$DEST/" "$BACKUP_REPO/latest/"

# Copy secrets-free config for reference
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  cp "$HOME/.openclaw/openclaw.json" "$BACKUP_REPO/latest/openclaw.json"
fi

# Safety check — never push secrets
if grep -rq "sk-ant-\|ghp_\|xoxb-\|Bot MTk\|DISCORD_BOT_TOKEN=" "$BACKUP_REPO/latest/" 2>/dev/null; then
  echo "  🚨 SECRETS DETECTED — aborting push. Run secrets-check.js to find them."
  exit 1
fi

# Commit and push
git add -A
if git diff --cached --quiet; then
  echo "  No changes since last backup."
else
  git commit -m "backup: $TIMESTAMP" --quiet

  # Push with retry
  RETRIES=4
  DELAY=2
  for i in $(seq 1 $RETRIES); do
    if git push --quiet 2>/dev/null; then
      echo "  ✓ Pushed to GitHub"
      break
    else
      if [ "$i" -lt "$RETRIES" ]; then
        echo "  ⚠️  Push failed, retrying in ${DELAY}s..."
        sleep $DELAY
        DELAY=$((DELAY * 2))
      else
        echo "  ⚠️  Push failed after $RETRIES attempts. Local backup is safe."
      fi
    fi
  done
fi

echo ""
echo "✅ Backup complete (local + GitHub)."
