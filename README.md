# Aheadworks Cursor Harness kit

Portable harness for **any** Magento 2 layout: Mark Shust (`src/` + `bin/start`), pystacker / compose, host PHP, custom bind mounts.

Bundles:

- `.cursor/agents` (00-harness + 10-domain-helpers)
- `.cursor/rules` + skills (`/aw-task`, `/aw-harness-init`, `/aw-cbm-ensure-index`, …)
- `docs/_harness` (workflow, gates, tools)
- MCP: `magento-wiring-mcp` (source) + `codebase-memory-mcp` (installer downloads the binary from DeusData releases; ~300MB binary is not in git)

## New developer — first time on this machine

Skill `/aw-harness-init` does **not** appear in an empty Magento project by itself. It lives in the **kit**. Bootstrap once per machine:

1. Get this kit (clone / copy / network share) onto the machine, e.g. `~/aw-harness` or `/media/ssdwork/Sites/aw-harness`.
2. Install **user-level** Cursor skills + optional PATH wrappers:

```bash
/path/to/aw-harness/bootstrap-user-skills.sh
```

This copies `/aw-harness-init` and `/aw-harness-pack` into `~/.cursor/skills/` and symlinks:

- `~/.local/bin/harness-install` → kit `scripts/harness-install`
- `~/.local/bin/harness-pack` → kit `scripts/harness-pack`

Ensure `~/.local/bin` is on your `PATH` (bootstrap prints a hint if not).

3. Restart Cursor (or reload skills).
4. Open the Magento project → chat: **`/aw-harness-init`**.

**Without the skill** you can still install:

```bash
harness-install --target /path/to/magento-root
# or
/path/to/aw-harness/install.sh --target /path/to/magento-root
```

## Install into a Magento project

### Interactive (recommended)

```bash
harness-install
# or
harness-install --target /path/to/magento-root
```

The installer asks (and **skips** anything already present unless `--force`):

1. Magento root (`app/`)
2. Module code path (`app/code/Aheadworks`, …)
3. Stack: markshust / pystacker / host / other docker
4. Compose dir, PHP container, path inside the container
5. MCP (**outside** Magento by default):
   - **shared** — first install: ask for a path (default `~/.aw-harness/mcp`) and install wiring+CBM there
   - **reuse** — MCP already on the machine / sibling — only wire `mcp.json`
   - **project** — Magento-local `.harness/mcp` (optional, not recommended)

Example: first project installs MCP to `~/.aw-harness/mcp` → second project reuses that path (no second copy).

After a successful install, the **project** also gets `.cursor/skills/aw-harness-init` (copied with the kit). User-level skills from step 2 remain the bootstrap for the *next* empty project.

Install also:

- merges **codebase-memory-mcp** into `~/.cursor/mcp.json` when missing (safe JSON merge)
- best-effort runs `docs/_harness/tools/cbm-ensure-index.sh` for the two roots

### Non-interactive

```bash
harness-install \
  --non-interactive \
  --target /path/to/magento \
  --code-path app/code/Aheadworks \
  --stack pystacker \
  --runtime docker \
  --compose-dir /path/to/compose \
  --php-container myproj-php-1 \
  --runtime-magento-root /var/www/html \
  --mcp-mode shared \
  --mcp-shared-root "$HOME/.aw-harness/mcp" \
  --force
```

## What gets written

| Path | Purpose |
|---|---|
| `AGENTS.md` | Project agent rules (stack-filled) |
| `.cursor/agents|rules|skills|mcp.json` | Cursor harness + wiring MCP |
| `docs/_harness/` | Workflow + tools |
| `docs/_harness/tools/env.local.sh` | **This machine’s** runtime (docker/host, container, paths) |
| `~/.aw-harness/mcp/` (shared, default) | Machine-wide wiring + CBM (not inside Magento) |
| `~/.cursor/mcp.json` | User CBM entry (created or merged) |

## Refresh the kit from SoT

```bash
harness-pack --source /path/to/m249ee2/src
# or
/path/to/aw-harness/pack.sh --source /path/to/m249ee2/src
```

Optional env overrides when MCP live trees are not next to SoT:

```bash
AW_WIRING_MCP_SRC=/path/to/magento-wiring-mcp \
AW_CBM_MCP_SRC=/path/to/codebase-memory-mcp \
  harness-pack --source /path/to/m249ee2/src
```

`pack.sh` skips project-only skills (e.g. `ngrok-tunnel`).

## After install

1. Reload Cursor MCP.
2. If indexes were skipped: `/aw-cbm-ensure-index` or `docs/_harness/tools/cbm-ensure-index.sh`.
3. `docs/_harness/tools/gates.sh <Module>`
4. `/aw-task` or `/aw-document-module`

## Layout

```
aw-harness/
  VERSION
  README.md
  GETTING_STARTED.md
  bootstrap-user-skills.sh   # once per developer machine → ~/.cursor/skills + ~/.local/bin
  install.sh
  pack.sh
  scripts/
    harness-install          # PATH wrapper → install.sh
    harness-pack             # PATH wrapper → pack.sh
  kit/
  mcp/
```
