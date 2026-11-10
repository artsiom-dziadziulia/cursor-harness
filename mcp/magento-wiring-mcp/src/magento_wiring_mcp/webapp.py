"""Local web UI for Magento wiring index (companion to CBM Lens)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import HTMLResponse, JSONResponse, RedirectResponse
from starlette.routing import Route

from .galaxy import build_aheadworks_galaxy, build_module_galaxy
from .index import filter_module, get_index

STATIC_DIR = Path(__file__).parent / "static"


def _module_payload(name: str) -> dict[str, Any] | None:
    idx = get_index()
    if name not in idx.modules:
        return None
    prefs = filter_module(idx.preferences, name)
    plugins = filter_module(idx.plugins, name)
    observers = filter_module(idx.observers, name)
    webapi = filter_module(idx.webapi, name)
    routes = filter_module(idx.routes, name)
    virtuals = filter_module(idx.virtual_types, name)
    foreign = [
        p
        for p in plugins
        if p.get("target") and not str(p["target"]).startswith(f"Aheadworks\\{name}\\")
    ]
    return {
        "module": name,
        "counts": {
            "preferences": len(prefs),
            "plugins": len(plugins),
            "virtualTypes": len(virtuals),
            "observers": len(observers),
            "webapi": len(webapi),
            "routes": len(routes),
            "foreignPlugins": len(foreign),
        },
        "preferences": prefs,
        "plugins": plugins,
        "virtualTypes": virtuals,
        "observers": observers,
        "webapi": webapi,
        "routes": routes,
        "foreignPlugins": foreign,
    }


async def api_stats(_request: Request) -> JSONResponse:
    return JSONResponse(get_index().stats())


async def api_modules(_request: Request) -> JSONResponse:
    idx = get_index()
    rows = []
    for name in idx.modules:
        rows.append(
            {
                "module": name,
                "preferences": len(filter_module(idx.preferences, name)),
                "plugins": len(filter_module(idx.plugins, name)),
                "observers": len(filter_module(idx.observers, name)),
                "webapi": len(filter_module(idx.webapi, name)),
                "routes": len(filter_module(idx.routes, name)),
            }
        )
    return JSONResponse({"modules": rows, "count": len(rows)})


async def api_module(request: Request) -> JSONResponse:
    name = request.path_params["name"]
    payload = _module_payload(name)
    if payload is None:
        return JSONResponse({"error": f"Unknown module: {name}"}, status_code=404)
    return JSONResponse(payload)


async def api_galaxy_aheadworks(_request: Request) -> JSONResponse:
    return JSONResponse(build_aheadworks_galaxy(get_index()))


async def api_galaxy_module(request: Request) -> JSONResponse:
    name = request.path_params["name"]
    payload = build_module_galaxy(get_index(), name)
    if payload.get("error"):
        return JSONResponse(payload, status_code=404)
    return JSONResponse(payload)


async def api_refresh(_request: Request) -> JSONResponse:
    idx = get_index(force=True)
    return JSONResponse(idx.stats())


async def page_home(_request: Request) -> HTMLResponse:
    return HTMLResponse((STATIC_DIR / "index.html").read_text(encoding="utf-8"))


async def page_module(request: Request) -> HTMLResponse:
    name = request.path_params["name"]
    if name not in get_index().modules:
        return RedirectResponse("/")
    return HTMLResponse((STATIC_DIR / "index.html").read_text(encoding="utf-8"))


routes = [
    Route("/", page_home),
    Route("/module/{name}", page_module),
    Route("/api/stats", api_stats),
    Route("/api/modules", api_modules),
    Route("/api/modules/{name}", api_module),
    Route("/api/galaxy/aheadworks", api_galaxy_aheadworks),
    Route("/api/galaxy/modules/{name}", api_galaxy_module),
    Route("/api/refresh", api_refresh, methods=["POST"]),
]

app = Starlette(routes=routes)


def main() -> None:
    import uvicorn

    get_index(force=True)
    host = os.environ.get("MAGENTO_WIRING_UI_HOST", "127.0.0.1")
    port = int(os.environ.get("MAGENTO_WIRING_UI_PORT", "9750"))
    print(f"Magento Wiring UI: http://{host}:{port}/  (CBM Lens usually :9749)")
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
