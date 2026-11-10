#!/usr/bin/env bash
# Ensure the two workspace CBM roots exist. Index only what is missing.
# Usage: cbm-ensure-index.sh [--force]
#   --force  reindex both roots even if present (same as cbm-index-module.sh)
# Env:   CBM_BIN  path to codebase-memory-mcp binary
# Exit:  0 = both roots present (or successfully indexed), 1 = failure
#        0 + warning if binary missing (never hard-fail harness on CBM)

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
    # Last resort: command from user mcp.json
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
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        -h|--help)
            echo "Usage: $0 [--force]"
            exit 0
            ;;
    esac
done

CODE="$ROOT/app/code/Aheadworks"
DOCS="$ROOT/docs"

if [ ! -x "$CBM_BIN" ]; then
    echo "warning: CBM binary not found or not executable: $CBM_BIN (skip ensure-index)" >&2
    exit 0
fi

if [ ! -d "$CODE" ]; then
    echo "error: Aheadworks code root not found: $CODE" >&2
    exit 1
fi
if [ ! -d "$DOCS" ]; then
    echo "error: docs root not found: $DOCS" >&2
    exit 1
fi

CODE_REAL="$(cd "$CODE" && pwd -P)"
DOCS_REAL="$(cd "$DOCS" && pwd -P)"

have_code=0
have_docs=0

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

if "$CBM_BIN" cli list_projects --format=json >"$TMP_JSON" 2>/dev/null; then
    # Prints: have_code=0|1 have_docs=0|1
    status_line="$(
        python3 - "$TMP_JSON" "$CODE_REAL" "$DOCS_REAL" <<'PY'
import json, os, sys
path, code, docs = sys.argv[1], os.path.realpath(sys.argv[2]), os.path.realpath(sys.argv[3])
with open(path, encoding="utf-8") as f:
    data = json.load(f)
have_code = have_docs = 0
for p in data.get("projects") or []:
    root = os.path.realpath(p.get("root_path") or "")
    if root == code:
        have_code = 1
    if root == docs:
        have_docs = 1
print(f"{have_code} {have_docs}")
PY
    )"
    have_code="${status_line%% *}"
    have_docs="${status_line##* }"
else
    echo "warning: list_projects failed; will attempt full index" >&2
    FORCE=1
fi

run_index() {
    local path="$1"
    echo "== index $path"
    if ! "$CBM_BIN" cli --progress index_repository --repo-path="$path" --mode=full; then
        echo "error: index_repository failed for $path" >&2
        return 1
    fi
}

if [ "$FORCE" -eq 1 ]; then
    run_index "$CODE" || exit 1
    run_index "$DOCS" || exit 1
    echo "OK  forced reindex: app/code/Aheadworks + docs"
    exit 0
fi

if [ "${have_code:-0}" -eq 1 ] && [ "${have_docs:-0}" -eq 1 ]; then
    echo "OK  CBM indexes already present for this workspace:"
    echo "    $CODE_REAL"
    echo "    $DOCS_REAL"
    exit 0
fi

[ "${have_code:-0}" -eq 1 ] || run_index "$CODE" || exit 1
[ "${have_docs:-0}" -eq 1 ] || run_index "$DOCS" || exit 1

echo "OK  CBM ensure-index done (missing roots indexed)"
exit 0
