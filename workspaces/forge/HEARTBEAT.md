# HEARTBEAT.md — Forge Health Checks

Run this checklist when something seems off, or on request.

## Workspace Files
- [ ] SOUL.md is readable and > 0 bytes
- [ ] IDENTITY.md is readable and > 0 bytes
- [ ] MEMORY.md is readable and < 3KB
- [ ] CURRENT.md shows active dev tasks
- [ ] TASK-QUEUE.md exists and is readable
- [ ] GOTCHAS.md exists (failure patterns log)
- [ ] AGENT-BRIEF.md exists (project context)
- [ ] memory/ directory exists

## Channel
- [ ] #forge channel exists in Discord server
- [ ] Bot can post to #forge
- [ ] Last message in #forge is within expected timeframe

## Dev Toolchain
- [ ] `node --version` returns a version (Node.js is installed)
- [ ] `npm --version` returns a version
- [ ] `git --version` returns a version
- [ ] `git status` succeeds in the active project repo (no repo corruption)
- [ ] No active branch is directly on `main` — should be on a feature or nightly branch

## Build & Commit Hygiene
- [ ] No uncommitted changes left over from the last nightly run
- [ ] Current nightly branch follows naming convention `nightly/YYYY-MM-DD`
- [ ] Last build (`npm run build`) exited 0 — check CURRENT.md for last result
- [ ] No broken commits in recent git log (check for "WIP" or "temp" commit messages)

## Exec Access
- [ ] Exec tool is listed in available tools for this session
- [ ] Can write to the active project repo directory

## Memory
- [ ] MEMORY.md < 3KB
- [ ] No API keys or tokens in any .md file
- [ ] Daily log written to memory/YYYY-MM-DD.md if active today

## Report Format

When running this as a task, post results to #forge:
```
FORGE HEARTBEAT [date]
✅ Workspace: all files present
✅ Toolchain: node 20.x, npm 10.x, git 2.x
✅ Branch: nightly/2026-04-22 (no main commits)
✅ Last build: PASS
✅ Memory: 0.9KB, clean
⚠️ GOTCHAS.md: 2 unresolved patterns — review before next run
```
