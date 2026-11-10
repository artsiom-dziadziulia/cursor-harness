# Старт для нового разработчика — aw-harness + Cursor

Пошаговая инструкция: с нуля на своей машине поднять Aheadworks Cursor harness в любом Magento 2 проекте.

---

## Что вы получите

- Правила агентов (`AGENTS.md`, Gate A, роли)
- Skills: `/aw-task`, `/aw-approve`, `/aw-document-module`, …
- Инструменты: `docs/_harness/tools/gates.sh`, `drift.sh`, …
- MCP: **magento-wiring** (XML-схема модулей) и **codebase-memory** (граф кода)
- Документацию процесса в `docs/_harness/`

---

## Шаг 0. Что нужно заранее

1. Установлен **Cursor**.
2. Есть рабочий **Magento 2** проект на диске (любая раскладка: Mark Shust `…/src`, pystacker, host PHP, …).
3. Доступ к комплекту **aw-harness** — папка с `install.sh`, `bootstrap-user-skills.sh`, `kit/`, `mcp/`.  
   Как получить: клон/копия с общей шары, от коллеги, с SoT-машины.  
   Дальше в тексте путь к комплекту обозначаем как `$AW_HARNESS`  
   (пример: `/media/ssdwork/Sites/aw-harness` или `~/aw-harness`).

Проверка комплекта:

```bash
ls "$AW_HARNESS/install.sh" "$AW_HARNESS/bootstrap-user-skills.sh" "$AW_HARNESS/scripts/harness-install" "$AW_HARNESS/kit" "$AW_HARNESS/mcp"
```

---

## Шаг 1. Один раз на машине — user-skills + PATH

В **пустом** Magento-проекте скилла `/aw-harness-init` ещё нет. Его ставят в профиль Cursor:

```bash
"$AW_HARNESS/bootstrap-user-skills.sh"
```

Скрипт:

- копирует в `~/.cursor/skills/`: `aw-harness-init`, `aw-harness-pack`
- пишет путь к kit в `KIT_ROOT.txt`
- ставит symlink’и в `~/.local/bin/`: `harness-install`, `harness-pack`

Если `~/.local/bin` не в `PATH` — добавьте `export PATH="$HOME/.local/bin:$PATH"` в shell-профиль.

**Перезапустите Cursor** (или Reload Window), чтобы подхватились skills.

Проверка: в любом чате Cursor skills должны видеть `/aw-harness-init`; в терминале — `command -v harness-install`.

> Без bootstrap можно обойтись: `"$AW_HARNESS/install.sh" --target …`. Skill / `harness-install` удобнее.

---

## Шаг 2. Открыть Magento-проект в Cursor

`File → Open Folder` → корень, с которым будете работать.

Важно: harness ставится в **Magento root** — каталог, где есть `app/` (и обычно `bin/magento`).

| Стек | Что открывать / куда ставить |
|---|---|
| Mark Shust | Часто открывают `…/project` или `…/project/src`. Target для install = папка с `app/` (обычно `src`). |
| Pystacker / compose | Папка с `app/` внутри стека. |
| Host PHP | Корень Magento на диске. |

Запомните абсолютный путь, например `/home/you/work/my-m2/src`.

---

## Шаг 3. Установить harness в проект

### Вариант A — через Cursor (предпочтительно)

В Agent-чате проекта:

```text
/aw-harness-init
```

или: «разверни harness», «init harness».

Агент (или вы в терминале) задаст вопросы. Отвечайте по факту вашего стека.

### Вариант B — только терминал

```bash
harness-install --target /absolute/path/to/magento-root
# или без PATH-wrapper:
"$AW_HARNESS/install.sh" --target /absolute/path/to/magento-root
```

Интерактивный режим (TTY) сам спросит то же самое.

---

## Шаг 4. Ответы на вопросы установщика

### 4.1 Magento root

Папка с `app/`. Пример: `/home/you/work/my-m2/src`.

### 4.2 Code path (модули Aheadworks)

Обычно `app/code/Aheadworks`.  
Если модули в другом namespace / `vendor` — укажите относительный путь от Magento root.

### 4.3 Как крутится PHP

| Выбор | Когда |
|---|---|
| **Mark Shust** | Есть `bin/start`, контейнер `*-phpfpm-1` |
| **Pystacker / compose** | `docker compose`, свой PHP-сервис |
| **Host PHP** | PHP и `vendor/` на хосте, без контейнера |
| **Other docker** | Контейнер есть, имя задаёте вручную |

Для docker дополнительно:

- **Compose / stack directory** — где `bin/start` или `docker-compose.yml` (у Mark Shust часто *родитель* `src`)
- **PHP container name** — смотрите `docker ps` (пример: `mym2-phpfpm-1`)
- **Magento path inside container** — чаще `/var/www/html`

### 4.4 MCP (серверы для Cursor) — **вне** Magento

Бинарники MCP **не** кладутся в дерево Magento по умолчанию. На первой установке укажите отдельный каталог (часто домашний):

| Режим | Смысл |
|---|---|
| **shared** (первая установка) | Спросить путь и поставить туда wiring + CBM. Дефолт: `~/.aw-harness/mcp`. Все следующие Magento-проекты будут **reuse** этот путь. |
| **reuse** | MCP уже есть на машине (`~/.aw-harness/mcp`, соседний проект, …) — только прописать в `.cursor/mcp.json`. |
| **project** | `<magento>/.harness/mcp` — опционально, не рекомендуется (дубликаты). |

