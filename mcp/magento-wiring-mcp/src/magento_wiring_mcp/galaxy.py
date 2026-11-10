"""Build Galaxy graphs: Aheadworks entity cloud + per-module wiring."""

from __future__ import annotations

from typing import Any

from .index import WiringIndex, filter_module


def aw_owner(fqcn: str | None, modules: list[str]) -> str | None:
    """Map Aheadworks\\Foo\\... to module directory name Foo (longest prefix wins)."""
    if not fqcn or not fqcn.startswith("Aheadworks\\"):
        return None
    rest = fqcn[len("Aheadworks\\") :]
    best: str | None = None
    for mod in modules:
        if rest == mod or rest.startswith(mod + "\\"):
            if best is None or len(mod) > len(best):
                best = mod
    return best


def target_bucket(fqcn: str | None, modules: list[str]) -> str:
    """Module name, Magento_core, or Other."""
    if not fqcn:
        return "Other"
    owner = aw_owner(fqcn, modules)
    if owner:
        return owner
    if fqcn.startswith("Magento\\") or fqcn.startswith("Magento\\\\"):
        return "Magento_core"
    return "Other"


def _short(fqcn: str) -> str:
    return fqcn.rsplit("\\", 1)[-1] if fqcn else ""


def build_aheadworks_galaxy(idx: WiringIndex) -> dict[str, Any]:
    """
    Module-level overview: Aheadworks modules ↔ each other and Magento_core only.

    No class/plugin/observer/webapi nodes here — those live in per-module galaxy.
    Aggregates plugin WRAPS and cross-module PREFERENCE edges.
    """
    modules = list(idx.modules)
    edge_acc: dict[tuple[str, str, str], dict[str, Any]] = {}

    def bump(src: str, dst: str, kind: str, sample: str) -> None:
        if not src or not dst or src == dst:
            return
        # Overview: only AW↔AW and AW↔Magento_core (Other kept as optional hub)
        allowed_dst = dst in modules or dst in ("Magento_core", "Other")
        allowed_src = src in modules or src in ("Magento_core", "Other")
        if not (allowed_src and allowed_dst):
            return
        key = (src, dst, kind)
        if key not in edge_acc:
            edge_acc[key] = {
                "source": src,
                "target": dst,
                "kind": kind,
                "count": 0,
                "samples": [],
                "fromModule": src if src in modules else None,
                "toModule": dst if dst in modules else dst,
            }
        edge_acc[key]["count"] += 1
        if sample and len(edge_acc[key]["samples"]) < 5:
            edge_acc[key]["samples"].append(sample)

    for p in idx.plugins:
        src = p.get("module") or ""
        if not src:
            continue
        dst = target_bucket(p.get("target"), modules)
        if dst == src:
            continue  # intra-module wrap — not an overview edge
        bump(src, dst, "WRAPS", f"{p.get('name')}: {p.get('type')} → {p.get('target')}")

    for pref in idx.preferences:
        src = pref.get("module") or ""
        if not src:
            continue
        for_side = target_bucket(pref.get("for"), modules)
        type_side = target_bucket(pref.get("type"), modules)
        # Preference "for" another AW module (or Magento interface → still Magento_core / Other)
        if for_side != src and for_side in modules:
            bump(src, for_side, "PREFERENCE", f"{pref.get('type')} for {pref.get('for')}")
        elif for_side == "Magento_core":
            bump(src, "Magento_core", "PREFERENCE", f"{pref.get('type')} for {pref.get('for')}")
        # Impl living in another AW module
        if type_side != src and type_side in modules:
            bump(src, type_side, "PREFERENCE", f"{pref.get('for')} → {pref.get('type')}")

    linked = set(modules)
    for e in edge_acc.values():
        linked.add(e["source"])
        linked.add(e["target"])

    nodes: list[dict[str, Any]] = []
    for name in sorted(linked):
        if name == "Magento_core":
            nodes.append(
                {
                    "id": name,
                    "kind": "magento",
                    "label": "Magento core",
                    "isModule": False,
                }
            )
        elif name == "Other":
            nodes.append(
                {
                    "id": name,
                    "kind": "external",
                    "label": "Other",
                    "isModule": False,
                }
            )
        else:
            nodes.append(
                {
                    "id": name,
                    "kind": "module",
                    "label": name,
                    "plugins": len(filter_module(idx.plugins, name)),
                    "observers": len(filter_module(idx.observers, name)),
                    "preferences": len(filter_module(idx.preferences, name)),
                    "webapi": len(filter_module(idx.webapi, name)),
                    "isModule": True,
                }
            )

    links = sorted(edge_acc.values(), key=lambda e: (-e["count"], e["source"], e["target"]))
    return {
        "scope": "aheadworks",
        "mode": "modules",
        "nodes": nodes,
        "links": links,
        "stats": {
            "modules": len(modules),
            "nodes": len(nodes),
            "crossEdges": len(links),
            "wrapsToCore": sum(1 for e in links if e["target"] == "Magento_core" and e["kind"] == "WRAPS"),
            "wrapsBetweenAw": sum(
                1
                for e in links
                if e["kind"] == "WRAPS" and e["source"] in modules and e["target"] in modules
            ),
        },
    }


