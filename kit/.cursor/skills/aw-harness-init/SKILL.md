---
name: aw-harness-init
description: >-
  Fully deploy the Aheadworks Cursor harness into ANY Magento 2 project layout
  (Mark Shust, pystacker, host PHP, custom compose). Asks where Magento, modules,
  PHP runtime and MCP home (outside Magento, default ~/.aw-harness/mcp) should
  live. Reuses existing MCP; skips pieces already present. Use for aw-harness-init,
  init harness, разверни harness, setup harness, install aw-harness, harness-install.
---

# `/aw-harness-init` — portable harness install

## How this skill got here

| Situation | Where the skill lives |
|---|---|
| New machine / empty Magento | Run once: `<aw-harness>/bootstrap-user-skills.sh` → `~/.cursor/skills/` (+ `harness-install` in `~/.local/bin`). |
| After harness install | Also under the project’s `.cursor/skills/`. |
| No skill | Run `harness-install --target …` or `<aw-harness>/install.sh --target …`. |

Kit path: `KIT_ROOT.txt` next to this file, or ask the user.

## Goal

Install harness into Magento root. **MCP binaries go outside Magento** (default `~/.aw-harness/mcp`). Idempotent. Reuse existing MCP when present.

## MCP policy (important)

1. **First install on the machine** → mode `shared`: ask for a path **not** under Magento (default `$HOME/.aw-harness/mcp`), install wiring + CBM there.
2. **Later projects** → mode `reuse` that same home (or sibling), only write project `mcp.json` with this Magento’s `MAGENTO_ROOT`.
3. **project** (`.harness/mcp` inside Magento) — only if the user insists; confirm twice / warn.

Never accept Magento root (or a path under it) as MCP home.

## Interview (RU)

1. Magento root (`app/`)
2. Module code path
3. PHP stack (if no `env.local.sh`)
4. MCP: reuse existing / install shared home (path!) / project-local (discourage)
5. `--force` only if refresh requested

## Run installer

Prefer PATH wrapper when bootstrap was run:

```bash
harness-install --target "$MAGENTO_ROOT"
# or
"$KIT/install.sh" --target "$MAGENTO_ROOT"
```

First install, non-TTY:

```bash
harness-install \
  --non-interactive \
  --target "$MAGENTO_ROOT" \
  --code-path app/code/Aheadworks \
  --stack markshust --runtime docker \
  --compose-dir "$COMPOSE_DIR" \
  --php-container "$PHP_CONTAINER" \
  --mcp-mode shared \
  --mcp-shared-root "$HOME/.aw-harness/mcp"
```

After install: remind user to reload Cursor MCP. CBM merge into `~/.cursor/mcp.json` and `cbm-ensure-index` are handled by the installer when possible.

## Rules

- Prefer shared/reuse over project-local MCP.
- Do not hardcode SoT paths into a foreign project.
- Do not commit / composer / wipe `docs/<Module>/`.
- Do not `--force` unless asked.
