# MCP Server Recommendations

MCP (Model Context Protocol) servers extend what Claude can do beyond its built-in tools. They run locally on your machine and give agents access to external services, GitHub, databases, browsers, search engines, through a standardised interface.

This matters for Athena because your agents need to interact with real systems. The right MCP servers turn "fetch that PR" or "check the database" from multi-step manual work into single-tool calls.

---

## How MCP Servers Work

MCP servers run as local processes. Claude Code discovers them via configuration and connects on startup. Each server exposes tools that Claude can call, just like built-in tools, but backed by external services.

Configuration lives in one of two places:
- **Claude Code CLI/Desktop:** `~/.claude/claude_desktop_config.json`
- **Per-project:** `.mcp.json` in the project root

---

## Recommended Servers

### GitHub MCP Server

**What it does:** Full GitHub access, repos, PRs, issues, code search, reviews, comments.

**Why you need it:** Dev and executor agents need to create PRs, post review comments, and manage issues without leaving the agent session. Nightly agents push to branches, this server lets them create the PR too.

**Config:**
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxx"
      }
    }
  }
}
```

**Which agents use it:** Executor/Dev agents, Athena (for issue triage), nightly agents.

**Security note:** The token needs repo scope. Store it in `~/.env.secrets` and reference it via environment variable, don't hardcode it in the config.

---

### Brave Search MCP Server

**What it does:** Web search via the Brave Search API. Returns structured results with titles, URLs, and snippets.

**Why you need it:** Poseidon's research sessions and Athena's general queries both benefit from real-time web search. Already part of the Athena stack (install.sh collects the API key).

**Config:**
```json
{
  "mcpServers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "BSA_xxxxxxxxxxxx"
      }
    }
  }
}
```

**Which agents use it:** Poseidon (primary), Athena, Icarus (for market research).

---

### Filesystem MCP Server

**What it does:** Extended file operations, read, write, move, search, and manage files across directories.

**Why you need it:** Useful when agents need to work across multiple workspace directories or manage files outside their workspace root. The built-in file tools are scoped, this server extends reach.

**Config:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y", "@modelcontextprotocol/server-filesystem",
        "/path/to/allowed/directory"
      ]
    }
  }
}
```

**Which agents use it:** Athena (cross-workspace operations), executor agents.

**Security note:** Scope the allowed directories tightly. Don't give access to `~` or `/`, only the directories agents actually need.

---

### Puppeteer MCP Server

**What it does:** Browser automation, navigate pages, take screenshots, click elements, fill forms, extract content.

**Why you need it:** Site health checks, visual regression testing, scraping data from pages that require JavaScript rendering. The `site-health.js` script handles basic HTTP checks, but Puppeteer handles the rest.

**Config:**
```json
{
  "mcpServers": {
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    }
  }
}
```

**Which agents use it:** Poseidon (research scraping), executor agents (visual testing), nightly agents (screenshot verification).

---

### Supabase MCP Server

**What it does:** Direct database operations, run SQL queries, manage tables, inspect schema, handle migrations.

**Why you need it:** If your projects use Supabase (common in the Athena stack), this lets agents query data, check schema, and run migrations without shelling out to psql.

**Config:**
```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "sbp_xxxxxxxxxxxx"
      }
    }
  }
}
```

**Which agents use it:** Executor/Dev agents, nightly agents (data verification).

**Security note:** Use a service role key scoped to the specific project, not your personal access token. Store in `~/.env.secrets`.

---

### Memory MCP Server

**What it does:** Persistent key-value memory that survives across sessions. Stores and retrieves structured data.

**Why you need it:** Optional alternative to the file-based memory system (MEMORY.md, daily files). Some operators prefer a database-backed memory for faster lookups. Not a replacement for the file-based system, more of a complement for structured data.

**Config:**
```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

**Which agents use it:** Any agent that needs fast structured lookups.

**Note:** The file-based memory system (MEMORY.md + daily logs) is the primary memory pattern in Athena. This server is a supplement, not a replacement. Don't split memory across two systems unless you have a clear reason.

---

## Per-Project vs Global Config

**Global** (`~/.claude/claude_desktop_config.json`): Servers available in every Claude Code session. Good for GitHub, Brave Search, things every session needs.

**Per-project** (`.mcp.json` in repo root): Servers specific to a project. Good for Supabase (project-specific credentials), filesystem (project-specific paths).

```json
// .mcp.json — per-project example
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase"],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
      }
    }
  }
}
```

Use `${ENV_VAR}` syntax to reference secrets from your environment rather than hardcoding them.

---

## Security Notes

MCP servers run with the same permissions as your user account. They can read files, make network requests, and execute commands depending on the server.

**Apply the same secrets hygiene as everywhere else:**
- Never hardcode tokens in config files that get committed to git
- Add `.mcp.json` to `.gitignore` if it contains real credentials (or use env var references)
- Scope tokens to minimum required permissions (e.g. GitHub token with only `repo` scope)
- Review what each server can access before enabling it
- Run `scripts/secrets-check.js` after adding new MCP configs to catch leaks

---

## What You Don't Need

Not every MCP server is useful for agent workflows. Skip these unless you have a specific reason:

- **Slack MCP**: Athena uses Discord, not Slack. Only add if your team also uses Slack.
- **Google Drive MCP**: file-based memory is simpler and doesn't require OAuth.
- **Database servers (Postgres, SQLite)**: Use Supabase MCP instead if you're on Supabase. Only add raw database servers if you're managing your own Postgres.

---

*Start with GitHub + Brave Search. Add others as your agents need them. Each new server is a new attack surface, only enable what you actually use.*
