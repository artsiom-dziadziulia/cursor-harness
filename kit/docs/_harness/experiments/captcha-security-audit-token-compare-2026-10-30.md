# Experiment: Captcha security audit — MCP vs Cursor payload

Date: 2026-10-30  
Module: `app/code/Aheadworks/Captcha`  
Goal: same `/magento2-security-audit` checklist, compare **evidence payload size** (proxy for input tokens/cost).

## Method

| Path | How evidence was gathered |
|---|---|
| **MCP** | `codebase-memory-mcp` CLI on project `…-app-code-Aheadworks`, `path_filter=Captcha/`: checklist `search_code` + targeted `get_code_snippet` (10 calls). Outputs saved under `/tmp/captcha-audit-mcp/`. |
| **Cursor focused** | Host `rg` for the same high-risk patterns + full read of 10 key files (controllers, fail-safe plugin, geo IP, config/di/acl). Outputs under `/tmp/captcha-audit-cursor/`. |
| **Cursor naive (upper bound)** | Sum of all `.php/.xml/.js/.phtml/.html` file sizes under the module (196 files) — what a careless “read the whole module” pass would pull. |

Token estimate: `bytes / 4` (ASCII/code-heavy). **Not** Cursor invoice tokens (no system prompt, skill text, or multi-turn chat overhead).

Illustrative cost: **$3.00 per 1M input tokens** (order-of-magnitude mid-tier; replace with your plan rate).

## Results

| Method | Bytes of evidence | ~Input tokens (÷4) | Units | Wall (gather only) | Illust. $ @ $3/MTok |
|---|---:|---:|---:|---|---:|
| A. MCP focused | 27 737 | 6 934 | 10 tool calls | ~4.4 s CLI | $0.021 |
| B. Cursor `rg` hits only | 8 162 | 2 040 | 5 greps | ~0.1 s | $0.006 |
| C. Cursor `rg` + 10 key files | 49 000 | 12 250 | 15 | ~0.1 s | $0.037 |
| D. Cursor naive full tree | 767 363 | 191 840 | 196 files | — | $0.576 |

### Fair comparisons

- **MCP (A) vs Cursor fair audit (C):** MCP used **~43% less** evidence payload (~**1.8×** smaller). Same confirmed findings (Fail-Safe bypass default-on; IP header trust; ACL present on admin test actions).
- **MCP (A) vs naive full read (D):** MCP used **~96% less** payload (~**28×** smaller).
- **Cursor `rg`-only (B)** is smallest but **insufficient alone** for a defensible audit (no full fail-safe / IP / ACL bodies). Real Cursor agent work looks like **C**, not B.

## Security outcome (both paths)

Same PM-level conclusion: issues detected, overall **High** (storefront Fail-Safe allows invalid captcha when enabled; default is on). Details in chat report for this run.

## Caveats

1. MCP chat via Cursor MCP adds tool-schema/wrapper tokens not counted in CLI dump sizes.
2. Cursor agent turns add Grep/Read JSON envelopes; measured here is raw file/`rg` content.
3. Wall clock: local `rg` is faster; MCP wins on **context size**, not raw search latency.
4. Re-run: `docs/_harness/experiments/` — recreate `/tmp/captcha-audit-{mcp,cursor}` with the same commands if needed.

## Commands used (repro)

```bash
# Cursor-style gather (host)
MOD=app/code/Aheadworks/Captcha
rg -n 'eval\s*\(|unserialize\s*\(|…' "$MOD"
# + cat key files → /tmp/captcha-audit-cursor

# MCP gather
CBM=/media/ssdwork/Sites/codebase-memory-mcp/codebase-memory-mcp
PROJ=media-ssdwork-Sites-m249ee2-src-app-code-Aheadworks
"$CBM" cli search_code --project=$PROJ --path-filter=Captcha/ …
"$CBM" cli get_code_snippet --project=$PROJ --qualified-name=… 
```
