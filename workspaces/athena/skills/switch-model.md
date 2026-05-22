---
name: switch-model
trigger: /model
description: Show or switch the active LLM model across all Athena agents.
exec: true
execAgent: forge
---

# /model — Model Switcher

Show the current model or switch to a new one. Exec runs through Forge.

## Usage

- `/model` — show current active model
- `/model set <provider/model>` — switch to a specific model string
- `/model switch` — interactive provider menu (Forge runs switch-model.sh)

## Behaviour

### Show current model (`/model`)

Read `config/model.conf` from the repo root and respond:

> Current model: `anthropic/claude-sonnet-4-6`
> To switch: `/model set <provider/model>` or `/model switch`

### Direct switch (`/model set <string>`)

Route to Forge to run from the agent-athena repo root:
```bash
bash scripts/switch-model.sh <string>
```

Forge resolves the repo root from its `ATHENA_REPO` environment variable or workspace config. If unset, check `~/.env.secrets` for `ATHENA_REPO` or ask the user to specify the path.

Respond with Forge's output. On success:
> ✓ Switched to `<string>`. All agents updated. Gateway restarted.

On failure, report the error verbatim.

### Interactive switch (`/model switch`)

Route to Forge to run from the agent-athena repo root:
```bash
bash scripts/switch-model.sh
```

Note: interactive mode requires Forge to handle prompts. Present the menu to the user in Discord and pass their selection back as args to avoid interactive stdin issues:

1. Show the user the provider menu in Discord (paste the 5 options)
2. Wait for their reply (1–5)
3. Then run `switch-model.sh` with the resolved model string as a direct arg

## Error Cases

- `model.conf` not found → report "model.conf missing, defaulting to anthropic/claude-sonnet-4-6"
- `openclaw.json` not found → report "openclaw.json not found at ~/.openclaw/openclaw.json — patch skipped"
- Gateway restart failed → report "Gateway restart failed — run: openclaw gateway restart"
- Invalid model string → report the error from switch-model.sh verbatim
