"""Parse Magento etc/*.xml into structured wiring records."""

from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


def _local(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def _attr(el: ET.Element, *names: str) -> str:
    for name in names:
        val = el.attrib.get(name)
        if val is not None and str(val).strip() != "":
            return str(val).strip()
    return ""


def parse_di(path: Path, module: str, area: str) -> dict[str, list[dict[str, Any]]]:
    """Extract preferences, plugins, virtualTypes from a di.xml."""
    prefs: list[dict[str, Any]] = []
    plugins: list[dict[str, Any]] = []
    virtuals: list[dict[str, Any]] = []

    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return {"preferences": prefs, "plugins": plugins, "virtualTypes": virtuals}

    for el in root.iter():
        tag = _local(el.tag)
        if tag == "preference":
            prefs.append(
                {
                    "for": _attr(el, "for"),
                    "type": _attr(el, "type"),
                    "module": module,
                    "area": area,
                    "file": str(path),
                }
            )
        elif tag == "virtualType":
            virtuals.append(
                {
                    "name": _attr(el, "name"),
                    "type": _attr(el, "type"),
                    "module": module,
                    "area": area,
                    "file": str(path),
                }
            )

    # Rebuild parent map for plugins nested under <type>
    parent_map: dict[ET.Element, ET.Element] = {}
    for parent in root.iter():
        for child in list(parent):
            parent_map[child] = parent

    for el in root.iter():
        if _local(el.tag) != "plugin":
            continue
        parent = parent_map.get(el)
        target = _attr(parent, "name") if parent is not None and _local(parent.tag) == "type" else ""
        disabled = _attr(el, "disabled").lower() in ("true", "1")
        plugins.append(
            {
                "name": _attr(el, "name"),
                "type": _attr(el, "type"),
                "target": target,
                "sortOrder": _attr(el, "sortOrder") or "0",
                "disabled": disabled,
                "module": module,
                "area": area,
                "file": str(path),
            }
        )

    return {"preferences": prefs, "plugins": plugins, "virtualTypes": virtuals}


def parse_events(path: Path, module: str, area: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return rows

    parent_map: dict[ET.Element, ET.Element] = {}
    for parent in root.iter():
        for child in list(parent):
            parent_map[child] = parent

    for el in root.iter():
        if _local(el.tag) != "observer":
            continue
        parent = parent_map.get(el)
        event = _attr(parent, "name") if parent is not None and _local(parent.tag) == "event" else ""
        rows.append(
            {
                "event": event,
                "name": _attr(el, "name"),
                "instance": _attr(el, "instance"),
                "disabled": _attr(el, "disabled").lower() in ("true", "1"),
                "shared": _attr(el, "shared"),
                "module": module,
                "area": area,
                "file": str(path),
            }
        )
    return rows


def parse_webapi(path: Path, module: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return rows

    parent_map: dict[ET.Element, ET.Element] = {}
    for parent in root.iter():
        for child in list(parent):
            parent_map[child] = parent

    for el in root.iter():
        if _local(el.tag) != "route":
            continue
        # webapi route has url + method; service is child
        url = _attr(el, "url")
        method = _attr(el, "method")
        service_class = ""
        service_method = ""
        for child in list(el):
            if _local(child.tag) == "service":
                service_class = _attr(child, "class")
                service_method = _attr(child, "method")
        if not url:
            continue
        rows.append(
            {
                "url": url,
                "httpMethod": method,
                "service": service_class,
                "serviceMethod": service_method,
                "module": module,
                "file": str(path),
            }
        )
    return rows


def parse_routes(path: Path, module: str, area: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return rows

    parent_map: dict[ET.Element, ET.Element] = {}
    for parent in root.iter():
        for child in list(parent):
            parent_map[child] = parent

    for el in root.iter():
        if _local(el.tag) != "route":
            continue
        parent = parent_map.get(el)
        router_id = _attr(parent, "id") if parent is not None and _local(parent.tag) == "router" else ""
        modules: list[str] = []
        for child in list(el):
            if _local(child.tag) == "module":
                modules.append(_attr(child, "name"))
        rows.append(
            {
                "id": _attr(el, "id"),
                "frontName": _attr(el, "frontName"),
                "router": router_id,
                "modules": modules,
                "module": module,
                "area": area,
                "file": str(path),
            }
        )
    return rows


def area_from_path(path: Path, etc_dir: Path) -> str:
    """etc/di.xml → global; etc/adminhtml/di.xml → adminhtml; etc/frontend/... → frontend."""
    try:
        rel = path.relative_to(etc_dir)
    except ValueError:
        return "global"
    parts = rel.parts
    if len(parts) >= 2 and parts[0] in ("adminhtml", "frontend", "crontab", "graphql", "webapi_rest", "webapi_soap"):
        return parts[0]
    return "global"
