# HEARTBEAT.md

## Checks (run these silently, only report problems)

1. **Cron health** — check cron jobs. Flag any with consecutiveErrors > 0.
2. **Session sizes** — check session files. Flag any > 50MB.
3. **CURRENT.md freshness** — flag if not modified in last 48 hours. If stale, update it.
4. **MEMORY.md size** — flag if > 3000 bytes. Needs trimming.
5. **Nightly outcome health** — check nightly agent success rate. Flag any project with <50% success in last 7 days.
6. **Site health** — check live sites. Flag any that aren't responding.
7. **Backup recency** — check latest backup timestamp. Flag if no backup in last 48 hours.
8. **Session bloat** — check for orphaned executor sessions. Flag if >10 found.
9. **Secrets exposure** — scan workspace for exposed credentials. Flag any found.
10. **Weekly compaction** — flag if no memory summary in last 10 days.
11. **Nightly notes activity** — check NIGHTLY-NOTES.md. If no entries in last 7 days, nightly agents aren't writing. Investigate.

If all checks pass, reply: HEARTBEAT_OK
If anything fails, report what's wrong and fix it if safe to do so.
