# Security Policy

## Reporting a vulnerability

If you find a security issue in Agent Athena, **do not** open a public GitHub issue.

Use [GitHub Security Advisories](https://github.com/henchmarketing-rgb/agent-athena/security/advisories/new) to report privately. Include:
- A description of the issue
- Steps to reproduce
- The version (commit SHA) you tested against
- Your assessment of impact

You'll get an acknowledgement within 72 hours and a fix or mitigation timeline within 7 days.

We follow coordinated disclosure: please give us a reasonable window to ship a fix before publishing details.

---

## Critical: agent permission model

Athena ships a multi-agent architecture. Several agents are configured with **`dangerouslySkipPermissions: true`** in older versions of the templates. This setting **disables Claude Code's permission prompts** and is documented as recommended in some guides.

### What this means

When `dangerouslySkipPermissions: true` is enabled on an agent that:
- has `exec` access (Forge, Icarus, Recovery), AND
- consumes external content (Discord messages, web pages, Paperclip task descriptions, scraped content)

…**a prompt injection in any of that external content can result in arbitrary shell execution on the host running the agent.**

This is a fundamental tradeoff the project makes for autonomy. We document it explicitly so operators can make an informed choice.

### What we recommend

1. **Default to `dangerouslySkipPermissions: false`** for any agent that reads untrusted input. The current templates ship with this default.
2. **Treat `dangerouslySkipPermissions: true` as opt-in only** for agents you've fully scoped (e.g., a nightly QC agent reading only your own logs).
3. **Run agents on a dedicated VM or container.** Don't run them on a host that contains personal data, SSH keys, or credentials beyond what the agent needs.
4. **Review tool permissions in `.claude/settings.json` per-agent.** Don't grant `exec` or `bash` to agents that don't need them.
5. **Sanitize the input surface.** Don't paste arbitrary URLs/messages/screenshots into agent contexts without thinking about what's in them.
6. **Read the warnings** in `templates/OFFICE.md`, `docs/AGENT-CAPABILITIES.md`, `docs/PAPERCLIP-API.md`, and `INSTALL.md` before flipping the flag back on.

### Recovery agent specifically

The Recovery agent has elevated permissions and is documented as activated by `@Recovery` mention in any Discord channel. **Anyone with send access to your Discord server can trigger Recovery.** If your Discord is not single-operator, lock Recovery activation behind a Discord role check before going live.

[ESCALATION.md](docs/ESCALATION.md) covers the full contract between Argus, Heracles, Recovery, and Athena, plus the three options for gating Recovery activation (role, channel, or PIN).

---

## Credentials and secrets

- Agent Athena writes secrets to `~/.env.secrets` (chmod 600) and sources it from your shell profile.
- Secrets in this file are loaded into every shell session that sources it. If you don't want this behaviour, comment out the `source ~/.env.secrets` line in your `.zshrc`/`.bashrc` and load secrets per-process instead.
- The repo includes `secrets-check.js` to scan for accidentally committed credentials. Run it as a pre-commit hook if you intend to contribute.

## Reporting non-security bugs

For non-security issues, open a GitHub issue using the bug template.
