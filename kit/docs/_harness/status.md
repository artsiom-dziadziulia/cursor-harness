# Статус харнесса и документации

Обновлено: 2026-11-03 (Magento Wiring MCP интегрирован в harness). Проверка целостности: `docs/_harness/tools/check-harness.sh` (`--strict` — считать недокументированные модули ошибкой).

## Компоненты харнесса

| Компонент | Путь | Статус |
|---|---|---|
| Корневая инструкция агента | `AGENTS.md` (дублирующее правило `00-harness.mdc` удалено 2026-10-09) | ✅ |
| Процесс «ТЗ → МР» | `docs/_harness/WORKFLOW.md`, `templates/` | ✅ |
| Quality gates (= CI модулей) | `docs/_harness/QUALITY_GATES.md`, `tools/gates.sh` | ✅ прогнаны на всех модулях (Hyvä-детект как в CI — по `require`) |
| Окружение (Mark Shust docker-magento, PHP 8.5 / Magento 2.4.9) | `docs/_harness/ENVIRONMENT.md`, `tools/{env,drift,sync}.sh` | ✅ |
| Codebase Memory (локальный MCP) | `CODEBASE_MEMORY.md`, `tools/cbm-index-module.sh`; **2 индекса**: Aheadworks + docs; бинарник `/media/ssdwork/Sites/codebase-memory-mcp/` | ✅ |
| Magento Wiring MCP | `MAGENTO_WIRING_MCP.md`, `.cursor/mcp.json`, `.cursor/rules/magento-wiring-mcp.mdc`; сервер `/media/ssdwork/Sites/magento-wiring-mcp` | ✅ |
| phpunit под PHP 8.5 / тесты 2.4.9 | `tools/phpunit/*` | ✅ |
| Стандарт документации модулей | `docs/_harness/DOCS_STANDARD.md` | ✅ эталон — `docs/AdvancedReports/` |
| Субагенты | `.cursor/agents/00-harness/aw-*.md` (9 ролей; `aw-qa`, `aw-doc-keeper` — `model: fast`); помощники — `.cursor/agents/10-domain-helpers/` (4), архив — `.cursor/agents-library/` | ✅ |
| Команды (skills) | `.cursor/skills/aw-{task,approve,continue,simple-task,without-harness,document-module}` | ✅ |
| Правила модулей | `.cursor/rules/modules/<module-kebab>.mdc` → ссылка на `docs/<Module>/AGENTS.md` (без `@`-включения) | ✅ (+ `review-reminder.mdc`; на диске часть `docs/<Module>/` отсутствует — `check-harness` видит не полный каталог) |
| Самопроверка | `tools/check-harness.sh` | ✅ |
| Реестр задач | `docs/tasks/README.md` | ✅ (пусто) |

## Документация модулей

Легенда: ✅ готово и проверено · 🟡 в работе · ⏳ не начато. Порядок — волны (сначала базовые модули, от которых зависят остальные).

