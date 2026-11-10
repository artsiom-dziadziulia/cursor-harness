---
name: aw-document-module
description: Create or fully refresh docs/<Module>/ for one or more directories in app/code/Aheadworks following docs/_harness/DOCS_STANDARD.md, and wire the module rule. Usage - /aw-document-module <Module> [<Module> ...]
disable-model-invocation: true
---

# /aw-document-module — (re)generate module documentation

1. Read `docs/_harness/DOCS_STANDARD.md` and the reference set `docs/AdvancedReports/`. Also skim `docs/_harness/CODEBASE_MEMORY.md` and `docs/_harness/MAGENTO_WIRING_MCP.md`.
2. For each module name (directory name under `app/code/Aheadworks/`), delegate to subagent `aw-module-documenter`
   (several modules may run in parallel). Pass: module name, path, "follow DOCS_STANDARD.md, reference docs/AdvancedReports/; prefer CBM for PHP/docs; required module_wiring + list_* for plugins/observers/webapi/routes".
3. When a documenter returns, spot-check 5 facts against the code (a table, a plugin target, a config default, a cron schedule, a route). Plugin/observer/API/route facts: verify via **magento-wiring** (`list_plugins` / …). PHP behaviour: CBM `get_code_snippet` / `search_code` when indexed; otherwise Read. Fix or send back on mismatch.
4. Ensure the module rule exists: `.cursor/rules/modules/<module-kebab>.mdc` with
   `globs: app/code/Aheadworks/<Module>/**`, `alwaysApply: false`, body pointing to `docs/<Module>/AGENTS.md` (plain path, no `@` include) and the README.
5. Add/refresh the module row in `docs/README.md`.
6. Run `docs/_harness/tools/check-harness.sh`; update `docs/_harness/status.md`.
7. **Reindex Codebase Memory** (exactly two unified roots — all Aheadworks code + all docs):
   `docs/_harness/tools/cbm-index-module.sh`
   Do not create per-module indexes. If the binary is missing, warn and continue.
8. Report findings (bugs, risky areas, drift) to the user; mention CBM index result.

Docs only — never edit code, never use git write commands. Disk docs remain the source of truth; CBM is the preferred agent read path after step 7.
