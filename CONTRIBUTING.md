# Contributing to Agent Athena

Thanks for considering a contribution. Athena is a multi-agent system, so changes ripple. Read this before opening a PR.

## Before you start

1. **Open an issue first** for anything beyond a typo or one-line fix. Get a thumbs-up before writing code.
2. **Run on a fresh machine.** A lot of bugs only show up on a clean install. If you can't test on a fresh box, say so in the PR.
3. **Read the existing docs.** `README.md`, `INSTALL.md`, `OPERATIONS.md`, and the files in `docs/` describe how the system is meant to work.

## What we want

- **Install fixes.** `install.sh` is a 24KB bash script that needs to work on macOS and Linux. Bug reports with reproduction steps are gold.
- **Cross-platform support.** Currently macOS-first. Linux distros beyond Debian/Ubuntu need work.
- **Missing scripts.** `discord-setup.js`, `create-project.js`, idempotent `paperclip-setup.js` all need real implementations.
- **Doc consolidation.** README, QUICKSTART, FULL-GUIDE, and PRODUCTION-REFERENCE overlap heavily. Help us pick one canonical install path.
- **Cost transparency.** Help write `COST-GUIDE.md` with real numbers.
- **Tests.** Currently zero. A smoke test that runs `install.sh --dry-run` would be enormous.

## What we don't want

- Refactors with no clear motivation.
- Renaming for taste.
- Cleanup beyond what your change touches.
- New features before existing ones work end-to-end on a fresh box.

## Getting started

```bash
git clone https://github.com/henchmarketing-rgb/agent-athena.git
cd agent-athena
git checkout -b your-feature-name
```

Make your change. Test it. Open a PR against `main`.

## Code style

- **Shell**: pass `shellcheck` (CI runs it).
- **JavaScript**: pass `node --check` (CI runs it). No specific lint enforced yet; match surrounding style.
- **Python**: PEP 8.
- **Markdown**: no em dashes as clause separators (use a comma, period, or rewrite). The Athena writing guide forbids them; CI may grep for `\s—\s` and warn.

## Commit messages

`type: short description` where type is one of: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`.

Examples:
- `feat: idempotent install with state file`
- `fix: install.sh apt-get sudo on Linux`
- `docs: strip em dashes from QUICKSTART`

## PR checklist

- [ ] My change has a clear motivation (link the issue)
- [ ] I tested on a fresh box, OR documented why I couldn't
- [ ] I didn't add new dependencies without flagging them
- [ ] I didn't touch unrelated code
- [ ] No secrets, no personal info, no internal references
- [ ] No `Co-Authored-By: Claude` trailers (we keep commits clean)

## Architectural decisions

For changes to: agent personas, the install flow, the Discord channel structure, the memory compaction model, or anything in the spec — open an issue tagged `architectural` first. These decisions affect every operator's setup.

## Security

See `SECURITY.md`. Don't open public issues for security problems.

## License

By contributing, you agree your contributions will be licensed under the MIT License (see `LICENSE`).
