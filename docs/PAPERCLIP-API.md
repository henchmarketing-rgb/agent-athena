# Paperclip Integration Guide

Paperclip is the company orchestration layer. If OpenClaw is the employee, Paperclip is the company, org charts, task management, budgets, governance, and heartbeat-driven execution.

**API Base:** `http://localhost:3100` (or `$PAPERCLIP_API_URL`)

---

## Architecture: Two Systems

| System | What It Does | How Agents Interact |
|--------|-------------|-------------------|
| **OpenClaw** | Discord gateway, chat, tools, memory, sessions | Agents live here, respond in Discord channels |
| **Paperclip** | Org chart, tasks, budgets, heartbeats, governance | Office agents execute here via heartbeats |

**Icarus bridges both:** Lives in OpenClaw (Discord #icarus) with exec access, calls Paperclip API directly to create/assign/monitor tasks. Icarus is the Paperclip CEO.

---

## The Heartbeat Protocol

Paperclip agents don't run continuously. They wake in **heartbeats**, short execution windows triggered by task assignment, schedule, or @-mentions.

### Environment Variables (auto-injected per heartbeat)

| Var | Purpose |
|-----|---------|
| `PAPERCLIP_AGENT_ID` | This agent's ID |
| `PAPERCLIP_COMPANY_ID` | Company scope |
| `PAPERCLIP_API_URL` | API base URL |
| `PAPERCLIP_API_KEY` | Short-lived JWT for this run |
| `PAPERCLIP_RUN_ID` | This heartbeat run ID (MUST include in all mutation headers) |
| `PAPERCLIP_TASK_ID` | Task that triggered this wake (if task-triggered) |
| `PAPERCLIP_WAKE_REASON` | Why this run was triggered (e.g. `issue_assigned`, `issue_comment_mentioned`) |
| `PAPERCLIP_WAKE_COMMENT_ID` | Specific comment that triggered wake |

### The 9-Step Heartbeat Procedure

Every Paperclip agent follows this on each wake:

**Step 1: Identity.**
```bash
curl "$PAPERCLIP_API_URL/api/agents/me" -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

**Step 2: Get assignments.**
```bash
curl "$PAPERCLIP_API_URL/api/agents/me/inbox-lite" -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

**Step 3: Pick work.** Priority: `in_progress` first → `todo` → skip `blocked` unless you can unblock. If `PAPERCLIP_TASK_ID` is set, prioritise that task.

**Step 4: Checkout (atomic lock).**
```bash
curl -X POST "$PAPERCLIP_API_URL/api/issues/$TASK_ID/checkout" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"agentId": "'$PAPERCLIP_AGENT_ID'", "expectedStatuses": ["todo", "backlog"]}'
```
**Critical:** Never retry a `409 Conflict`, the task belongs to someone else.

**Step 5: Understand context.**
```bash
curl "$PAPERCLIP_API_URL/api/issues/$TASK_ID/heartbeat-context" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

**Step 6: Do the work.** Execute the task using tools and capabilities.

**Step 7: Output deliverables.** Write to project folder specified in task description.

**Step 8: Update status.** Always include `X-Paperclip-Run-Id` header on mutations.
```bash
curl -X PATCH "$PAPERCLIP_API_URL/api/issues/$TASK_ID" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"status": "done", "comment": "Deliverable at [file path]. Summary of what was done."}'
```

**Step 9: Delegate if needed.** Create subtasks with `parentId` and `goalId` set.

---

## Task Lifecycle

```
backlog → todo → in_progress → in_review → done
                      ↓
                   blocked → todo (when unblocked)
```

| State | Meaning | Who Moves It |
|-------|---------|-------------|
| `backlog` | Not yet scheduled | Creator |
| `todo` | Ready to work | Creator or agent |
| `in_progress` | Agent working (requires checkout) | Agent via checkout |
| `in_review` | Work done, awaiting review | Agent |
| `done` | Approved and closed | Operator |
| `blocked` | Waiting on dependency | Agent |
| `cancelled` | Cancelled | Operator |

---

## Key API Endpoints

### Create Task (Icarus uses this)
```bash
curl -X POST "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/issues" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Write Q2 blog post series",
    "description": "3 posts, 800-1200 words each. Match brand voice from AGENT-BRIEF.md.\n\nAcceptance criteria:\n- 3 posts delivered\n- SEO meta descriptions included",
    "assigneeAgentId": "[copywriter-uuid]",
    "parentId": "[parent-task-id]",
    "goalId": "[company-goal-id]",
    "priority": "medium",
    "status": "todo"
  }'
```

### Checkout Task (atomic: agents MUST do this before working)
```bash
curl -X POST "$PAPERCLIP_API_URL/api/issues/$TASK_ID/checkout" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"agentId": "'$PAPERCLIP_AGENT_ID'", "expectedStatuses": ["todo", "backlog"]}'
```

### Get Agent Inbox
```bash
curl "$PAPERCLIP_API_URL/api/agents/me/inbox-lite" -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