| Волна | Модуль | Статус | Комментарий |
|---|---|---|---|
| Пилот | AdvancedReports | ✅ | Эталон формата (апрув 2026-10-02); gates после синхронизации полностью зелёные (114 тестов) |
| 1 — базовые | Core | ✅ | Нет `.git`; синхронные HTTP-запросы и запуск Composer при открытии страницы Products |
| 1 | Bup | ✅ | Нет `.git`; включён только в контейнере; плагины на всех админ-формах |
| 1 | Captcha | ✅ | Пересобрано 2026-10-30: 9 файлов + 4 `features/` + USER_GUIDE/DEVELOPER_DOCUMENTATION; `check-harness` OK Captcha. Нет `.git`; enabled в контейнере. Риск: storefront Fail-Safe (default on) пропускает invalid captcha |
| 1 | Csblock | ✅ | Пересобрано 2026-10-27: 9 файлов, `check-harness` OK. Пакет 1.2.1, ветка `release/1.2.2` @ `075da1a`; в инстансе disabled (нет в `config.php`). WC: `NewConditionHtml` type/`rule` allowlist. Риски: OM create, grid join alias `t`, пустые `category_ids` = все категории |
| 1 | FakeDataGenerator | ✅ | Нет `.git`; `execute(): void` → команда всегда завершается `TypeError` |
| 1 | Nmi | ✅ | Нет `.git`; disabled, нет в обоих `config.php`; `debug=1` без маскирования, `verifypeer=false` |
| 2 — подписки | Sarp2 | ✅ | 12 `features/`; незакоммиченный `apiEndpoint` → staging в `etc/di.xml`; токен интеграции уходит в браузер админа (iframe логов); phpstan: 11 unmatched baseline (артефакт окружения) |
| 2 | Sarp2Adyen | ✅ | Рендерер токена в `RendererPool` — несуществующий класс; REST без проверки владельца |
| 2 | Sarp2Stripe | ✅ | Stripe 4.5.0 в стеке при требовании `>=4.6.0`; phpstan FAIL: `parent::hasCustomerSessionFeatures()` (commit 59d4c02) отсутствует в Stripe 4.5.0 стека → на этом стеке риск фатальной ошибки; есть ли метод в 4.6.0 — не проверено |
| 2 | Sarp2Aps | ✅ | Disabled (нет в обоих `config.php`); ссылается на класс/JS, которых нет в APS 2.14.0 → риск при авто-включении |
| 2 | Sarp2BraintreeByPaypal | ✅ | Нет `.git`; `ClientFactory` всегда берёт production-ключи (в стеке sandbox); токены не используются как резервные |
| 2 | Sarp2Reports | ✅ | Cron MRR застрял (флаг 2024-08-02); индекс обновляется только вручную; FK теряются после reindex; ACL-ошибки; instant email из гридов, вероятно, запрещён (регрессия `AdvancedReports/Report/Send`) |
| 2 | Sarp2Hyva | ✅ | Hyvä установлен, магазины на Luma → код не исполняется; `ReplacePlugin` меняет ссылку и на Luma; `Hyva_ThemeFallback` не установлен |
| 2 | Sarp3Server | ✅ | 11 `features/`; блокирует REST/GraphQL (403) и cron стека; `PUT V1/scheduleItem` без проверки владельца; админ-контроллеры без авторизации; секреты в git; phpstan: 2 ошибки (нет пакета `mixpanel/mixpanel-php`) |
| 2 | Sarp3IntegrationGiftcard | ✅ | Админ-контроллер `Edit\GiftCard` без авторизации/ACL (подтверждено); исторические `docs/deployment`, `docs/qa` расходятся с кодом |
| 2 | sarp3-connect | ✅ | Lumen-сервис Stripe Connect OAuth; `APP_KEY` закоммичен в `.env.example` (подпись `state`); тесты не запускались (нет runtime) |
| 2 | PdfTemplates | ✅ | 6 `features/`; массовая печать PDF из гридов → `TypeError` (плагины `getPdf(array)` получают коллекцию); PDF вложений рендерится дважды; unit-тест — заглушка |
| 3 — клиенты/маркетинг | Acr | ✅ | Код восстановления корзины = `sha512(quote_id)` без соли → угадываем (подтверждено); фикс `GenerateManageCode` (40924792) только в `release/2.1.2`; гриды без `aclResource` |
| 3 | Giftcard | ✅ | Нет `.git`; анонимные REST `/V1/carts/:cartId/aw-giftcard*` (в т.ч. `get-customer-codes` — карты по любому email); списание без блокировки/перепроверки баланса; в данных стека 2 карты по 100.00 списаны на 1864.05 и 1204.61; срок действия проверяется только через cron |
| 3 | AdvancedReviews | ✅ | 9 `features/`; 12 security-находок (валидация вложений, гостевой Emailpost, привязка гостевого отзыва к клиенту по email); ACL `::comments` используется, но не объявлен; mview статистики не работает |
| 3 | AdvancedReviewsHyva | ✅ | JSON `Provide`: IDOR по `customer_id`, утечка email, `pageSize=0`; stored XSS через `x-html`; код не исполняется (store на Luma) |
| 3 | Ca | ✅ | Нет `.git`; 14 `features/`; 15 security-находок (гость задаёт статус/группу компании, админ компании правит чужие сущности, AJAX мимо проверки прав, REST без проверки владельца); требует отсутствующий `Aheadworks_UiComponents`; phpstan: 22 unmatched baseline (артефакт) |
| 3 | RewardPoints | ✅ | Нет `.git`; `self`-маршруты REST без проверки владельца; смешение base/store валюты в расчётах; phpstan: 2 unmatched baseline (артефакт) |
| 3 | Raf | ✅ | **SQL-инъекция без аутентификации**: анонимный `POST /V1/awRafFriend/canApplyDiscount` → `ResourceModel/Friend/Order.php:66,70` (email/IP вклеиваются в WHERE; подтверждено по коду); транзакции RP в обход FIFO; в репо незакоммиченная правка `OrderRepositoryPlugin.php` и `.idea/` |
| 4 — поддержка/checkout/доставка | ImprovedSorting | ✅ | 4 `features/`; ветка `feature/40594742-Enable-Grouping` (группировка уже в `origin/release/1.0.0`); cron по умолчанию раз в минуту с синхронным reindex `catalogsearch_fulltext`; layout безусловно подменяет шаблоны списка/тулбара; gates полностью зелёные (83 теста) |
| 4 | OneStepCheckout | ✅ | 9 `features/`; в стеке выключен в конфиге + REST 403 (Sarp3Server) → заказ не оформить ни через OSC, ни через Luma; фикс Stripe 40318283 (`f4d37834`) в `origin/release/2.9.3`, без тега, runtime не подтверждён; глобальные побочные эффекты при выключенном OSC (валидация адресов, сохранение quote на каждый estimate); security: перезапись лога заполнения любой quote анонимно, `composer require` любого пакета из админки (`config_aw_osc`), перечисление подписчиков; gates PASS (97 тестов) |
| 4 | Helpdesk2 | ✅ | 12 `features/`; только в контейнере; входящая почта в стеке не проверяема (0 шлюзов, нет webklex/laminas-mail/google apiclient); phpstan FAIL — 17 ошибок из-за отсутствующего webklex (не артефакт baseline); 17 security-находок: анонимный REST `createNewMessage` в любой тикет (подтверждено), ответ по email без проверки отправителя, regex-фильтр HTML, open redirect, Gmail webhook без аутентификации, публичные вложения, права отделов не применяются к mass actions/REST |
| 4 | Rma | ✅ | Пересобрано 2026-10-23: 9 файлов + 8 `features/`. Пакет 1.10.2, в этом инстансе выключен (нет в `config.php`). ACL срока возврата и path дефолта `ignore` / `is_ignored` расходятся. `check-harness`: OK |
| 4 | ShippingConditions | ✅ | 5 `features/`; DIM-факторы читаются из несуществующего пути `carriers/awstr/volumetric/*` → фактор 0, используется сырой объём (подтверждено); группа клиента на реальном checkout всегда 0 (подтверждено снимком заказа 000006204); класс доставки у дочернего товара configurable игнорируется; зависимости от OSC/Captcha не объявлены |
| 4 | ShippingRules | ✅ | Пересортировка всех тарифов по цене при каждом расчёте даже без правил; возможен `TypeError` при ошибке перевозчика в списке; условия правил проверяются только по первому товару корзины; `ObjectManager` в `ShippingMethodOptions` |
| 4 | ShippingTableRates | ✅ | 4 `features/`; на checkout методы, ограниченные группами клиентов, скрыты от всех (следствие группы 0); класс без подходящего тарифа молча оценивается в 0; цена/кол-во округляются до шага перед сопоставлением диапазонов; Rate Debugger — отдельная копия логики (цены могут отличаться от checkout); импорт без транзакции; ~12 нарушений правила `aw-str-api-data-constants` |
| 5 — отчёты-надстройки | RmaReports | ✅ | ACL в `etc/ acl.xml` (пробел в имени, с 2022, подтверждено) → ресурсы неизвестны, доступ только у полных админов; instant email не работает (namespace гридов ≠ `aw_arep_<key>_grid`); данные обновляются только ручным reindex; в отчёт попадают только RMA в статусе Approved |
| 5 | Helpdesk2Report | ✅ | Глобально подменяет applier `period` AdvancedReports (`etc/di.xml:87`, подтверждено) → сдвиг периода на день в TZ ≠ UTC для всех отчётов; у гридов нет `aclResource` (экспорт/рендер любому админу); SQL из сырого ввода в гриде тегов; с 31fee30 — свой mview-индексатор, обновление заблокировано cron allow-list Sarp3Server |
| Доп. (2026-10-09) | Pquestion | ✅ | 6 `features/`; включён только в контейнере, таблицы пустые; права «Who Can Answer» / гостевые вопросы и голоса проверяются только в UI (`Controller/Question/Answer/Submit.php`, анонимный REST `answer/create`) — суть тикета 36166145; фронт и REST принимают `is_admin`/`status`/`customer_id`; подписки на уведомления меняются для любого email; mview передаёт ID товаров как ID вопросов; `aw_pq_email_queue.object_id` — smallint; phpstan FAIL 30 (не сгенерированы фабрики — модуль не компилировался) |
| Доп. (2026-10-28) | ReviewReminder | ✅ | 9 файлов, `check-harness` OK. Пакет 1.0.12, `master` @ `2a51705`; **enabled** (с 2026-10-28). Риски: глобальная preference на `Magento\Email\Model\Template`; enable через legacy `modules_disable_output`; `OrderPlugin` требует load→save для перехода в complete |
| Доп. (2026-10-29) | EmailTemplates | ✅ | 9 файлов + 2 `features/`, `check-harness` OK. Пакет 1.2.0, `master` @ `8bedd19`; **disabled**. Риски: глобальный `FilterPlugin`, dual MIME attach, `Attachment/Delete` через GET, баг `strpos === null` в `Config::getTrackingParams`, пустой `module.xml` sequence |

