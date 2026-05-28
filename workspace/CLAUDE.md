# Agnes — analyst workspace

This workspace is connected to an Agnes deployment. Use Claude Code to query data through the `agnes` CLI.

> Looking for human-readable workspace docs? Open `AGNES_WORKSPACE.md` in this directory — that file documents what `agnes init` installed, where files live, and how to uninstall.

## Rules

- Before computing any business metric: `agnes catalog --metrics --show <category>/<name>` — never invent metric calculations.
- Treat `agnes catalog` as the source of truth for available tables and their `query_mode` (`local`, `remote`, `materialized`).
- Do not use `DESCRIBE` / `SHOW COLUMNS` — use `agnes schema <table>` instead.
- Sync data regularly with `agnes pull` (the SessionStart hook does this automatically at session start).
- **Personal notes go in `.claude/CLAUDE.local.md`, NOT here.** This file is regenerated on `agnes init --force`; edits here will be lost. `CLAUDE.local.md` is preserved and uploaded on `agnes push`.

## Metrics workflow

1. `agnes catalog --metrics` — list registered metrics + categories
2. `agnes catalog --metrics --show <category>/<name>` — read the canonical SQL + business rules
3. Adapt the canonical SQL; never write metric calculations from scratch.

## Data sync

- `agnes pull` — download current data from server (auto on SessionStart)
- `agnes push` — upload session transcripts + `CLAUDE.local.md` to server (auto on SessionEnd)
- `agnes catalog` — what's available, what each table contains
- `agnes schema <table>` — column list + types
- `agnes describe <table> -n 5` — five sample rows

## Querying

For tables with `query_mode = local` or `materialized`:

```
agnes query "SELECT … FROM <table>"
```

For tables with `query_mode = remote` (backed by a warehouse — BigQuery, Snowflake, etc.), data is NOT on disk. Choose one:

- One-shot aggregate (cheap):
  ```
  agnes query --remote "SELECT COUNT(*) FROM <table>"
  ```
- Filtered subset for local exploration:
  ```
  agnes snapshot create <name> --select <cols> --where '<predicate>' --estimate
  agnes snapshot create <name> --select <cols> --where '<predicate>' --as <local_name>
  agnes query "SELECT … FROM <local_name>"
  ```

Always run `--estimate` first on remote tables. The default scan cap is 5 GiB; bigger scans get rejected with `remote_scan_too_large`.

## Private sessions

`/agnes-private` — mark the current Claude Code session as private. The transcript will be skipped the next time `agnes push` runs.

## Marketplace plugins

`/update-agnes-plugins` — refresh marketplace plugins for this workspace. Run after the operator has shipped new plugin versions to the configured marketplace.

---

> **Operator note:** This file ships from your infra repo's `workspace/CLAUDE.md`. Replace this placeholder with deployment-specific rules (per-team metrics, internal terminology, on-call playbooks) before pointing your Agnes server's Initial Workspace Template at the repo. Analysts pick up changes on their next `agnes init --force` after you sync the template at `/admin/server-config`.
