# Magento Wiring MCP

Companion to Codebase Memory for **Magento XML wiring** (what CBM call-graph misses).

| Concern | Tool |
|---|---|
| PHP structure / callers | CBM (`search_graph`, `trace_path`, …) |
| Plugins, preferences, observers, webapi, routes | **magento-wiring** MCP |

Server (portable, outside Magento tree):  
`/media/ssdwork/Sites/magento-wiring-mcp` — see its `README.md`.

### Web UI

Not part of CBM Lens (cannot inject into it). Companion UI on **`:9750`**.

**Autostart with Lens:** when Cursor starts the `magento-wiring` MCP (same session that brings up CBM Lens on `:9749`), the MCP process starts Wiring UI if the port is free. Controlled by env in [`.cursor/mcp.json`](../../.cursor/mcp.json):

| Env | Default | Meaning |
|---|---|---|
| `MAGENTO_WIRING_UI_AUTOSTART` | `1` | `0` / `false` / `off` — do not spawn UI |
| `MAGENTO_WIRING_UI_HOST` | `127.0.0.1` | bind address |
| `MAGENTO_WIRING_UI_PORT` | `9750` | HTTP port |

Log: `~/.cache/magento-wiring-mcp/ui.log`. Manual start (if MCP not running):

```bash
MAGENTO_ROOT=/media/ssdwork/Sites/m249ee2/src \
  /media/ssdwork/Sites/magento-wiring-mcp/.venv/bin/magento-wiring-ui
```

- Wiring UI: http://127.0.0.1:9750/  
  - **All Aheadworks** / **per-module** Galaxy — **3D orbit** (drag rotate, scroll zoom), hierarchy mode, Tables  
  - Cross-module WRAPS / PREFERENCE (+ Magento_core); module view includes inbound plugins  
- CBM Lens: http://127.0.0.1:9749/ (PHP call graph; not Magento DI)  

## Config (this project)

[`.cursor/mcp.json`](../../.cursor/mcp.json) → server `magento-wiring` with:

- `MAGENTO_ROOT` = this `src/`
- `MAGENTO_CODE_PATH` = `app/code/Aheadworks`

Cursor rule (auto when editing Aheadworks code): [`.cursor/rules/magento-wiring-mcp.mdc`](../../.cursor/rules/magento-wiring-mcp.mdc).

## Agent protocol

When analysing, implementing, documenting, or reviewing an Aheadworks module:

1. `module_wiring("<Module>")` — cheap card (counts + foreign plugins + samples).
2. Drill with `list_plugins` / `list_preferences` / `list_observers` / `list_webapi` / `list_routes` as needed.
3. Confirm class behaviour in PHP via CBM or disk `Read`.
4. After editing `etc/*.xml` in a task → `refresh_index`.

Do **not** claim “no plugin on X” from CBM alone — check `list_plugins(target=…)`.

## Harness stages (required)

| Stage / role | When to call wiring MCP |
|---|---|
| S1 `aw-analyst` | After module docs; before PHP deep-dive if entry is plugin/observer/API/route — always `module_wiring` for the module under analysis |
| S2 `aw-planner` | When plan touches DI/events/webapi/routes |
| S4 `aw-developer` | Before editing wiring; `refresh_index` after `etc/*.xml` changes |
| S5 `aw-code-reviewer` | Verify plugin/observer/API registration against `list_*` |
| S7 `aw-doc-keeper` | Reconcile ARCHITECTURE / INTEGRATIONS tables with `module_wiring` + `list_*` |
| `/aw-document-module` / `aw-module-documenter` | **Required** inventory source for plugins/observers/webapi/routes |
| `magento-issue-debugger` | First stop for plugin conflict / observer / API routing questions |

Orchestrator: if a subagent skips wiring for a DI-related task, send it back.

## Scope / limits

- Scans only `MAGENTO_CODE_PATH` (default Aheadworks). Core/vendor targets appear as **plugin targets**, but Magento core `di.xml` is not indexed.
- Layout XML → block/template not in v0.1.
- GraphQL `schema.graphqls` not parsed (use disk / CBM `search_code`).
- If the MCP server is unavailable: fall back to reading `etc/*.xml` on disk and note the fallback in the artifact.