Метод для волн 1–5: субагент `aw-module-documenter` на модуль (параллельно внутри волны), затем выборочная проверка
фактов оркестратором и прогон `check-harness.sh`; после волны — обновление статусов в `docs/README.md` и здесь.

## Решения пользователя

| Вопрос | Решение (2026-10-02) |
|---|---|
| Формат пилота `docs/AdvancedReports/` | Одобрен; волны 1–5 в этом формате |
| Зеркальная синхронизация модулей с drift | Выполнена для всех 16 модулей с расхождениями (см. ниже) |
| Несовпадение `app/etc/config.php` хоста и контейнера | Источник истины не выбирается; модульные доки описывают оба состояния |

### Открытые вопросы

1. **`Aheadworks_Sarp3Server` в контейнере.** Пока он включён, в стеке 17 весь REST/GraphQL отвечает 403, а cron выполняет только
   allow-list сервера (индексы по расписанию и cron остальных модулей не работают с 2026-09-28). Для smoke-тестов checkout/API/cron
   его придётся выключать (`module:disable` + `setup:upgrade` — изменение окружения, только с согласия пользователя).
   **Решено 2026-10-05:** пользователь отключил модуль в контейнере (REST 200, cron индексаторов идёт).
2. **Незакоммиченные изменения в репозиториях модулей** (не от харнесса; агенты их не трогают, но они попадут в `git diff` следующей задачи):
   - `Sarp2/etc/di.xml` — `apiEndpoint` переключён на `https://staging.sarp3.aheadworks.com/`;
   - `Raf/Plugin/Model/Order/OrderRepositoryPlugin.php` — стилевой откат без изменения логики; неотслеживаемая папка `Raf/.idea/`;
   - `ImprovedSorting` — неотслеживаемые `docs/` и `Test/Unit/Model/Sorting/SortCodeGeneratorTest.php` (тест проходит в gates).

