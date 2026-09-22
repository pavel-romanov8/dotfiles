# Pi observational memory

[`pi-observational-memory`](https://github.com/elpapi42/pi-observational-memory) keeps a branch-local ledger of observations and durable reflections, then uses that prepared memory for fast compaction. It is useful for long, multi-day Pi sessions where decisions and rationale need to survive repeated compactions.

This repository pins **`pi-observational-memory@3.1.4`**. It requires Pi 0.81.0 or newer.

## Install

Close Pi before changing its global settings, then run:

```bash
./pi/setup-observational-memory.sh
```

The setup script:

1. validates the existing global `settings.json`;
2. installs the pinned npm package globally through Pi;
3. merges `pi/observational-memory.json` into the global Pi settings.

The checked-in file is the shared source of truth: setup replaces the complete `observational-memory` namespace on every machine while preserving unrelated Pi settings. A changed settings file receives a uniquely named private backup. Restart Pi (or run `/reload`) and start a new session after installation. V3 does not migrate memory from the old V2 format.

## Shared configuration

```json
{
  "observational-memory": {
    "compactAfterTokensMode": "ratio",
    "compactAfterTokensRatio": 0.5,
    "showWorkerNotifications": false
  }
}
```

This is the exact content of `pi/observational-memory.json`. The package defaults are otherwise retained, and omitting `model` intentionally makes workers use the current session model. Ratio mode uses half of the active model's advertised context window for proactive compaction instead of the fixed 81K source-token threshold. On the current 272K default model this resolves to about 136K estimated source-entry tokens. Pi's own context-pressure compaction remains independent and may run first.

Routine worker notifications are hidden to reduce UI noise. Errors, model fallbacks, compaction notices, and explicit `/om:*` output remain visible.

## Configuration

Settings can be global in `~/.pi/agent/settings.json` (or `$PI_CODING_AGENT_DIR/settings.json`) or project-local in `.pi/settings.json`. Project values override global values. Restart Pi or run `/reload` after changes.

| Setting | Default | Purpose |
| --- | --- | --- |
| `observeAfterTokens` | `10000` | Source-token interval between observer runs. Lower is more current but costs more model calls. |
| `observerChunkMaxTokens` | 20% of worker context, fallback `60000` | Maximum estimated source tokens sent to one observer request; minimum 256. |
| `reflectAfterTokens` | `20000` | Source-token interval for durable reflections and subsequent dropper opportunities. |
| `compactAfterTokens` | `81000` | Fixed proactive threshold in `calibrated` mode and fallback when ratio mode cannot read a context window. |
| `compactAfterTokensMode` | `calibrated` | `calibrated` uses the fixed threshold; `ratio` scales to the active model context window. |
| `compactAfterTokensRatio` | `0.68` | Ratio-mode threshold; must be greater than 0 and less than 1. This repo sets `0.5`. |
| `observationsPoolMaxTokens` | `20000` | Visible observation pressure that causes compaction to perform a full fold. |
| `observationsPoolTargetTokens` | half of max (`10000`) | Active observation target used by post-reflection pruning; must be below max. |
| `agentMaxTurns` | `16` | Turn cap for each background observer, reflector, or dropper loop. |
| `agentMaxTokens` | `32000` | Requested output-token cap for workers, clamped to the selected model's maximum. |
| `model` | current session model | Optional `{ "provider", "id", "thinking" }` worker-model override. |
| `showWorkerNotifications` | `true` | Show routine worker progress. This repo sets `false`. |
| `passive` | `false` | Disable proactive workers and auto-compaction while retaining commands, recall, and the manual compaction hook. |
| `debugLog` | `false` | Write sensitive local NDJSON diagnostics below the Pi agent directory. |

Valid `model.thinking` values are `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `max`. Without a model override, workers use the session model with low thinking. A dedicated cheaper model can reduce cost, but it must exist in Pi's model registry and have working authentication.

### Useful profiles

Keep the checked-in configuration for a balanced long-session setup. Add shared changes directly to `pi/observational-memory.json`; rerunning setup distributes them to each machine.

Lower background cost and frequency:

```json
{
  "observational-memory": {
    "observeAfterTokens": 20000,
    "reflectAfterTokens": 50000,
    "agentMaxTurns": 8
  }
}
```

More responsive memory, with more background calls:

```json
{
  "observational-memory": {
    "observeAfterTokens": 5000,
    "reflectAfterTokens": 10000
  }
}
```

Temporarily disable proactive work for one launch:

```bash
PI_OBSERVATIONAL_MEMORY_PASSIVE=1 pi
```

For a local model with a smaller context window, explicitly reduce both request sides, for example:

```json
{
  "observational-memory": {
    "observerChunkMaxTokens": 10000,
    "agentMaxTokens": 8192
  }
}
```

## Commands and behavior

- `/om:status` shows counts, worker state, token clocks, pool pressure, and errors.
- `/om:view` shows memory currently visible after compaction and tries to copy it to the system clipboard.
- `/om:view full` shows the full branch ledger, including memory not yet folded into visible context.
- The agent-facing `recall` tool retrieves source evidence for a specific 12-character observation or reflection id; it is not semantic search.

The extension makes background model requests containing session source chunks and prior memory. This has the same provider privacy and usage implications as other model calls. It runs with full user permissions like every Pi extension. In the reviewed 3.1.4 package, local process execution is limited to fixed platform clipboard commands for `/om:view`; opt-in debug logging writes under `~/.pi/agent/observational-memory/`.

## Update or remove

The version is pinned, so normal package updates do not move it. Review a newer release, change the version in `setup-observational-memory.sh`, and rerun the script.

Remove the package with:

```bash
pi remove npm:pi-observational-memory
```

Removal leaves the `observational-memory` settings namespace in place for a later reinstall; delete that namespace manually if it is no longer wanted.
