---
name: aw-cbm-ensure-index
description: >-
  Ensure Codebase Memory (CBM) indexes exist for this Magento harness workspace —
  the two roots app/code/Aheadworks and docs. Use when indexes are missing, after
  harness port/install, before first CBM read, or when the user says ensure CBM
  index, create CBM index, индекс CBM, нет индекса CBM, /aw-cbm-ensure-index.
  Does not force-reindex when both roots already exist (pass --force for that).
---

# /aw-cbm-ensure-index — create CBM indexes if missing

Idempotent. Creates the **two unified** harness indexes only when absent. Never creates per-module indexes.

## Do this

1. Skim `docs/_harness/CODEBASE_MEMORY.md` (two roots only: `app/code/Aheadworks` + `docs`).
2. From Magento `src/` (workspace root), run:

```bash
docs/_harness/tools/cbm-ensure-index.sh
```

3. Report the script outcome to the user in one short line:
   - already present → say both roots OK, do **not** reindex;
   - missing root(s) indexed → which ones were built;
   - CBM binary missing → warning only, continue without blocking;
   - failure → show stderr, fall back to `Read`/`Grep`.

## Force reindex (only if user asks)

```bash
docs/_harness/tools/cbm-ensure-index.sh --force
```

Same effect as `docs/_harness/tools/cbm-index-module.sh`.

## Do not

- Index Magento root, `vendor/`, or a single `Aheadworks/<Module>` path.
- Treat this skill as a substitute for magento-wiring MCP (XML DI still uses `module_wiring` / `list_*`).
- Block harness doc/code work if CBM is unavailable — warn and continue.