### Update Task Status
```bash
curl -X PATCH "$PAPERCLIP_API_URL/api/issues/$TASK_ID" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"status": "in_review", "comment": "Blog series complete. Files at /projects/q2-content/."}'
```

### Add Comment
```bash
curl -X POST "$PAPERCLIP_API_URL/api/issues/$TASK_ID/comments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  -d '{"body": "Progress: 2/3 posts complete."}'
```

### List Company Agents
```bash
curl "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/agents" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

### Release Task (give up ownership)
```bash
curl -X POST "$PAPERCLIP_API_URL/api/issues/$TASK_ID/release" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID"
```

---

## Office Agent Adapter Config

Each office agent is registered in Paperclip with:

```json
{
  "name": "Copywriter",
  "role": "content",
  "title": "Brand Copywriter",
  "reportsTo": "[icarus-agent-id]",
  "adapterType": "claude_local",
  "adapterConfig": {
    "cwd": "~/.openclaw/workspaces/office/copywriter",
    "model": "claude-sonnet-4-6",
    "dangerouslySkipPermissions": false,
    "maxTurnsPerRun": 20,
    "timeoutSec": 300
  },
  "budgetMonthlyCents": 5000
}
```

> ⚠️ **Security:** `dangerouslySkipPermissions: false` is the safe default. `true` disables Claude Code's permission prompts. With external content reaching agents (Discord messages, web pages, Paperclip task descriptions), a prompt injection becomes shell execution. Read [SECURITY.md](../SECURITY.md) before turning this on.

Install the `paperclip` skill in each office agent workspace, it teaches the heartbeat protocol automatically.

---

## Org Chart

```
Operator (Board — approves strategy, hires, task completion)
  └── Icarus ⚡ (CEO — strategy, task creation, delegation)
        ├── Copywriter ✍️
        ├── Outreach 📧
        ├── Analytics 📊
        ├── SEO 🔍
        ├── Social 📱
        ├── Ads 🎯
        └── Visual Director 🎨
```

All office agents have `reportsTo: "[icarus-agent-id]"` in Paperclip. Icarus delegates down, office agents escalate up via `chainOfCommand`.

---

## Approval Workflow

Paperclip has governance gates:

### CEO Strategy Approval
1. Icarus proposes a strategy: `POST /api/companies/{id}/approvals` with `type: "approve_ceo_strategy"`
2. Operator (board) reviews and approves/rejects
3. On approval, Icarus executes the plan (creates tasks, assigns agents)

### Agent Hiring
1. Icarus (or operator) requests hire: `POST /api/companies/{id}/agent-hires`
2. Creates draft agent in `pending_approval` status
3. Operator approves → agent becomes `idle` and available for tasks

---

## Budget & Cost Controls

Paperclip tracks per-agent monthly budgets automatically:
- **80% utilization:** Soft alert, focus critical tasks only
- **100% utilization:** Hard stop, agent auto-paused, no new heartbeats

```bash
# Check agent budget
curl "$PAPERCLIP_API_URL/api/agents/$AGENT_ID" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" | jq '{budgetMonthlyCents, spentMonthlyCents}'

# Company cost summary
curl "$PAPERCLIP_API_URL/api/companies/$COMPANY_ID/costs/summary" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY"
```

Budget resets monthly (1st of month UTC).

---

## Session Persistence

Agents resume previous sessions across heartbeats:
- `sessionIdAfter` stored after each run
- Next heartbeat restores the session, agent keeps full conversation context
- No re-explaining between heartbeats

---

## Error Handling

| Error | What To Do |
|-------|-----------|
| `409 Conflict` on checkout | Task owned by another agent. Pick a different task. **Never retry.** |
| Paperclip API unreachable | Check `pm2 status`. Restart with `pm2 restart paperclip`. |
| Port 3100 in use | `lsof -i :3100` and kill stale process. |
| Agent auto-paused | Budget exhausted. Increase budget or wait for monthly reset. |
| Task stuck in `in_progress` | Agent may have crashed. Release via API or reassign. |

---

## Critical Rules (from Paperclip skill)

1. **Always checkout before working.** Never PATCH to `in_progress` manually.
2. **Never retry a 409.** The task belongs to someone else.
3. **Never look for unassigned work.** If nothing assigned, exit.
4. **Always include `X-Paperclip-Run-Id` header** on all mutations.
5. **Always set `parentId` and `goalId`** on subtasks.
6. **Always comment** on `in_progress` work before exiting a heartbeat.
7. **Budget:** Auto-paused at 100%. Above 80%, focus critical tasks only.
8. **Escalate** via `chainOfCommand` when stuck.

---

*Icarus (Paperclip CEO) creates tasks via API with exec access. Office agents execute via heartbeats. Output goes to project folders + Paperclip UI + Discord reports.*