Пример пути: `/home/you/.aw-harness/mcp` → внутри появятся `magento-wiring-mcp/` и `codebase-memory-mcp/`.  
Путь **нельзя** указывать внутрь Magento root.

### 4.5 Overwrite / force

На **первой** установке — нет.  
`--force` / «перезаписать» — только если намеренно обновляете harness с kit.

Повторный запуск install **без force** идемпотентен: уже лежащие agents/skills/`env.local`/venv/user CBM **пропускаются**.

---

## Шаг 5. Что должно появиться после install

В Magento root:

```text
AGENTS.md
.cursor/agents/00-harness/…
.cursor/skills/aw-task/…          # и остальные skills
.cursor/mcp.json                  # magento-wiring → ваш проект
docs/_harness/WORKFLOW.md
docs/_harness/tools/env.local.sh  # runtime этой машины
docs/_harness/status.md           # штамп установки
```

MCP (shared, по умолчанию) лежит **не** в проекте, например:

```text
~/.aw-harness/mcp/magento-wiring-mcp/
~/.aw-harness/mcp/codebase-memory-mcp/
```

В Magento только `.cursor/mcp.json` указывает на эти бинарники + `MAGENTO_ROOT` этого проекта.  
Режим `project` (локальный `.harness/mcp`) — исключение.

---

## Шаг 6. Подключить MCP в Cursor

### 6.1 Project MCP (wiring)

Файл `.cursor/mcp.json` уже написан install’ом.  
В Cursor: **Settings → MCP** (или Command Palette → reload MCP) → убедитесь, что **magento-wiring** зелёный / без ошибки.

Если ругается на бинарник — проверьте путь `command` в `.cursor/mcp.json` и что venv создан:

```bash
ls "$(jq -r '.mcpServers["magento-wiring"].command' .cursor/mcp.json)"
```

При необходимости без `--skip-venv` перезапустите install или создайте venv вручную в каталоге wiring MCP.

### 6.2 User MCP (Codebase Memory)

CBM обычно один на пользователя. Install:

- пишет сниппет `.cursor/mcp.user-codebase-memory.snippet.json`
- **создаёт** `~/.cursor/mcp.json`, если файла нет
- **вмерживает** `codebase-memory-mcp` в существующий `~/.cursor/mcp.json`, если ключа ещё нет (остальные MCP не трогает)

Reload MCP после установки.

---

## Шаг 7. Индексы Codebase Memory

Ровно **два** индекса на проект (правило harness):

1. Каталог модулей — например `app/code/Aheadworks` (абсолютный путь к нему).
2. `docs` проекта (абсолютный путь).

Install по возможности сам вызывает `docs/_harness/tools/cbm-ensure-index.sh`.  
Если пропустил / упал: `/aw-cbm-ensure-index` или вручную тот же скрипт.  
Позже для одного модуля: `docs/_harness/tools/cbm-index-module.sh <Module>`.

---

## Шаг 8. Проверка, что всё живое

1. В чате: «какие skills harness есть?» / попробуйте увидеть `/aw-task`.
2. Wiring: спросите про plugins модуля (если MCP поднялся).
3. Gates (нужен запущенный PHP runtime из `env.local.sh`):

```bash
docs/_harness/tools/gates.sh SomeModule --no-unit
```

Если контейнер не запущен — старт по подсказке из `docs/_harness/ENVIRONMENT.md` / `AW_STACK_HINT` в `env.local.sh`. **Не** поднимайте Docker без просьбы пользователя в agent-режиме; сами — можете.

---

## Шаг 9. Как работать дальше

| Задача | Команда / действие |
|---|---|
| Баг / фича по процессу | `/aw-task` |
| Мелкое одномодульное | `/aw-simple-task` |
| Без артефактов harness | `/aw-without-harness` |
| Документация модуля | `/aw-document-module` |
| Обновить kit с SoT | `/aw-harness-pack` или `harness-pack` (maintainers) |
| CBM indexes | `/aw-cbm-ensure-index` |

Читайте `AGENTS.md` и `docs/_harness/WORKFLOW.md` в своём проекте.

---

## Частые сценарии

### Второй Magento рядом с первым

Первый проект уже поставил MCP в `~/.aw-harness/mcp` → во втором `/aw-harness-init` выберите **reuse** (часто предложит сам).  
В проекте появится только harness + `mcp.json`, без второй копии MCP.

### Повторный init в том же проекте

Снова `install.sh` / `/aw-harness-init` **без force** — почти всё `skip`, поправится только то, чего не хватает.  
Полное обновление с kit — с `--force` (и согласием).

### Скилл есть в user, kit переехал

```bash
AW_HARNESS_KIT=/новый/путь/aw-harness /новый/путь/aw-harness/bootstrap-user-skills.sh
```

---

## Чеклист на одну страницу

- [ ] Есть комплект `$AW_HARNESS`
- [ ] Один раз: `bootstrap-user-skills.sh` → restart Cursor
- [ ] Открыт Magento root (`app/`) в Cursor
- [ ] `/aw-harness-init` или `harness-install --target …`
- [ ] Отвечены root / code path / stack / **MCP home вне Magento** (дефолт `~/.aw-harness/mcp`)
- [ ] Reload MCP; wiring зелёный
- [ ] User `mcp.json` содержит codebase-memory-mcp
- [ ] CBM: 2 индекса (код + docs)
- [ ] Можно звать `/aw-task`
