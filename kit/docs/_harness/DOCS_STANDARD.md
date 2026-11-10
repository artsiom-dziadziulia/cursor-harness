# Module documentation standard

Every directory in `app/code/Aheadworks/` has a documentation folder `docs/<DirectoryName>/`
(same name and case as the module directory). Module docs are written in **Russian**; code
identifiers, paths, config paths, class names stay as in code. `AGENTS.md` of a module is written in
**English** (it is an agent instruction).

Docs describe the code **as it is on the host** at the time of writing. Every non-obvious claim
links to a file (`Model/Indexer/Statistics.php`), and where useful to a method (`::execute()`).
No speculation: if behaviour is unclear, write "не подтверждено" and what would confirm it.

## Required files

| File | Content | Required sections |
|---|---|---|
| `README.md` | Entry point, human overview | Назначение · Версия и пакет (`composer.json` name/version, `module.xml` setup_version if any) · Git (repo path, current branch at doc time) · Зависимости (module.xml sequence, composer require, soft deps) · Кто зависит от модуля · Карта документации · Глоссарий |
| `AGENTS.md` | Agent instruction for this module (EN) | Scope · Read-first list · Where to find what (table: concern → path) · Invariants / must-not-break · Common pitfalls · Extension points · How to verify a change (gates + smoke) · Related modules |
| `ARCHITECTURE.md` | Structure and flows | Структура каталогов · Сервис-контракты (`Api/`, `Api/Data/`) и реализации (DI preferences) · Ключевые классы по слоям · Плагины на ядро/другие модули (target → plugin → purpose) · Observers (event → observer → purpose) · Основные потоки (mermaid sequence/flowchart) |
| `DATABASE.md` | Persistence | Таблицы из `db_schema.xml` (назначение, ключевые колонки, PK/FK/индексы) · Связи (mermaid erDiagram) · EAV-атрибуты / extension attributes / поля в core-таблицах · Data/Schema patches (name → what it does) · Индексаторы и mview (id, таблицы, подписки) |
| `CONFIGURATION.md` | Admin config and access | Настройки `system.xml` (path, тип, default из `config.xml`, scope, смысл) · ACL ресурсы · Меню админки · Email-шаблоны · Переводы (`i18n`) |
| `INTEGRATIONS.md` | Entry points other than UI | REST (`webapi.xml`: route, method, service, ACL) · GraphQL (`schema.graphqls`) · Cron (`crontab.xml`: job, schedule/config path, class) · Очереди (topics, consumers) · CLI (`di.xml` commands) · Dispatched events (`eventManager->dispatch`) · Интеграции с другими AW-модулями и сторонними (payments, Hyvä, Stripe, Adyen…) |
| `FRONTEND.md` | UI | Admin: routes/controllers, UI-компоненты (listing/form), layout handles · Storefront: routes, layout handles, blocks/view models, templates, JS-компоненты (RequireJS/Knockout), стили · Hyvä-совместимость · Email templates rendering |
| `TESTING.md` | How to verify | Существующие тесты (unit dirs, что покрыто) · Как запустить (`gates.sh <Module>`) · Результат последнего прогона и известные падения · Пробелы покрытия · Ручные smoke-сценарии (шаги в стеке 17) · Тестовые данные |
| `KNOWN_ISSUES.md` | Risk map | Хрупкие места и почему · История значимых багфиксов (из `git log`: ID, суть, файлы) · Технический долг · Расхождения host/container на момент документирования |

Sections that do not apply are kept with the text "Не применимо — <reason>" so absence is explicit.

## Large modules

For modules with distinct functional areas (e.g. Sarp2, Helpdesk2, Sarp3Server, Ca, RewardPoints, Rma,
AdvancedReports) add `docs/<Module>/features/<area>.md` per area (purpose, flow, classes, tables,
config, pitfalls) and link them from `README.md` and `AGENTS.md`. Existing in-module docs
(`app/code/Aheadworks/<Module>/docs/*`, `README.md`) are linked, not copied.

## Agent rule per module

Each documented module has `.cursor/rules/modules/<module-kebab>.mdc` (`AdvancedReports` → `advanced-reports.mdc`)
with `globs: app/code/Aheadworks/<Module>/**`, `alwaysApply: false` and a pointer to `docs/<Module>/AGENTS.md`
(plain path, no `@` include): whenever an agent touches the module code it is told to read the module instruction once,
and roles that already read it do not get a second copy.

## Validation

`docs/_harness/tools/check-harness.sh` checks: required files present, module rule present and correct, freshness
header, relative links and `#anchors` resolve (GitHub-style slugs), referenced `.cursor/rules/*.mdc` exist.
A module counts as documented only when it is `OK` there.

## Freshness

`README.md` header contains: `Актуально на: <date>, ветка <branch>, commit <short sha>` (from
`git -C app/code/Aheadworks/<Module> log -1 --format=%h`). The doc keeper updates the header and
affected sections after every task (`WORKFLOW.md` S7).

## Codebase Memory index

After creating or refreshing `docs/<Module>/` (and after S7 doc updates), refresh the **two unified**
Codebase Memory roots (all Aheadworks code + all docs) — never a per-module index:

```bash
docs/_harness/tools/cbm-index-module.sh
```

Disk files remain authoritative. Read/query protocol: `docs/_harness/CODEBASE_MEMORY.md`.

## Magento wiring MCP

Before hand-reading all `etc/di.xml` / `events.xml` / `webapi.xml` / `routes.xml`, call **magento-wiring**
(`module_wiring` + `list_*` — see `MAGENTO_WIRING_MCP.md`) and use that inventory for ARCHITECTURE /
INTEGRATIONS tables. Fall back to raw XML only if the MCP is down. PHP behaviour still via CBM/disk.

## Discovery checklist (for the documenter)

Read in this order; every item must be reflected in some file above:
1. **magento-wiring** inventory for the module (`module_wiring`, plugins, preferences, observers, webapi, routes).
2. Then: `registration.php`, `composer.json`, `etc/module.xml`, remaining `etc/*` not covered above
   (`db_schema.xml`, `Setup/Patch/**`, `config.xml`, `system.xml`, `acl.xml`, `menu.xml`, `schema.graphqls`,
   `crontab.xml`, `cron_groups.xml`, `indexer.xml`, `mview.xml`, `communication.xml`, `queue_*.xml`,
   `email_templates.xml`, `extension_attributes.xml`, `catalog_attributes.xml`, `sales.xml`, `fieldset.xml`,
   `pdf.xml`, `payment.xml`), `view/*/layout`, `view/*/ui_component`, `view/*/requirejs-config.js`,
   `view/*/web/js`, `Api/**`, `Console/**`, `Cron/**`, `Observer/**`, `Plugin/**`, `Test/**`, `i18n/*`,
   in-module docs, `git log -30` of the module repo.
