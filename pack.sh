#!/usr/bin/env bash
# Rebuild /media/ssdwork/Sites/aw-harness from the SoT Magento project.
# Usage:
#   ./pack.sh [--source /path/to/m249ee2/src]
#   AW_WIRING_MCP_SRC=… AW_CBM_MCP_SRC=… ./pack.sh --source …
set -euo pipefail

DEST="$(cd "$(dirname "$0")" && pwd)"
SRC="${AW_HARNESS_SOT:-/media/ssdwork/Sites/m249ee2/src}"
if [[ "${1:-}" == "--source" ]]; then
  SRC="$2"
  shift 2 || true
elif [[ -n "${1:-}" && "${1:-}" != --* ]]; then
  SRC="$1"
  shift || true
fi
SRC="$(cd "$SRC" && pwd)"

# MCP source trees (override via env). Prefer sibling of SoT, then Sites/, then kit copy.
resolve_mcp_src() {
  local name="$1" env_var="$2"
  local -a cands=()
  [[ -n "${!env_var:-}" ]] && cands+=("${!env_var}")
  cands+=(
    "$(cd "$(dirname "$SRC")/.." && pwd)/${name}"
    "/media/ssdwork/Sites/${name}"
    "$HOME/Sites/${name}"
    "$DEST/mcp/${name}"
  )
  local c
  for c in "${cands[@]}"; do
    [[ -d "$c" ]] || continue
    c="$(cd "$c" && pwd)"
    echo "$c"
    return 0
  done
  echo "ERROR: cannot find ${name} source (set ${env_var}=/path/to/${name})" >&2
  return 1
}

WIRING_SRC="$(resolve_mcp_src magento-wiring-mcp AW_WIRING_MCP_SRC)"
CBM_SRC="$(resolve_mcp_src codebase-memory-mcp AW_CBM_MCP_SRC)"

echo "==> Packing harness from $SRC → $DEST"
echo "    wiring MCP src: $WIRING_SRC"
echo "    CBM MCP src:    $CBM_SRC"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Preserve installer + portable templates (SoT rsync must not wipe them)
mkdir -p "$TMP/preserve"
for f in install.sh pack.sh VERSION README.md GETTING_STARTED.md bootstrap-user-skills.sh; do
  [[ -f "$DEST/$f" ]] && cp -a "$DEST/$f" "$TMP/preserve/"
done
mkdir -p "$TMP/preserve/scripts"
if [[ -d "$DEST/scripts" ]]; then
  rsync -a "$DEST/scripts/" "$TMP/preserve/scripts/"
fi
mkdir -p "$TMP/preserve/templates"
for f in \
  kit/AGENTS.md.template \
  kit/mcp.user.json.template \
  kit/.cursor/mcp.json.template \
  kit/docs/_harness/ENVIRONMENT.md.template \
  kit/docs/_harness/tools/env.local.sh.template
do
  [[ -f "$DEST/$f" ]] && cp -a "$DEST/$f" "$TMP/preserve/templates/$(basename "$f")"
done

mkdir -p "$DEST/kit/.cursor/"{agents,rules/modules,skills} "$DEST/kit/docs" "$DEST/mcp" "$DEST/scripts"

rsync -a --delete "$SRC/.cursor/agents/00-harness/" "$DEST/kit/.cursor/agents/00-harness/"
rsync -a --delete "$SRC/.cursor/agents/10-domain-helpers/" "$DEST/kit/.cursor/agents/10-domain-helpers/"

for f in aheadworks-code-style aw-data-persistor-key aw-phpdoc aw-resource-main-table aw-str-api-data-constants magento-wiring-mcp; do
  cp -a "$SRC/.cursor/rules/${f}.mdc" "$DEST/kit/.cursor/rules/" 2>/dev/null || true
done

# Skills: pack portable ones; exclude project-specific (ngrok for m249ee2, …)
rsync -a --delete \
  --exclude 'ngrok-tunnel/' \
  "$SRC/.cursor/skills/" "$DEST/kit/.cursor/skills/"

