---
name: aw-harness-pack
description: >-
  Rebuild /media/ssdwork/Sites/aw-harness from the SoT Magento project (agents,
  rules, skills, docs/_harness, magento-wiring-mcp, codebase-memory-mcp). Use when
  the user says pack harness, обнови aw-harness, aw-harness-pack, harness-pack, or
  refresh the portable harness kit.
---

# `/aw-harness-pack` — rebuild portable harness kit

## Goal

Refresh **`/media/ssdwork/Sites/aw-harness`** from the SoT project (default `m249ee2/src`) so `/aw-harness-init` / `harness-install` can bootstrap **any** Magento layout.

## Steps

1. Confirm SoT Magento root (default `/media/ssdwork/Sites/m249ee2/src`).
2. Ensure SoT has up-to-date `aw-harness-init` / `aw-harness-pack` skills and portable `docs/_harness/tools/env.sh` (docker|host).
3. Run:

```bash
harness-pack --source /media/ssdwork/Sites/m249ee2/src
# or
/media/ssdwork/Sites/aw-harness/pack.sh --source /media/ssdwork/Sites/m249ee2/src
```

If MCP live trees are not under `/media/ssdwork/Sites/`:

```bash
AW_WIRING_MCP_SRC=/path/to/magento-wiring-mcp \
AW_CBM_MCP_SRC=/path/to/codebase-memory-mcp \
  harness-pack --source /path/to/m249ee2/src
```

4. Confirm after pack:
   - `install.sh` / `scripts/harness-install` executable
   - templates present: `kit/AGENTS.md.template`, `ENVIRONMENT.md.template`, `env.local.sh.template`, `mcp.json.template`
   - **no** `kit/docs/_harness/tools/env.local.sh` (project-local — must stay out of the kit)
   - skills `aw-harness-init` / `aw-harness-pack` / `aw-cbm-ensure-index` under `kit/.cursor/skills/`
   - **no** `ngrok-tunnel` in kit skills (project-specific, excluded)

5. Refresh user skills + PATH wrappers:

```bash
/media/ssdwork/Sites/aw-harness/bootstrap-user-skills.sh
```

## Rules

- Do not delete `install.sh` / `README.md` / `VERSION` / `*.template` / `scripts/` — `pack.sh` preserves them.
- Do not pack `env.local.sh` from SoT into the kit.
- Do not commit.
- Module-specific `.cursor/rules/modules/*.mdc` stay **out** of the kit.
- Project-only skills (`ngrok-tunnel`) stay **out** of the kit.
