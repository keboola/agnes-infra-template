# Curated marketplace plugins

This directory holds the Claude Code plugins your Agnes deployment ships to analysts via the marketplace integration. Each plugin lives in its own sub-directory (`plugins/<slug>/`) and is listed in `../.claude-plugin/marketplace.json`.

## How Agnes consumes this directory

The Agnes server clones this repo nightly (or on manual sync at `/admin/marketplaces`), parses `../.claude-plugin/marketplace.json`, and surfaces each listed plugin to analysts. Plugin install happens on the analyst's laptop via the `/update-agnes-plugins` slash command — Agnes does **not** push plugins to laptops directly.

Files outside `plugins/` and `.claude-plugin/` are invisible to the marketplace parser.

## Per-plugin layout (Claude Code plugin format)

Each plugin directory follows the Claude Code plugin spec:

```
plugins/<slug>/
├── plugin.json    # plugin manifest — name, version, dependencies
├── skills/        # SKILL.md files (optional)
├── agents/        # agent definitions (optional)
└── commands/      # slash-command definitions (optional)
```

See the Claude Code documentation for the full plugin format: <https://docs.claude.com/claude-code/plugins>.

## Registering a new plugin

1. Create `plugins/<slug>/plugin.json` with the manifest.
2. Add the entry to `../.claude-plugin/marketplace.json` under `plugins:`:

   ```json
   {
     "name": "<slug>",
     "version": "0.1.0",
     "source": "./plugins/<slug>",
     "description": "<one-line summary>"
   }
   ```

3. Open a PR. After merge, the Agnes server picks up the change on its next scheduled sync (03:00 UTC) or when an admin clicks "Sync now" at `/admin/marketplaces`.
4. Analysts pick up the new plugin by running `/update-agnes-plugins` in any Claude Code session.

## Optional UI metadata

The Agnes UI can show richer metadata (display name, tagline, cover photo) for each plugin via `../.claude-plugin/marketplace-metadata.json`. The format is documented in the upstream OSS contract:
<https://github.com/keboola/agnes-the-ai-analyst/blob/main/docs/curated-marketplace-format.md>
