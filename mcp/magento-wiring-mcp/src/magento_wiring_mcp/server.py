"""MCP stdio server exposing Magento XML wiring tools."""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

from .index import contains_ci, filter_module, get_index

mcp = FastMCP(
    "magento-wiring",
    instructions=(
        "Magento 2 XML wiring for Aheadworks modules: plugins, preferences, "
        "observers, webapi, routes. Use alongside Codebase Memory for PHP call graphs. "
        "Call refresh_index after editing etc/*.xml. Prefer module_wiring for a cheap overview."
    ),
)


def _dumps(data: Any, *, limit: int | None = None) -> str:
    if isinstance(data, list) and limit is not None:
        truncated = len(data) > limit
        payload: Any = {
            "count": len(data),
            "showing": min(len(data), limit),
            "items": data[:limit],
        }
        if truncated:
            payload["truncated"] = True
        data = payload
    return json.dumps(data, ensure_ascii=False, indent=2)


@mcp.tool()
def refresh_index() -> str:
    """Rebuild the wiring index from MAGENTO_ROOT / MAGENTO_CODE_PATH. Call after XML edits."""
    idx = get_index(force=True)
    return _dumps(idx.stats())


@mcp.tool()
def index_stats() -> str:
    """Return counts for the current in-memory wiring index (builds on first call)."""
    return _dumps(get_index().stats())


@mcp.tool()
def list_modules() -> str:
    """List module directory names under MAGENTO_CODE_PATH that have etc/."""
    idx = get_index()
    return _dumps({"modules": idx.modules, "count": len(idx.modules)})


@mcp.tool()
def module_wiring(module: str) -> str:
    """Compact wiring card for one module (preferences/plugins/observers/webapi/routes counts + samples)."""
    idx = get_index()
    name = module.strip()
    if name.startswith("Aheadworks_"):
        name = name[len("Aheadworks_") :]
    if name not in idx.modules:
        return _dumps({"error": f"Unknown module: {module}", "hint": "Use list_modules"})

    prefs = filter_module(idx.preferences, name)
    plugins = filter_module(idx.plugins, name)
    observers = filter_module(idx.observers, name)
    webapi = filter_module(idx.webapi, name)
    routes = filter_module(idx.routes, name)
    virtuals = filter_module(idx.virtual_types, name)

    return _dumps(
        {
            "module": name,
            "counts": {
                "preferences": len(prefs),
                "plugins": len(plugins),
                "virtualTypes": len(virtuals),
                "observers": len(observers),
                "webapi": len(webapi),
                "routes": len(routes),
            },
            "plugins_on_core_or_foreign": [
                {"target": p["target"], "name": p["name"], "type": p["type"], "area": p["area"]}
                for p in plugins
                if p.get("target") and not str(p["target"]).startswith(f"Aheadworks\\{name}\\")
            ][:25],
            "sample_preferences": [
                {"for": p["for"], "type": p["type"], "area": p["area"]} for p in prefs[:15]
            ],
            "sample_observers": [
                {"event": o["event"], "instance": o["instance"], "area": o["area"]}
                for o in observers[:15]
            ],
            "sample_webapi": [
                {
                    "method": w["httpMethod"],
                    "url": w["url"],
                    "service": w["service"],
                    "serviceMethod": w["serviceMethod"],
                }
                for w in webapi[:15]
            ],
            "routes": [
                {
                    "area": r["area"],
                    "frontName": r["frontName"],
                    "id": r["id"],
                    "router": r["router"],
                }
                for r in routes
            ],
        }
    )


