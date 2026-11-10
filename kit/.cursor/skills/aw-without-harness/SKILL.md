---
name: aw-without-harness
description: Do a task directly, outside the harness process - no plan approval, no docs/tasks artifacts, no harness subagents, no gates. Reads docs/<Module>/ and docs/; writes module docs only if the user says yes after the end-of-task ask. Uses harness code standards and CBM + magento-wiring MCP. Usage - /aw-without-harness <Module> <what to do>
disable-model-invocation: true
---

# /aw-without-harness — direct work, process off / tooling on

## Off (do not use)
- `docs/_harness/WORKFLOW.md`, Gate A, plan approval
- Anything under `docs/tasks/`
- Harness role subagents (`aw-analyst`, `aw-developer`, …)
- Quality gates / `gates.sh` / phpcs·phpstan·phpunit as a required step
- Automatic module doc writes (`docs/<Module>/`, S7) — **unless** the user explicitly asks after the end-of-task question

Do **not** read WORKFLOW.md for this command.

## On (same as normal harness)

### Code standards
Follow harness coding rules (read only what the change needs):
- `.cursor/rules/aheadworks-code-style.mdc`
- `.cursor/rules/aw-phpdoc.mdc`
- `.cursor/rules/aw-data-persistor-key.mdc`
- `.cursor/rules/aw-resource-main-table.mdc`
- `.cursor/rules/aw-str-api-data-constants.mdc`
- PHP 8.2–8.5 / Magento 2.4.6–2.4.9; match surrounding module code

### Docs (required before coding)
Always read project docs for the target module — process artifacts stay off, **module/harness docs stay on**:

1. `docs/<Module>/AGENTS.md` (once per chat / once per module in the request).
2. Other files under `docs/<Module>/` as needed for the change (`ARCHITECTURE`, `DATABASE`, `CONFIGURATION`, `INTEGRATIONS`, `FRONTEND`, `KNOWN_ISSUES`, `features/…`) — prefer CBM on the **docs** project (`search_code` / `get_code_snippet` / `get_file_outline` scoped to `docs/<Module>/…`); do not dump every file.
3. Shared `docs/` when relevant: `docs/README.md` (catalog / deps), `docs/_harness/ENVIRONMENT.md`, `CODEBASE_MEMORY.md`, `MAGENTO_WIRING_MCP.md` — only the sections you need. Still **skip** `WORKFLOW.md` and `docs/tasks/`.
4. If `docs/<Module>/` is missing or empty → note that in the reply and continue from code + MCP wiring; do not invent docs.
5. **Do not write or update** `docs/<Module>/` (or other `docs/`) during the change — only after the user confirms at the end (see Steps).

### MCP read path (required when available)
Same protocol as `docs/_harness/CODEBASE_MEMORY.md` + `MAGENTO_WIRING_MCP.md`:

1. If CBM indexes for this workspace may be missing → `docs/_harness/tools/cbm-ensure-index.sh` (or skill `/aw-cbm-ensure-index`).
2. **Code:** CBM first — `list_projects`, then `search_graph` / `search_code` / `get_code_snippet` / `get_file_outline` / `trace_path` / `check_index_coverage`, scoped to `<Module>/`.
3. **Docs:** same CBM tools on the **docs** project, scoped to `docs/<Module>/` and other `docs/…` paths from the Docs section above.
4. **Magento XML wiring** (`di.xml` / `events.xml` / `webapi.xml` / `routes.xml`): **magento-wiring** MCP — `module_wiring` / `list_plugins` / `list_preferences` / `list_observers` / `list_webapi` / `list_routes`. Do not claim wiring from CBM alone.
5. Fall back to `Read` / `Grep` on coverage gaps, stale index, or if MCP is down. Use disk `Read` for the files you are about to edit.

### Environment safety
- Git read-only: never add/commit/push/checkout/stash/reset/restore/merge/rebase.
- No CI, no `composer`/`npm` changes, no destructive DB actions without asking.
- Never run PHP tooling on the host; edit on the host bind mount; `sync.sh` skips `app/code`. Run `bin/magento cache:flush` in `m249ee2-phpfpm-1` when config/layout/templates changed (`setup:di:compile` / `setup:upgrade` only if needed).
- Edit only what the request needs. Never add unrelated files inside the module tree.

## Steps
1. Ensure CBM roots if needed.
2. **Read docs first:** `docs/<Module>/AGENTS.md` + needed `docs/<Module>/*` and relevant `docs/` (via CBM docs project when indexed).
3. Explore code via CBM + magento-wiring (not a raw dump of the whole module).
4. Apply harness code standards; make the change right away — no plan, no confirmation stop. Ask only if ambiguity changes the result.
5. Sync only if something outside the bind mount needs it; flush cache in the container when required.
6. Reply in Russian, ≤ 10 lines: what changed (files), which docs were read, MCP used or fallback, what was synced/run, what was not checked, and whether a regression test or `/aw-task` follow-up is worth it.
7. **Always end with a docs ask** (Russian, one short question), e.g. «Нужно ли обновить документацию модуля (`docs/<Module>/`) под это изменение?»  
   - **No / skip / silence** → do not touch docs.  
   - **Yes** → update only the affected `docs/<Module>/` files to match the change (follow `docs/_harness/DOCS_STANDARD.md` lightly; no full re-document unless asked). Then run `docs/_harness/tools/cbm-index-module.sh` if docs were written.
