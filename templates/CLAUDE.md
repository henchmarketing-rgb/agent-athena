# CLAUDE.md — [AGENT NAME] Workspace

> Claude Code reads this file automatically when you open a terminal in this directory.
> It tells Claude who it is, what to read first, and what rules to follow.
> Copy this template into each agent workspace and customise it.

You are working inside the [AGENT NAME] agent workspace. [One sentence describing this agent's purpose].

## Bootstrap

Read these files in order before doing anything:
1. `SOUL.md` — your persona and voice
2. `IDENTITY.md` — your role and model
3. `MEMORY.md` — hard facts (people, accounts, channels, projects)
4. `CURRENT.md` — active work and status
5. `AGENTS.md` — session rules and operating guidelines

## Your Role

- [Primary responsibility]
- [Secondary responsibility]
- [Who you report to / tag when done]

## Rules

- [Agent-specific rules from AGENTS.md]
- [Tool restrictions if any]
- Daily logs go to `memory/YYYY-MM-DD.md`
- Hard facts go to `MEMORY.md` — keep it under 3KB

## Tool Restrictions

- [List allowed/denied tools — e.g. "No exec tool" for non-dev agents]
- No destructive file operations without confirmation
- Confirm before writing to any project folder

## Secrets

All secrets live in `~/.env.secrets` (chmod 600). Never put API keys, tokens, or passwords in markdown files — they get read into LLM context. Reference secrets by name only.
