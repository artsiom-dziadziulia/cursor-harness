# Codebase Memory (CBM) — harness integration

Local [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) knowledge graph for Aheadworks
modules and their `docs/<Module>/`. **Files on disk remain the source of truth** (git, `check-harness`,
humans). CBM is the **preferred read path** for agents when an index exists, so exploration costs fewer tokens.

## Install (once per machine)

| Item | Value on this workstation |
|---|---|
| Binary | `/media/ssdwork/Sites/codebase-memory-mcp/codebase-memory-mcp` |
| User MCP config | `~/.cursor/mcp.json` → server `codebase-memory-mcp` (applies to **every** Cursor workspace) |
| Cache / indexes | `~/.cache/codebase-memory-mcp/` (per indexed root path) |
| Lens UI | `http://127.0.0.1:9749` (`codebase-memory-mcp daemon start --open`) |

Override the binary with `CBM_BIN` if the path differs. Do **not** put the absolute CBM path into each
project’s `.cursor/mcp.json` when copying the harness to another Mark Shust tree under `/media/ssdwork/Sites/` —
keep MCP registration user-global so new Magento roots pick it up automatically.

After copying harness / skills / rules into a new Magento `src/`, CBM is already available; only **indexes**
must be built for that tree.

## What to index (exactly two projects)

Always maintain **only these two** roots (mode `full`). Do **not** create per-module indexes.

1. Code: `app/code/Aheadworks` — all Aheadworks modules
2. Docs: `docs` — harness, module docs, tasks

```bash
docs/_harness/tools/cbm-index-module.sh
# optional Module arg is ignored; kept for harness call-sites
# CBM_BIN=/path/to/binary docs/_harness/tools/cbm-index-module.sh
```

Equivalent CLI:

```bash
CBM="${CBM_BIN:-/media/ssdwork/Sites/codebase-memory-mcp/codebase-memory-mcp}"
"$CBM" cli index_repository --repo-path="$(pwd)/app/code/Aheadworks" --mode=full
"$CBM" cli index_repository --repo-path="$(pwd)/docs" --mode=full
```

Expected `list_projects` names (path-derived):

- `…-app-code-Aheadworks`
- `…-docs`

If a narrower project appears (e.g. `…-EmailTemplates`), delete it with `delete_project` and reindex the two roots above.

Do **not** index the whole Magento root, `vendor/`, or unrelated `app/code/*`.

## When to (re)index

| Event | Action |
|---|---|
| Indexes missing / harness port / first CBM use | `/aw-cbm-ensure-index` → `tools/cbm-ensure-index.sh` (indexes **only if absent**) |
| `/aw-document-module` finished | `cbm-index-module.sh` (both roots) |
| S7 `aw-doc-keeper` updated docs | `cbm-index-module.sh` (both roots) |
| Large code change under Aheadworks | Reindex at least the code root (or both via the script) |
| Force rebuild of both roots | `cbm-ensure-index.sh --force` or `cbm-index-module.sh` |

If the binary or MCP server is missing, log a warning and continue — never block doc writes on CBM.

## Read protocol (agents)

**Before** analysing or documenting a module:

1. `list_projects`. Use the **Aheadworks** project for code and the **docs** project for documentation (match `root_path` ending in `app/code/Aheadworks` and `docs`).
2. If either is missing → run `docs/_harness/tools/cbm-ensure-index.sh` (or skill `/aw-cbm-ensure-index`); until ready, fall back to `Read` / `Grep`.
3. When both exist → treat CBM as the **default read channel**:
   - Docs: `search_code` / `search_graph` / `get_code_snippet` / `get_file_outline` on the **docs** project (filter by `docs/<Module>/…` paths).
   - Code: same tools on the **Aheadworks** project (filter by `<Module>/…` paths).
4. Call `check_index_coverage` for paths you rely on. On partial / skipped / stale / missing coverage → read those files from disk, then prefer reindex.
5. Use disk `Read` for exact edits you are about to write, and when CBM is down.

**Do not** dump entire `docs/<Module>/*.md` into context when the docs project is indexed and fresh — query the graph first, then pull snippets.

Magento DI (plugins, preferences, observers, layout XML) may be incomplete in the call graph; confirm behaviour in XML on disk when the claim is Magento-wiring specific.
For Aheadworks `etc/*.xml` wiring use the **magento-wiring** MCP (`module_wiring`, `list_plugins`, …) — see [`MAGENTO_WIRING_MCP.md`](MAGENTO_WIRING_MCP.md).

## CLI cheat sheet

```bash
CBM="${CBM_BIN:-/media/ssdwork/Sites/codebase-memory-mcp/codebase-memory-mcp}"
"$CBM" cli list_projects --detail=stats
docs/_harness/tools/cbm-ensure-index.sh          # no-op if both roots exist
docs/_harness/tools/cbm-index-module.sh          # always full reindex both
"$CBM" cli search_graph --project=<…-app-code-Aheadworks> --query=MigrateFromMagetrend
"$CBM" cli search_code --project=<…-docs> --pattern=Magetrend
"$CBM" daemon status
```

Team sharing of one live MCP process is not supported; optional shared baseline is `.codebase-memory/graph.db.zst`
(`persistence: true`) — see upstream README. This harness keeps indexes local per developer machine.
