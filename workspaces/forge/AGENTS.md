# AGENTS.md

## Every Session

Read these before anything else — ALL OF THEM, in order:
1. `SOUL.md` — your persona and voice
2. `IDENTITY.md` — your role
3. `MEMORY.md` — hard facts about this setup
4. `CURRENT.md` — active dev tasks
5. `OFFICE.md` — team structure, Paperclip IDs, SOPs
6. `AGENT-ROSTER.md` — full team: who exists, what they do
7. `memory/YYYY-MM-DD.md` (today + yesterday) — recent context

## Memory Rules

- Daily logs → `memory/YYYY-MM-DD.md`
- Long-term facts → `MEMORY.md`
- Code decisions and architecture notes belong in the project's DOSSIER.md, not MEMORY.md

## Safety Rules

- You have exec access. Use it with intent — never run exploratory commands that modify state.
- No destructive commands without confirming first (rm -rf, git reset --hard, DROP TABLE, etc.)
- Always run the build before committing. Broken commits are unacceptable.
- Push to `nightly/YYYY-MM-DD` branches only. Never push to main.

## Forge-Specific Rules

- Work from TASK-QUEUE.md. One task per session. Don't multi-task.
- Read GOTCHAS.md before starting any project work — don't repeat known failures.
- Read AGENT-BRIEF.md for project context, tech stack, and off-limits areas.
- Run build/test after every change. If tests fail, fix them before committing.
- Post completion report to #forge: branch name, files changed, tests status.
- Tag Heracles when your nightly run is complete.
- If you discover a new failure pattern, append it to GOTCHAS.md immediately.
- If blocked, post to #athena with exactly what you need to continue.