@mcp.tool()
def list_plugins(
    module: str | None = None,
    target: str | None = None,
    plugin_type: str | None = None,
    limit: int = 50,
) -> str:
    """List di.xml plugins. Optional filters: module, target class substring, plugin type/class substring."""
    idx = get_index()
    rows = filter_module(idx.plugins, module)
    if target:
        rows = [r for r in rows if contains_ci(r.get("target", ""), target)]
    if plugin_type:
        rows = [r for r in rows if contains_ci(r.get("type", ""), plugin_type)]
    rows = sorted(rows, key=lambda r: (r.get("target", ""), r.get("sortOrder", "0"), r.get("name", "")))
    return _dumps(rows, limit=max(1, min(limit, 200)))


@mcp.tool()
def list_preferences(
    module: str | None = None,
    interface: str | None = None,
    limit: int = 50,
) -> str:
    """List di.xml preferences. Optional filters: module, interface/for substring."""
    idx = get_index()
    rows = filter_module(idx.preferences, module)
    if interface:
        rows = [r for r in rows if contains_ci(r.get("for", ""), interface) or contains_ci(r.get("type", ""), interface)]
    rows = sorted(rows, key=lambda r: r.get("for", ""))
    return _dumps(rows, limit=max(1, min(limit, 200)))


@mcp.tool()
def list_observers(
    module: str | None = None,
    event: str | None = None,
    limit: int = 50,
) -> str:
    """List events.xml observers. Optional filters: module, event name substring."""
    idx = get_index()
    rows = filter_module(idx.observers, module)
    if event:
        rows = [r for r in rows if contains_ci(r.get("event", ""), event)]
    rows = sorted(rows, key=lambda r: (r.get("event", ""), r.get("name", "")))
    return _dumps(rows, limit=max(1, min(limit, 200)))


@mcp.tool()
def list_webapi(module: str | None = None, limit: int = 50) -> str:
    """List webapi.xml routes (REST). Optional module filter."""
    idx = get_index()
    rows = filter_module(idx.webapi, module)
    rows = sorted(rows, key=lambda r: (r.get("url", ""), r.get("httpMethod", "")))
    return _dumps(rows, limit=max(1, min(limit, 200)))


@mcp.tool()
def list_routes(module: str | None = None, limit: int = 50) -> str:
    """List routes.xml frontNames (adminhtml/frontend). Optional module filter."""
    idx = get_index()
    rows = filter_module(idx.routes, module)
    rows = sorted(rows, key=lambda r: (r.get("area", ""), r.get("frontName", "")))
    return _dumps(rows, limit=max(1, min(limit, 200)))


def _ui_autostart_enabled() -> bool:
    flag = os.environ.get("MAGENTO_WIRING_UI_AUTOSTART", "1").strip().lower()
    return flag not in ("0", "false", "no", "off")


def _port_is_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.35):
            return True
    except OSError:
        return False


def _ensure_wiring_ui() -> None:
    """Start companion HTTP UI (default :9750) alongside MCP — same Cursor lifecycle as CBM Lens."""
    if not _ui_autostart_enabled():
        return
    host = os.environ.get("MAGENTO_WIRING_UI_HOST", "127.0.0.1")
    port = int(os.environ.get("MAGENTO_WIRING_UI_PORT", "9750"))
    if _port_is_open(host, port):
        return

    ui_bin = Path(sys.executable).resolve().parent / "magento-wiring-ui"
    if ui_bin.is_file():
        cmd = [str(ui_bin)]
    else:
        cmd = [sys.executable, "-m", "magento_wiring_mcp.webapp"]

    log_dir = Path.home() / ".cache" / "magento-wiring-mcp"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / "ui.log"
    # Detach so stdio MCP is not polluted; survive parent only until Cursor kills the session group
    # if the OS reaps the process group — start_new_session keeps UI up for the work session.
    with log_path.open("a", encoding="utf-8") as log:
        log.write(f"\n--- autostart ui {host}:{port} ---\n")
        log.flush()
        subprocess.Popen(
            cmd,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=os.environ.copy(),
            close_fds=True,
        )


def main() -> None:
    # Eager build so misconfig fails at startup with a clear error.
    get_index(force=True)
    _ensure_wiring_ui()
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
