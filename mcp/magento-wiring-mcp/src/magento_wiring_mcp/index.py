"""Scan Magento module etc/ trees and build an in-memory wiring index."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .parsers import area_from_path, parse_di, parse_events, parse_routes, parse_webapi


@dataclass
class WiringIndex:
    root: Path
    code_path: Path
    built_at: float = 0.0
    modules: list[str] = field(default_factory=list)
    preferences: list[dict[str, Any]] = field(default_factory=list)
    plugins: list[dict[str, Any]] = field(default_factory=list)
    virtual_types: list[dict[str, Any]] = field(default_factory=list)
    observers: list[dict[str, Any]] = field(default_factory=list)
    webapi: list[dict[str, Any]] = field(default_factory=list)
    routes: list[dict[str, Any]] = field(default_factory=list)

    def stats(self) -> dict[str, Any]:
        return {
            "root": str(self.root),
            "code_path": str(self.code_path),
            "modules": len(self.modules),
            "preferences": len(self.preferences),
            "plugins": len(self.plugins),
            "virtualTypes": len(self.virtual_types),
            "observers": len(self.observers),
            "webapi": len(self.webapi),
            "routes": len(self.routes),
            "built_at": self.built_at,
        }


def resolve_code_root() -> tuple[Path, Path]:
    """Return (magento_root, code_vendor_path) from env."""
    root = Path(os.environ.get("MAGENTO_ROOT", "")).expanduser()
    if not root.is_dir():
        raise RuntimeError(
            "MAGENTO_ROOT is not set or not a directory. "
            "Example: MAGENTO_ROOT=/media/ssdwork/Sites/m249ee2/src"
        )
    rel = os.environ.get("MAGENTO_CODE_PATH", "app/code/Aheadworks")
    code = (root / rel).resolve()
    if not code.is_dir():
        raise RuntimeError(f"Code path not found: {code}")
    return root.resolve(), code


def build_index() -> WiringIndex:
    root, code = resolve_code_root()
    idx = WiringIndex(root=root, code_path=code)

    modules = sorted(
        p.name
        for p in code.iterdir()
        if p.is_dir() and not p.name.startswith(".") and (p / "etc").is_dir()
    )
    idx.modules = modules

    for module in modules:
        etc = code / module / "etc"
        # di.xml anywhere under etc/
        for path in sorted(etc.rglob("di.xml")):
            area = area_from_path(path, etc)
            parsed = parse_di(path, module, area)
            idx.preferences.extend(parsed["preferences"])
            idx.plugins.extend(parsed["plugins"])
            idx.virtual_types.extend(parsed["virtualTypes"])

        for path in sorted(etc.rglob("events.xml")):
            area = area_from_path(path, etc)
            idx.observers.extend(parse_events(path, module, area))

        for path in sorted(etc.rglob("webapi.xml")):
            idx.webapi.extend(parse_webapi(path, module))

        for path in sorted(etc.rglob("routes.xml")):
            area = area_from_path(path, etc)
            idx.routes.extend(parse_routes(path, module, area))

    idx.built_at = time.time()
    return idx


_INDEX: WiringIndex | None = None


def get_index(*, force: bool = False) -> WiringIndex:
    global _INDEX
    if _INDEX is None or force:
        _INDEX = build_index()
    return _INDEX


def filter_module(rows: list[dict[str, Any]], module: str | None) -> list[dict[str, Any]]:
    if not module:
        return rows
    needle = module.strip()
    if needle.startswith("Aheadworks_"):
        needle = needle[len("Aheadworks_") :]
    return [r for r in rows if r.get("module") == needle]


def contains_ci(hay: str, needle: str) -> bool:
    return needle.lower() in hay.lower()
