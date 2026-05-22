# BUDGETS.md

> Per-project monthly cost caps in USD. Read by `scripts/cost-tracker.js --budgets BUDGETS.md`.

## Format

One project per line:

```
<project-slug>: <monthly-cap-in-USD>   # optional comment
```

Project slug should match either:

1. The directory name under `~/.openclaw/agents/<agent>/sessions/<project>/...`, OR
2. The `project` field set explicitly in the agent's session JSONL log lines.

`cost-tracker.js` infers the slug from the session file path. If your sessions don't carry the project slug in the path, log a `{"project": "<slug>"}` line at the top of each session.

## Example

```
hey-susan: 80
ironclad:  50
agent-athena: 25     # this project itself
prove-the-news: 30
internal:  100       # multi-project bucket
```

## How thresholds fire

| Spend (monthly projection) | Marker | Behaviour |
|---|---|---|
| ≤ 80% of cap | `✓` | All clear |
| 80–100% of cap | `⚠️` | Warning, no exit code |
| > 100% of cap | `🚨` | Process exits 1 (CI / cron will flag) |

## Recommended cron

Daily at 06:00 local. Pipe the output to Argus's morning summary or your alert webhook:

```cron
0 6 * * * cd ~/.openclaw/workspace && /usr/local/bin/node scripts/cost-tracker.js --days 14 --budgets BUDGETS.md >> logs/cost.log 2>&1 || node scripts/alert.js --incident high --message "Project budget breach (see logs/cost.log)"
```

## What this is NOT

This is a **soft** budget that warns the operator. It does not stop agents mid-task. Hard per-task budget caps live in Paperclip's `budgetMonthlyCents` field on each agent (set via `scripts/paperclip-setup.js`).

For belt-and-suspenders: set Paperclip's hard cap a bit higher than your BUDGETS.md soft cap, so the soft warning fires before Paperclip refuses to assign new tasks.
