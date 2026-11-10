#!/usr/bin/env bash
# Reindex the two workspace CBM roots: all Aheadworks code + all docs.
# Usage: cbm-index-module.sh [<Module>]
#   <Module> is accepted for harness call-sites but ignored — indexes are always unified.
# Env:   CBM_BIN  path to codebase-memory-mcp binary
# Exit:  0 = both roots indexed, 1 = usage/binary/path failure

set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

resolve_cbm_bin() {
    local c
    if [[ -n "${CBM_BIN:-}" && -x "$CBM_BIN" ]]; then
        echo "$CBM_BIN"
        return 0
    fi
    for c in \
        "${HOME}/.aw-harness/mcp/codebase-memory-mcp/codebase-memory-mcp" \
        "${ROOT}/.harness/mcp/codebase-memory-mcp/codebase-memory-mcp" \
        "/media/ssdwork/Sites/codebase-memory-mcp/codebase-memory-mcp"
    do
        if [[ -x "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    if [[ -f "${HOME}/.cursor/mcp.json" ]]; then
        c="$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("mcpServers",{}).get("codebase-memory-mcp",{}).get("command",""))' "${HOME}/.cursor/mcp.json" 2>/dev/null || true)"
        if [[ -n "$c" && -x "$c" ]]; then
            echo "$c"
            return 0
        fi
    fi
    echo "${CBM_BIN:-${HOME}/.aw-harness/mcp/codebase-memory-mcp/codebase-memory-mcp}"
}

CBM_BIN="$(resolve_cbm_bin)"

if [ ! -x "$CBM_BIN" ]; then
    echo "warning: CBM binary not found or not executable: $CBM_BIN (skip index)" >&2
    exit 0
fi

CODE="$ROOT/app/code/Aheadworks"
DOCS="$ROOT/docs"

if [ ! -d "$CODE" ]; then
    echo "error: Aheadworks code root not found: $CODE" >&2
    exit 1
fi
if [ ! -d "$DOCS" ]; then
    echo "error: docs root not found: $DOCS" >&2
    exit 1
fi

run_index() {
    local path="$1"
    echo "== index $path"
    if ! "$CBM_BIN" cli --progress index_repository --repo-path="$path" --mode=full; then
        echo "error: index_repository failed for $path" >&2
        return 1
    fi
}

run_index "$CODE" || exit 1
run_index "$DOCS" || exit 1

echo "OK  unified CBM indexes: app/code/Aheadworks + docs"
exit 0
