# Quality gates

A task cannot reach the hand-over (Gate B) until every blocking gate passes (or the user explicitly
accepts a documented exception). Gates mirror the module CI so that a green local run predicts a
green pipeline. Agents never trigger CI themselves.

## Source of truth: module CI

Each module repo has `bitbucket-pipelines.yml` that calls `python3 -m aheadworks_test_manager`
(package `aheadworks-deploy-manager` 1.9.0). Its exact commands:

| CI step | Command | Local equivalent (`gates.sh`) |
|---|---|---|
| codesniffer | `vendor/bin/phpcs <module> --severity=9 --standard=Magento2 --extensions=php,phtml` | identical |
| phpstan | `vendor/bin/phpstan analyse <module> --configuration <module>/phpstan.neon --level 0 --autoload-file dev/tests/integration/framework/autoload.php` (after di:compile) | identical (uses the container's `generated/`) |
| unit | `vendor/bin/phpunit --configuration dev/tests/unit/phpunit.xml.dist <module>/Test/Unit` (skipped for Hyvä modules, i.e. `hyva-themes/*` in composer `require`; `suggest` does not count) | harness phpunit config, same test dir |
| install Magento | `module:enable --all`, `setup:upgrade`, `setup:di:compile` | `gates.sh --di` |
| UCT (2.4.9) | Upgrade Compatibility Tool, critical issues fail | not available locally — reviewer checks deprecated/removed core API usage manually |
| mess detector | defined but not wired into pipelines | optional: `vendor/bin/phpmd <module> ansi dev/tests/static/testsuite/Magento/Test/Php/_files/phpmd/ruleset.xml` |

CI matrix: PHP 8.2/2.4.6, 8.3/2.4.7, 8.4/2.4.8, 8.5/2.4.9. Local runtime is PHP 8.5 / Magento 2.4.9 (Mark Shust `phpfpm`),
so code must also stay valid for PHP 8.2 (no 8.3+ only syntax such as typed class constants,
`#[\Override]`, `json_validate()`), and must not rely on 2.4.9-only framework APIs in production code.

## Gate list

| # | Gate | Blocking | How |
|---|---|---|---|
| G0 | Host/container drift for the touched module is understood | yes | `drift.sh <Module>`. `app/code` is a bind mount, so the module is identical unless the mount is missing. `sync.sh` does not copy those files |
| G1 | `php -l` on changed PHP/PHTML | yes | `gates.sh --files` |
| G2 | phpcs Magento2 severity 9 on the module | yes | `gates.sh` |
| G3 | phpcs severity 5 on changed files | no (but new warnings in touched lines must be fixed or justified) | `gates.sh --files` |
| G4 | phpstan level 0 on the module | yes | `gates.sh` |
| G5 | PHPUnit `Test/Unit` of the module | yes | `gates.sh`; pre-existing failures must be listed with proof they exist before the change |
| G6 | `setup:di:compile` | yes when `di.xml`, plugins, constructors, factories/proxies or new classes changed | `gates.sh --di` |
| G7 | `setup:upgrade` succeeds | yes when `db_schema.xml`, patches, `module.xml` changed | see ENVIRONMENT.md |
| G8 | New/changed behaviour covered by unit tests | yes for bug fixes (regression test) unless the user waives it | reviewer |
| G9 | Manual smoke scenario from the plan executed (storefront/admin/CLI) | yes when UI or checkout/order flow changed | test report with steps and outcome |
| G10 | Module docs updated (`docs/<Module>/`) | yes | doc keeper + `check-harness.sh` |
| G11 | Coding rules: `.cursor/rules/aheadworks-code-style.mdc`, `aw-phpdoc.mdc`, `aw-data-persistor-key.mdc`, `aw-resource-main-table.mdc`, `aw-str-api-data-constants.mdc` | yes | code reviewer |

## Baseline rule for pre-existing failures

Before changing code, run `gates.sh <Module> --report docs/tasks/<ID>/05_test_report.md` once and
label that section **Baseline**. A failure present in the baseline and unrelated to the task does
not block the task, but must be listed in the Gate B hand-over summary as "pre-existing".

Known environment artifact: module CI installs one module at a time, so `phpstan-baseline.neon` files ignore
"class not found" for optional AW modules. In this project those modules sit next to each other in `app/code`
(e.g. Nmi, OneStepCheckout), the classes resolve, and phpstan reports
`Ignored error pattern ... was not matched in reported errors`. Such entries are pre-existing environment
failures, not code errors; each module's `TESTING.md` lists its exact count. Any other phpstan error is real.

## Reporting

`gates.sh --report` appends a markdown table to the task's `05_test_report.md`. The developer records the
printed summary table in `impl/task-NN.md`; QA adds commands run, what was synced, smoke steps and results,
and any skipped gate with its reason.

Output is quiet by default: a passing gate prints one line (phpunit with its test count), a failing gate prints
only the problems (phpcs `--report=emacs`, phpstan `--error-format=raw`, phpunit failure details). Pass/fail
semantics are identical to CI; `--verbose` restores the tools' default formats with the last 60 lines per gate.
