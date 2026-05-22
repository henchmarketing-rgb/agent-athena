# AGENT-BRIEF.md — [PROJECT_NAME]

<!-- ⚠️ CONTEXT ONLY — NO TASKS HERE -->
<!-- Tasks go in TASK-QUEUE.md (separate file) -->
<!-- If tasks appear here, the agent will try to do all of them at once -->

You are an autonomous improvement agent for [PROJECT_NAME].
Read this file first, then check TASK-QUEUE.md for tonight's task.

## Project

- **App**: [What it does in one sentence]
- **Repo**: [org/repo] (local: ~/Apps/[project-name])
- **Live**: [URL]
- **Stack**: [e.g. Next.js, Supabase, Vercel | or: vanilla HTML, no build step]
- **Branch rule**: Always work on `nightly/YYYY-MM-DD`. Never touch main directly.
- **Build check**: `npm run build` — if it fails, revert ALL changes before committing.
- **Commit format**: `nightly(YYYY-MM-DD): <what you did>`

## Start of Every Run

1. Read `GOTCHAS.md` — known traps, don't repeat them
2. Read `~/.openclaw/workspace/NIGHTLY-NOTES.md` — learn from other agents
3. Read this brief for project context
4. Read `TASK-QUEUE.md` for tonight's specific task
5. Do the work
6. Verify build passes AND the feature actually works
7. Append to `GOTCHAS.md` if you hit anything unexpected
8. Post report to Discord channel [REPORT_CHANNEL_ID]
9. Append to `NIGHTLY-NOTES.md` if you found something useful for other projects

## Tech Notes

- [Key architectural decision or constraint]
- [Known quirk or gotcha that's already handled]
- [Any off-limits files or routes]

## Off-Limits

- Never touch [FILE_OR_ROUTE] without explicit instruction
- Never auto-merge to main — always push a branch for review

## Cross-Agent Notes

After each run, if you discovered something that would help other nightly agents:
Append to `~/.openclaw/workspace/NIGHTLY-NOTES.md`:
```
## [YYYY-MM-DD] [Agent: project-name]
- What I found: [brief description]
- Relevant to: [other projects or "all"]
- Why it matters: [one sentence]
```