def build_module_galaxy(idx: WiringIndex, module: str) -> dict[str, Any]:
    """
    Class-level graph for one module — full wiring as declared in etc/:
    plugins, preferences, observers, webapi, virtualTypes, routes.xml,
    inbound plugins. Magento / third-party targets keep real FQCNs (no hub collapse).
    CONTAINS spokes attach entities to the module hub for layout.
    """
    modules = list(idx.modules)
    if module not in modules:
        return {"error": f"Unknown module: {module}"}

    nodes: dict[str, dict[str, Any]] = {}
    links: list[dict[str, Any]] = []

    def add_node(nid: str, kind: str, label: str, **extra: Any) -> None:
        if nid not in nodes:
            nodes[nid] = {"id": nid, "kind": kind, "label": label, "full": nid, **extra}
        else:
            nodes[nid].update({k: v for k, v in extra.items() if v is not None})

    def resolve_class(fqcn: str) -> tuple[str, str, str | None]:
        """Keep real FQCN; classify owner (this module / other AW / Magento / external)."""
        if not fqcn:
            return ("", "target", None)
        owner = aw_owner(fqcn, modules)
        if owner == module:
            return (fqcn, "target", module)
        if owner and owner != module:
            return (fqcn, "foreign_aw", owner)
        if fqcn.startswith("Magento\\"):
            return (fqcn, "magento", None)
        return (fqcn, "external", None)

    add_node(
        module,
        "module",
        module,
        isModule=True,
        plugins=len(filter_module(idx.plugins, module)),
        observers=len(filter_module(idx.observers, module)),
        preferences=len(filter_module(idx.preferences, module)),
        webapi=len(filter_module(idx.webapi, module)),
        virtualTypes=len(filter_module(idx.virtual_types, module)),
        routes=len(filter_module(idx.routes, module)),
    )

    contain_seen: set[str] = set()

    def belong(nid: str, *, from_module: str | None = None) -> None:
        if not nid or nid == module:
            return
        if nid in contain_seen:
            return
        contain_seen.add(nid)
        links.append(
            {
                "source": nid,
                "target": module,
                "kind": "CONTAINS",
                "label": "in",
                "fromModule": from_module or module,
                "toModule": module,
            }
        )

    for p in filter_module(idx.plugins, module):
        if p.get("disabled"):
            continue
        src = p.get("type") or ""
        if not src:
            continue
        add_node(src, "plugin", _short(src), module=module, area=p.get("area"), name=p.get("name"))
        belong(src)
        tgt_raw = p.get("target") or ""
        tgt_id, kind, owner = resolve_class(tgt_raw)
        if not tgt_id:
            continue
        add_node(
            tgt_id,
            kind,
            _short(tgt_raw),
            module=owner,
            foreign=kind in ("magento", "foreign_aw", "external"),
        )
        if owner == module:
            belong(tgt_id)
        links.append(
            {
                "source": src,
                "target": tgt_id,
                "kind": "WRAPS",
                "label": p.get("name") or "plugin",
                "sample": f"{src} → {tgt_raw}",
                "fromModule": module,
                "toModule": ("Magento" if kind == "magento" else (owner or tgt_id)),
            }
        )

    for pref in filter_module(idx.preferences, module):
        impl = pref.get("type") or ""
        iface_raw = pref.get("for") or ""
        if not impl or not iface_raw:
            continue
        iface_id, iface_kind, iface_owner = resolve_class(iface_raw)
        impl_id, impl_kind, impl_owner = resolve_class(impl)
        add_node(
            iface_id,
            "interface" if iface_owner == module else iface_kind,
            _short(iface_raw),
            module=iface_owner,
            foreign=iface_kind in ("magento", "foreign_aw", "external"),
        )
        add_node(
            impl_id,
            "prefImpl" if (impl_owner == module or impl_owner is None or impl_kind == "magento") else impl_kind,
            _short(impl),
            module=impl_owner or module,
            foreign=impl_kind in ("magento", "foreign_aw", "external"),
        )
        belong(impl_id)
        if iface_owner == module:
            belong(iface_id)
        links.append(
            {
                "source": impl_id,
                "target": iface_id,
                "kind": "PREFERENCE",
                "label": "preference",
                "sample": f"{impl} for {iface_raw}",
                "fromModule": module,
                "toModule": iface_owner or iface_id,
            }
        )

    for o in filter_module(idx.observers, module):
        if o.get("disabled"):
            continue
        event = o.get("event") or ""
        inst = o.get("instance") or ""
        if not event or not inst:
            continue
        add_node(event, "event", event)
        add_node(inst, "observer", _short(inst), module=module, area=o.get("area"))
        belong(inst)
        belong(event)
        links.append(
            {
                "source": inst,
                "target": event,
                "kind": "OBSERVES",
                "label": o.get("name") or "observer",
                "fromModule": module,
                "toModule": module,
            }
        )

    for w in filter_module(idx.webapi, module):
        route_id = f"{w.get('httpMethod')} {w.get('url')}"
        add_node(route_id, "route", route_id)
        belong(route_id)
        svc = w.get("service") or ""
        if svc:
            add_node(svc, "api", _short(svc), module=module)
            belong(svc)
            links.append(
                {
                    "source": svc,
                    "target": route_id,
                    "kind": "HANDLES",
                    "label": w.get("serviceMethod") or "",
                    "fromModule": module,
                    "toModule": module,
                }
            )

    for vt in filter_module(idx.virtual_types, module):
        name = vt.get("name") or ""
        base = vt.get("type") or ""
        if not name:
            continue
        add_node(name, "virtual", _short(name), module=module, area=vt.get("area"))
        belong(name)
        if base:
            base_id, base_kind, base_owner = resolve_class(base)
            add_node(
                base_id,
                base_kind if base_owner != module else "target",
                _short(base),
                module=base_owner,
                foreign=base_kind in ("magento", "foreign_aw", "external"),
            )
            if base_owner == module:
                belong(base_id)
            links.append(
                {
                    "source": name,
                    "target": base_id,
                    "kind": "VIRTUAL_OF",
                    "label": "virtualType",
                    "sample": f"{name} → {base}",
                    "fromModule": module,
                    "toModule": base_owner or base_id,
                }
            )

    for rt in filter_module(idx.routes, module):
        front = rt.get("frontName") or rt.get("id") or ""
        if not front:
            continue
        route_node = f"route:{rt.get('area') or 'global'}/{front}"
        add_node(
            route_node,
            "frontName",
            front,
            module=module,
            area=rt.get("area"),
            router=rt.get("router"),
        )
        belong(route_node)

    # Inbound plugins from other AW modules onto this module
    prefix = f"Aheadworks\\{module}\\"
    inbound = 0
    for p in idx.plugins:
        if p.get("module") == module or p.get("disabled"):
            continue
        tgt = p.get("target") or ""
        if not tgt.startswith(prefix):
            continue
        inbound += 1
        src = p.get("type") or ""
        add_node(
            src,
            "inbound_plugin",
            _short(src),
            module=p.get("module"),
            name=p.get("name"),
        )
        add_node(tgt, "target", _short(tgt), module=module)
        belong(tgt)
        if src:
            belong(src, from_module=p.get("module"))
        links.append(
            {
                "source": src,
                "target": tgt,
                "kind": "WRAPS_INBOUND",
                "label": p.get("name") or "plugin",
                "sample": f"{src} → {tgt}",
                "fromModule": p.get("module"),
                "toModule": module,
            }
        )

    return {
        "scope": "module",
        "module": module,
        "nodes": list(nodes.values()),
        "links": links,
        "stats": {
            "nodes": len(nodes),
            "links": len(links),
            "inboundPlugins": inbound,
            "crossAw": sum(
                1
                for L in links
                if L.get("toModule")
                and L.get("fromModule")
                and L["toModule"] != L["fromModule"]
                and L["toModule"] in modules
                and L["fromModule"] in modules
            ),
        },
    }
