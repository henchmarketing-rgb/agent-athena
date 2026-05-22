# Design Studio

Athena includes a visual asset pipeline for generating social cards, diagrams, and launch graphics. Everything runs locally, no SaaS, no subscriptions beyond what you already have.

## What It Includes

**Tools**
- **Playwright**: headless browser for screenshotting HTML cards to PNG
- **Firecrawl CLI**: web scraping and search (requires free API key at [firecrawl.dev](https://firecrawl.dev))

**Ready-made assets** (in `assets/`)
- 6 social cards (1600×900 PNG, 16:9), launch campaign visuals
- 2 diagrams, task pipeline and architecture
- HTML source files for every card, edit and regenerate

## Install

During `bash install.sh`, choose **y** when asked about the Design Studio. Or install manually:

```bash
npm install -g playwright firecrawl-cli
npx playwright install chromium
```

## Generate a Card

Each card is a self-contained HTML file. To regenerate as PNG:

```bash
# Start a local server from the assets directory
python3 -m http.server 9771 --directory assets &

# Screenshot at 1600×900
npx playwright screenshot --viewport-size=1600,900 \
  http://localhost:9771/card-roster.html \
  assets/card-roster.png

kill %1
```

Or use the Playwright MCP server if you have Claude Code running, navigate to the local URL and use `browser_take_screenshot`.

## Customise a Card

Open any `assets/card-*.html` in a text editor. All cards share the same design system:

| Variable | Value |
|---|---|
| Background | `#0a0e13` |
| Accent (bright) | `#5de4c7` |
| Accent (deep) | `#2a8f82` |
| Font (headlines) | Press Start 2P (Google Fonts) |
| Font (body) | Share Tech Mono (Google Fonts) |

Change the text content, adjust padding, regenerate with Playwright. The HTML files are the source of truth, the PNGs are outputs.

## Available Cards

| File | Headline | Purpose |
|---|---|---|
| `card-roster.html/png` | YOUR AI COMPANY. | Launch, shows all 14 agents |
| `card-nightshift.html/png` | WHILE YOU SLEPT. | Morning report visual |
| `card-numbers.html/png` | 14 / 1 / <1HR | Key stats card |
| `card-commands.html/png` | THREE COMMANDS. | Install simplicity |
| `card-prereqs.html/png` | THAT'S ALL. | Prerequisites |
| `card-onboarding.html/png` | SAY HELLO. | 7 onboarding phases |
| `diagram-pipeline.html/png` | HOW IT WORKS. | Task flow diagram |
| `diagram-architecture.html/png` | BUILT ON THREE LAYERS. | System architecture |

## Using Firecrawl

Firecrawl gives agents real-time web access, search, scrape, and research without leaving the terminal.

```bash
# Search the web
firecrawl search "your query" --limit 5

# Scrape a URL to markdown
firecrawl scrape https://example.com

# Map all URLs on a site
firecrawl map https://example.com
```

Set your API key in `~/.env.secrets`:
```bash
FIRECRAWL_API_KEY=fc-your-key-here
```

Free tier: 500 credits/month at [firecrawl.dev](https://firecrawl.dev).

## Browser Harness

The browser harness connects agents to a real Chrome session, with your login state, cookies, and full browser capabilities. Use this when you need agents to interact with real web apps: posting to X/LinkedIn, accessing dashboards, scraping auth-gated content.

### Setup

1. Install Chrome if not already installed
2. Launch Chrome with remote debugging enabled:
```bash
# Mac
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222 --no-first-run --user-data-dir=~/.chrome-debug-profile

# Or add this alias to ~/.zshrc / ~/.bashrc
alias chrome-debug='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222 --no-first-run --user-data-dir=~/.chrome-debug-profile'
```
3. Log into whatever services you want agents to access (Twitter, LinkedIn, etc.)
4. The harness connects automatically when Claude Code tools use browser operations

### When to use which tool

| Need | Tool |
|---|---|
| Screenshot a public page | Playwright |
| Scrape/search the web | Firecrawl |
| Interact with a logged-in account | Browser Harness |
| Post to social media | Browser Harness |
| Access a paywalled or auth-gated page | Browser Harness |

## /creative in Discord

Once Athena is running, type `/creative` in Discord to generate or regenerate visual assets conversationally. Athena routes to the right tool based on what you need.
