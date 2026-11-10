---
name: aw-simple-task
description: Lightweight harness path for a very small bug fix or tweak in one module - no subagents, one artifact, one approval stop. Usage - /aw-simple-task [<Teamwork ID or URL>] <Module> <what to change>
disable-model-invocation: true
---

# /aw-simple-task — small change without the full cycle

You work alone: **no subagents**. Root `AGENTS.md` rules apply (git read-only, no CI, no composer/npm, PHP tooling only via `docs/_harness/tools/`).
Do not read `docs/_harness/WORKFLOW.md`; everything you need is here.

## Eligibility (all must hold, otherwise stop and suggest `/aw-task`)
- one module; expected diff ≲ 30 lines;
- no `db_schema.xml`, data/schema patches, public API (`Api/`, `webapi.xml`) or new `di.xml` entries;
- the place to change is clear without a research phase (no reproduction / RCA needed).

## Steps
1. Read `docs/<Module>/AGENTS.md` (once) and only the code you change. Other module docs only if the change needs them. If the touch point is a plugin/observer/API, call `module_wiring` / `list_*` (magento-wiring MCP) first.
2. Create `docs/tasks/<ID>-<slug>/task.md` (no Teamwork ID ⇒ `noid-<YYYYMMDD>-<slug>/`), in Russian:
   - `## Тикет` — 1–3 lines; `## Где и почему` — file:line and the cause;
   - `## Мини-план` — ≤ 5 lines: files, change, test.
3. **Approval — stop.** Show the mini-plan in chat (≤ 5 lines) and ask: «Ответьте «да» или напишите правки.»
   On «да» write `## Одобрено` with date and the user's words into `task.md`. No code before it.
4. Implement, matching the module code and `.cursor/rules/aheadworks-code-style.mdc` / `aw-*.mdc`.
   Bug fix: add a regression unit test under `Test/Unit/...` unless the change is untestable (text, layout, translation) — say why in `task.md`.
5. `docs/_harness/tools/sync.sh --files <every changed path>`; `bin/magento cache:flush` in the container if config/layout/templates changed;
   `docs/_harness/tools/gates.sh <Module> --files <changed files>` (add `--di` if a constructor changed). Red gates you caused ⇒ fix (max 2 attempts), then stop and report.
6. Self-check instead of a review: PHP 8.2 syntax, Magento 2.4.6–2.4.9 API, escaping in templates, ACL on admin actions, no ObjectManager, no queries in loops, nothing outside the mini-plan.
7. Docs: one line in `docs/<Module>/KNOWN_ISSUES.md` § История значимых багфиксов (`<ID> — суть — ключевые файлы`); other `docs/<Module>/` files only if behaviour, config or ACL changed.
8. If at any point the change breaks the eligibility rules: stop, write why into `task.md`, suggest `/aw-task <ID>` (the analysis in `task.md` can be reused as intake).
9. Append `## Результат` to `task.md` (changed files, tests, gate table) and add a row to `docs/tasks/README.md` § Реестр.
10. **Hand-over** in chat (Russian, ≤ 10 lines): what changed, gate results, files that must not be committed
    (`git -C app/code/Aheadworks/<Module> status --porcelain` vs your files), branch `bugfix/<ID>-<Teamwork-Title-With-Dashes>`,
    commit message `https://ravedigital.teamwork.com/app/tasks/<ID> <Teamwork task title>`. The user does all git operations.
