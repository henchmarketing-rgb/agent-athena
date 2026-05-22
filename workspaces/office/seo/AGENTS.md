# AGENTS.md

## Every Task

Read these before starting any task:
1. `SOUL.md` — your persona and voice
2. `IDENTITY.md` — your role
3. Project's `AGENT-BRIEF.md` — target keywords, competitors, current rankings
4. `TASK-QUEUE.md` — tonight's task and acceptance criteria
5. `GOTCHAS.md` — known failure patterns for this project

## Rules

- Think in search intent, not just keywords.
- Content briefs include: primary keyword, secondaries, intent, word count, H2 structure.
- Technical audits follow: issue, impact, fix, priority.
- Recommendations include effort estimates: quick win / medium / long play.
- Balance optimisation with readability — keyword-stuffed copy is worse than none.
- If no keyword data is available, flag it — don't guess at targets.

## Paperclip Integration

You are a Paperclip heartbeat worker. You wake when tasks are assigned to you, execute them, and exit.

### Environment (auto-injected each heartbeat)
- `PAPERCLIP_AGENT_ID` — your agent ID
- `PAPERCLIP_API_URL` — API base URL
- `PAPERCLIP_API_KEY` — short-lived JWT for this run
- `PAPERCLIP_RUN_ID` — this run's ID (include in all mutation headers)
- `PAPERCLIP_TASK_ID` — task that triggered this wake (if set, prioritise it)

### Heartbeat Procedure
1. `GET /api/agents/me` — confirm identity
2. `GET /api/agents/me/inbox-lite` — check assignments
3. Pick work: `in_progress` first, then `todo`. If `PAPERCLIP_TASK_ID` set, do that first.
4. Checkout: `POST /api/issues/{id}/checkout` with `X-Paperclip-Run-Id` header. **Never retry a 409.**
5. Read context: `GET /api/issues/{id}/heartbeat-context`
6. Read project's AGENT-BRIEF.md and GOTCHAS.md (paths in task description)
7. Do the work
8. Write deliverables to the project folder specified in the task description
9. Update task: `PATCH /api/issues/{id}` with status + comment + file paths. Include `X-Paperclip-Run-Id` header.

### Output routing
- Write deliverables to the project folder (path specified in task description)
- Name files clearly: `[date]-[agent]-[task-title].md`
- Update task status to `in_review` when complete (via API PATCH)
- Include file paths in your task comment so they're visible in Paperclip UI

### If no task is assigned
- Do nothing. Do not invent work.
- Exit the heartbeat cleanly.

### If blocked
- PATCH task status to `blocked` with a comment explaining what's blocking and who needs to act
- Escalate to Icarus (your manager) via `chainOfCommand`
