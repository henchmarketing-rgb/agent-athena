# Escalation Contract

How problems flow between watchman agents (Argus, Heracles, Recovery) and the operator-facing Athena. Read before going live.

This contract exists because the audit found four agents (Argus, Heracles, Recovery, Athena) all watching the system with overlapping responsibilities and no defined hand-off rules. Without these rules, real production failures fall through gaps. With them, every alert has a clear owner.

---

## Roles, in 1 sentence each

| Agent | Role |
|---|---|
| **Athena** | Operator interface. Routes work, reports up, runs onboarding, owns weekly compaction. |
| **Argus** | Continuous health monitor. Watches sites, crons, sessions, secrets, costs. Real-time. |
| **Heracles** | Nightly QC reviewer. Scores last-night agent runs PASS/PARTIAL/FAIL. Once a day. |
| **Recovery** | Emergency failsafe. Elevated permissions. Operator-triggered only. |

---

## Severity ladder

Every alert is one of four severities. Each severity has exactly one owner and exactly one channel.

| Severity | Trigger | Owner | Channel | Operator notified? |
|---|---|---|---|---|
| **CRITICAL** | Production down · Data loss imminent · Secret leaked · Recovery already engaged | Recovery (after operator activates) | `#🛡️〡recovery` + DM operator | Yes, immediately |
| **HIGH** | Heracles: ≥2 nightly runs FAIL in a row · Argus: site down >5 min · Argus: ≥3 cron consecutive errors | Heracles or Argus posts here, Athena escalates if no operator response in 30 min | `#🦉〡athena` | Yes, within 30 min |
| **MEDIUM** | Single nightly FAIL · Cost spike · Session bloat · Stale CURRENT.md | Argus (continuous) or Heracles (morning) | Their own channel: `#👁️〡argus` / `#⚡〡heracles` | Yes, in next morning summary |
| **LOW** | Style nits, optional improvements, minor warnings | Heracles (rolled into morning summary) | `#⚡〡heracles` | Optional, summary only |

---

## Hand-off rules

### Argus → Athena

Argus posts in `#argus`. Argus tags `@athena` only when:
- Severity ≥ HIGH **and** the operator has not acknowledged within 30 min, OR
- Same MEDIUM alert has fired ≥ 3 times in 24 h (probable miss)

Athena's responsibility: surface the alert to the operator with context. Athena does NOT diagnose or fix. Athena does NOT trigger Recovery.

### Heracles → Athena

Heracles posts a single morning summary at 08:00 operator-local time in `#heracles`. The summary lists every nightly run from the previous night with PASS / PARTIAL / FAIL.

If the night had ANY of:
- ≥2 FAILs across all projects
- A FAIL on a project flagged "production" in its CURRENT.md
- A missing report (= automatic FAIL)

Heracles also posts a one-line callout in `#athena` with the failing project names and a link back to the full summary. Athena reads and routes to the operator.

### Argus / Heracles → Recovery

**Never automatic.** Argus and Heracles never tag `@recovery` directly. The escalation path is always:

1. Argus / Heracles posts to operator (via Athena if needed).
2. Operator decides whether to engage Recovery.
3. Operator types `@recovery` in `#recovery`.

This is intentional friction. Recovery has full exec access. We do not let watchman agents activate it.

### Athena → Recovery

Same rule: Athena never tags `@recovery`. Athena's job in a Recovery-worthy incident is to:
- Get the operator's attention via DM.
- Provide context: what Argus/Heracles saw, when, and what the affected systems are.
- Wait for operator decision.

---

## Recovery activation gating

The audit flagged a real risk: by default Recovery is documented as "tag `@Recovery` in any channel" — meaning **anyone with send access to your Discord server can trigger an agent with elevated shell permissions**.

For single-operator setups (only you in the Discord) this is fine. For any multi-person server, gate Recovery before going live:

### Option A: Discord role check (recommended)

Add a Discord role called `athena-operator`. In the Recovery agent's `AGENTS.md`, add a guard: only respond if the user invoking has the `athena-operator` role. The OpenClaw gateway can be extended to check this; until it does natively, Recovery's first action on every wake should be a member-role check via the Discord API and refusal otherwise.

### Option B: Channel restriction

Lock `#🛡️〡recovery` so only the operator role can post. Tags from other channels do not wake Recovery.

### Option C: Operator-PIN

Recovery refuses to act on a `@recovery` mention unless the message also includes a passphrase set in `~/.env.secrets` as `RECOVERY_PIN`. Cheap and effective for solo operators.

**Pick one before flipping the repo public** if anyone other than you has send access to your server.

---

## What each agent must NEVER do

### Argus
- ❌ Modify production code
- ❌ Send messages outside its assigned channels
- ❌ Trigger Recovery directly
- ❌ Take corrective action beyond reporting (it's a sensor, not an actuator)

### Heracles
- ❌ Re-run failed nightly agents
- ❌ Modify the work being reviewed
- ❌ Override another agent's verdict on its own task
- ❌ Trigger Recovery directly

### Recovery
- ❌ Activate itself; only the operator triggers it
- ❌ Make architectural changes beyond the immediate fix
- ❌ Continue working after the immediate emergency is resolved
- ❌ Modify `SECURITY.md`, `ESCALATION.md`, or `~/.openclaw/openclaw.json` (these are operator-only)

### Athena
- ❌ Tag `@recovery`
- ❌ Diagnose Argus or Heracles alerts (route them; don't try to fix them)
- ❌ Mark a Heracles FAIL as PASS

---

## Concurrency notes

The audit also flagged that `NIGHTLY-NOTES.md` is a shared mutable file with no lock. Agents writing concurrently can clobber each other.

Until Paperclip / OpenClaw add row-level locking, follow this rule:

**Append-only, never edit.** Every nightly agent appends a dated section to `NIGHTLY-NOTES.md` and never modifies prior entries. With append-only, the worst case from a race is an interleaved single line — not data loss.

To be safer still, agents can use a temp-file pattern:

```bash
# Pseudo-code for append-only with file lock-ish behaviour
tmp=$(mktemp)
cat NIGHTLY-NOTES.md > "$tmp"
echo "$NEW_ENTRY" >> "$tmp"
mv "$tmp" NIGHTLY-NOTES.md
```

`mv` is atomic on the same filesystem. This still races on read, but the write itself is safe.

---

## TL;DR for the operator

- One alert, one owner, one channel.
- Argus and Heracles **never** trigger Recovery.
- Athena **never** triggers Recovery.
- **You** trigger Recovery, in `#recovery`, with a role / channel / PIN gate in place.
- If you see overlapping alerts from multiple watchman agents, one of them is wrong — fix the contract, don't paper over it.