### Зеркальная синхронизация 2026-10-02

- `sync.sh --module <M> --mirror` для 16 модулей: удалено 36 файлов, загружено 16; после — drift нулевой у всех модулей
  (кроме `sarp3-connect`, который инструменты не обрабатывают).
- Бэкап версий контейнера: `/home/eborisenko/PhpstormProjects/Docker/aw-mirror-backup-20261002/`
  (`container-<Module>.tar`, `drift-<Module>.txt`, `mirror-log.txt`). Там же — неучтённые в git тесты экспорта
  AdvancedReports и удалённые плагины Sarp2.
- Перед удалением проверено, что код хоста не ссылается на удаляемые классы.
- Код `Nmi` и `Sarp2Aps` загружен, но модули не включались и `setup:upgrade` не запускался.
- Из-за изменения `Sarp2/etc/di.xml` выполнены `setup:di:compile` (успешно) и `cache:flush`.

### Состояние `config.php`

- Только в контейнере включены: `Bup`, `Captcha`, `Helpdesk2`, `Helpdesk2Report`, `Sarp3Server`.
- `Nmi`, `Sarp2Aps` отсутствуют в обоих файлах → следующий `setup:upgrade` включит их автоматически
  (у Nmi в БД остались данные прошлой установки: `setup_module` 1.3.3, 7 заказов).