# Harness docs/tools — never ship project-local env / ENVIRONMENT (templates only)
rsync -a --delete \
  --exclude 'tools/env.local.sh' \
  --exclude 'status.md' \
  --exclude 'ENVIRONMENT.md' \
  "$SRC/docs/_harness/" "$DEST/kit/docs/_harness/"

# Restore portable templates
[[ -f "$TMP/preserve/templates/AGENTS.md.template" ]] && \
  cp -a "$TMP/preserve/templates/AGENTS.md.template" "$DEST/kit/AGENTS.md.template"
[[ -f "$TMP/preserve/templates/mcp.user.json.template" ]] && \
  cp -a "$TMP/preserve/templates/mcp.user.json.template" "$DEST/kit/mcp.user.json.template"
[[ -f "$TMP/preserve/templates/mcp.json.template" ]] && \
  cp -a "$TMP/preserve/templates/mcp.json.template" "$DEST/kit/.cursor/mcp.json.template"
[[ -f "$TMP/preserve/templates/ENVIRONMENT.md.template" ]] && \
  cp -a "$TMP/preserve/templates/ENVIRONMENT.md.template" "$DEST/kit/docs/_harness/ENVIRONMENT.md.template"
[[ -f "$TMP/preserve/templates/env.local.sh.template" ]] && \
  cp -a "$TMP/preserve/templates/env.local.sh.template" "$DEST/kit/docs/_harness/tools/env.local.sh.template"

# Drop any leaked env.local.sh
rm -f "$DEST/kit/docs/_harness/tools/env.local.sh"

# MCP payloads
rsync -a --delete --exclude '.venv' --exclude '__pycache__' --exclude '*.egg-info' --exclude '.git' \
  "$WIRING_SRC/" "$DEST/mcp/magento-wiring-mcp/"
# CBM: ship installer docs + scripts; binary is too large for git (downloaded by install.sh)
rsync -a --delete --exclude '.git' --exclude '__pycache__' \
  --exclude 'codebase-memory-mcp' \
  "$CBM_SRC/" "$DEST/mcp/codebase-memory-mcp/"
# Keep a local binary for offline install when available (gitignored)
if [[ -x "$CBM_SRC/codebase-memory-mcp" ]]; then
  cp -a "$CBM_SRC/codebase-memory-mcp" "$DEST/mcp/codebase-memory-mcp/codebase-memory-mcp"
  chmod +x "$DEST/mcp/codebase-memory-mcp/codebase-memory-mcp"
fi

# Restore installer scripts + docs + wrappers
for f in install.sh pack.sh VERSION README.md GETTING_STARTED.md bootstrap-user-skills.sh; do
  [[ -f "$TMP/preserve/$f" ]] && cp -a "$TMP/preserve/$f" "$DEST/$f"
done
rsync -a "$TMP/preserve/scripts/" "$DEST/scripts/"

# Prefer SoT aw-harness-* skills
for S in aw-harness-init aw-harness-pack; do
  if [[ -d "$SRC/.cursor/skills/$S" ]]; then
    rsync -a "$SRC/.cursor/skills/$S/" "$DEST/kit/.cursor/skills/$S/"
  fi
done

chmod +x "$DEST/install.sh" "$DEST/pack.sh" "$DEST/bootstrap-user-skills.sh"
chmod +x "$DEST/scripts/"* 2>/dev/null || true
chmod +x "$DEST/kit/docs/_harness/tools/"*.sh 2>/dev/null || true
chmod +x "$DEST/mcp/codebase-memory-mcp/codebase-memory-mcp" 2>/dev/null || true

echo "==> Packed. Size:"; du -sh "$DEST" "$DEST/kit" "$DEST/mcp"/* 2>/dev/null | sed 's|^|    |'
echo "==> Skills in kit:"; ls "$DEST/kit/.cursor/skills" | sed 's|^|    |'
echo "==> Templates:"; ls "$DEST/kit/"*.template "$DEST/kit/docs/_harness/"*.template "$DEST/kit/docs/_harness/tools/"*.template "$DEST/kit/.cursor/"*.template 2>/dev/null | sed 's|^|    |'
