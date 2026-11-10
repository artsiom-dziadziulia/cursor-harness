# Magento Wiring MCP

MCP server that indexes Magento 2 `etc/*.xml` wiring for Aheadworks modules:

- `di.xml` — preferences, plugins, virtualTypes
- `events.xml` — observers
- `webapi.xml` — REST routes
- `routes.xml` — frontNames

Complements [Codebase Memory](https://github.com/DeusData/codebase-memory-mcp): CBM = PHP call graph; this server = Magento DI/events/API XML.

## Quick start

```bash
cd /media/ssdwork/Sites/magento-wiring-mcp
python3 -m venv .venv
.venv/bin/pip install -e .
```

Cursor / Claude MCP (stdio):

```json
{
  "mcpServers": {
    "magento-wiring": {
      "command": "/media/ssdwork/Sites/magento-wiring-mcp/.venv/bin/magento-wiring-mcp",
      "env": {
        "MAGENTO_ROOT": "/media/ssdwork/Sites/m249ee2/src",
        "MAGENTO_CODE_PATH": "app/code/Aheadworks"
      }
    }
  }
}
```

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `MAGENTO_ROOT` | required | Magento `src/` (contains `app/code`) |
| `MAGENTO_CODE_PATH` | `app/code/Aheadworks` | Relative path to scan |

Portable: change only these two env vars on another machine/server.

## Tools

| Tool | Purpose |
|---|---|
| `module_wiring` | Cheap card for one module |
| `list_plugins` / `list_preferences` / `list_observers` | Filtered wiring |
| `list_webapi` / `list_routes` | API and frontName routes |
| `list_modules` / `index_stats` / `refresh_index` | Inventory |

## Web UI (companion to CBM Lens)

CBM Lens is usually `http://127.0.0.1:9749`. Wiring UI defaults to **9750**.

When Cursor starts `magento-wiring-mcp`, it **autostarts** the UI if the port is free (same lifecycle as opening a Magento project with Lens). Disable with `MAGENTO_WIRING_UI_AUTOSTART=0`.

Manual:

```bash
MAGENTO_ROOT=/media/ssdwork/Sites/m249ee2/src \
  .venv/bin/magento-wiring-ui
```

Env: `MAGENTO_WIRING_UI_HOST` (default `127.0.0.1`), `MAGENTO_WIRING_UI_PORT` (default `9750`), `MAGENTO_WIRING_UI_AUTOSTART` (default `1`). Log: `~/.cache/magento-wiring-mcp/ui.log`.

Open `http://127.0.0.1:9750/` — module list, **Galaxy** (force graph: WRAPS / PREFERENCE / OBSERVES / HANDLES), Tables, Refresh index.

## Smoke

```bash
MAGENTO_ROOT=/media/ssdwork/Sites/m249ee2/src \
  .venv/bin/python -c "
from magento_wiring_mcp.index import get_index
i=get_index(force=True)
print(i.stats())
"
```