### Модули без `.git`

`Bup`, `Ca`, `Captcha`, `Core`, `FakeDataGenerator`, `Giftcard`, `Nmi`, `RewardPoints`, `Sarp2BraintreeByPaypal` —
у них нет собственного репозитория, поэтому финальный шаг
WORKFLOW (MR) для них невозможен; изменения — только по отдельному согласованию с пользователем.

## Журнал

| Дата | Что сделано |
|---|---|
| 2026-10-02 | Харнесс: WORKFLOW, QUALITY_GATES, ENVIRONMENT, DOCS_STANDARD, шаблоны, субагенты, skills, инструменты (gates/drift/sync/check-harness), phpunit-обвязка |
| 2026-10-02 | Пилот документации AdvancedReports (9 файлов + 8 `features/`), правило `.cursor/rules/modules/advanced-reports.mdc` |
| 2026-10-02 | Апрув формата; зеркальная синхронизация 16 модулей + `setup:di:compile`; baseline AdvancedReports обновлён (всё PASS) |
| 2026-10-02 | `drift.sh`: `LC_ALL=C` (ошибка сортировки в `join`) и разбор путей с пробелами |
| 2026-10-02 | Волна 1: Core, Bup, Captcha, Csblock, FakeDataGenerator, Nmi (доки + правила), выборочная проверка фактов по коду |
| 2026-10-02 | Волна 2: Sarp2, Sarp2Adyen, Sarp2Aps, Sarp2BraintreeByPaypal, Sarp2Stripe, Sarp2Hyva, Sarp2Reports, Sarp3Server, Sarp3IntegrationGiftcard, sarp3-connect, PdfTemplates; правки docs/Sarp2 по перекрёстным находкам; ENVIRONMENT: Hyvä/платёжные модули, побочные эффекты Sarp3Server; QUALITY_GATES: артефакт phpstan baseline |
| 2026-10-02 | Волна 3: Acr, AdvancedReviews, AdvancedReviewsHyva, Giftcard, Ca, RewardPoints, Raf; перекрёстные правки docs/Captcha, Csblock, Sarp2, Sarp3IntegrationGiftcard, Ca, AdvancedReviews, каталога |
| 2026-10-02 | `gates.sh`: Hyvä-модуль определяется только по `hyva-themes/*` в composer `require` (как CI), а не по строке в любом месте файла — раньше phpunit ложно пропускался у ImprovedSorting (`suggest`) |
| 2026-10-02 | Волна 4: ImprovedSorting (доки + правило) |
| 2026-10-02 | Волна 4: OneStepCheckout (доки + правило); перекрёстные правки docs/Ca, Nmi, Raf, Giftcard, Captcha (статус OSC в стеке, ссылки вместо «docs нет») |
| 2026-10-02 | Волна 4: Helpdesk2 (доки + правило); правки docs/Helpdesk2 по находкам Helpdesk2Report (FirstDate не вызывается, триггеры mview всегда есть), docs/Ca (механизм тикетов компании), каталога (зависимости) |
| 2026-10-02 | Волна 4: ShippingConditions, ShippingRules, ShippingTableRates (доки + правила); каталог: OSC у ShippingTableRates — только `<sequence>`, реальная интеграция OSC — в ShippingConditions; docs/Captcha: зависимость ShippingConditions → Captcha только в composer `suggest`. Итог: `check-harness.sh --strict` — 34/34, 0 битых ссылок |
| 2026-10-02 | Волна 4: Rma (доки + правило); docs/RmaReports: закрыт вопрос про `item_id` у configurable (пишется дочерняя simple-позиция) |
| 2026-10-02 | Волна 5: RmaReports, Helpdesk2Report (доки + правила); правки docs/AdvancedReports: email-провайдеры есть только у Sarp2Reports, глобальная подмена фильтра `period` модулем Helpdesk2Report |
| 2026-10-09 | Оптимизация расхода токенов: `status.md` — дашборд ≤ 60 строк + `journal.md`; план/журнал реализации/ревью кода — по файлу на задачу (`plan/`, `impl/`, `review/`); внутренние логи на английском; ответы ролей ≤ 10 строк; повторное ревью — только по замечаниям, ревьюер не перезапускает gates; группировка мелких задач (size S); партии по 5 задач через `/aw-continue`; ревью анализа (S1R) — только для feature; fast lane до ≈ 80 строк; `gates.sh` тихий по умолчанию (`--verbose`); `aw-qa`/`aw-doc-keeper` на `model: fast`; правила модулей без `@`-включения; удалены `00-harness.mdc`, шаг S8 / `aw-mr-preparer` / `06_mr.md` (сводка Gate B в чате); 26 из 30 специалистов `magento-*` перенесены в `.cursor/agents-library/` |
| 2026-10-09 | Pquestion (новый модуль): доки (9 файлов + 6 `features/`) и правило `pquestion.mdc`; выборочная проверка 5 фактов по коду (таблица, плагин, дефолт конфига, cron, роут) — совпадают; строка в каталоге `docs/README.md` |
| 2026-10-23 | Rma пересобран с диска (каталога не было): 9 файлов + 8 `features/`, правило `rma.mdc` уже было. Пять фактов сверены с кодом. Каталог: версия 1.10.2, модуль disabled |
| 2026-10-28 | ReviewReminder (новый в каталоге): доки (9 файлов) и правило `review-reminder.mdc`; 5 фактов сверены с кодом (таблица, плагин, дефолт, cron, роут); строка в `docs/README.md` |
| 2026-10-28 | ReviewReminder: пользователь включил модуль; runtime в доках → enabled; подтверждены таблицы + sample rule `FillDefaultRule` |
| 2026-10-30 | Codebase Memory: `CODEBASE_MEMORY.md`, `tools/cbm-index-module.sh`; чтение кода/docs через MCP при наличии индекса; `/aw-document-module` и S7 reindex после записи docs; правки `AGENTS.md`, WORKFLOW, ENVIRONMENT, DOCS_STANDARD, `aw-document-module`, `aw-module-documenter`, `aw-doc-keeper` |
| 2026-10-30 | Captcha: `/aw-document-module` (9+4 features, rule OK); spot-check 5 фактов через CBM; security-audit через MCP; unified CBM reindex |
| 2026-11-03 | Magento Wiring MCP: сервер + tools; протокол `MAGENTO_WIRING_MCP.md`; rule `magento-wiring-mcp.mdc`; роли S1/S2/S2R/S4/S5/S7 + documenter + issue-debugger; DOCS_STANDARD / WORKFLOW / AGENTS / aw-document-module |
