#!/usr/bin/env bash
# Install Aheadworks Cursor harness into ANY Magento 2 project (markshust, pystacker, host, …).
# Idempotent: skips pieces that already exist unless --force.
# Can reuse MCP from a sibling Magento project (same parent folder) instead of copying again.
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$KIT_ROOT/VERSION" 2>/dev/null || echo unknown)"

TARGET=""
CODE_PATH=""
RUNTIME=""          # docker | host
STACK_KIND=""       # markshust | pystacker | other-docker | host
COMPOSE_DIR=""
COMPOSE_PROJECT=""
PHP_CONTAINER=""
RUNTIME_MAGENTO_ROOT=""
MAGENTO_VERSION=""
STACK_HINT=""
MCP_MODE=""         # shared (default first install) | reuse | project
MCP_SHARED_ROOT=""
MCP_REUSE_FROM=""   # absolute path to an existing mcp parent (…/.harness/mcp or shared root)
# Default MCP home is OUTSIDE the Magento tree (machine-wide, under $HOME)
DEFAULT_MCP_HOME="${AW_DEFAULT_MCP_HOME:-$HOME/.aw-harness/mcp}"
FORCE=0
SKIP_VENV=0
NONINTERACTIVE=0

# Counters for summary
SKIPPED=0
WROTE=0
REUSED=0

ask() {
  local prompt="$1" default="${2:-}" var
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " var || true
    echo "${var:-$default}"
  else
    read -r -p "$prompt: " var || true
    echo "$var"
  fi
}

ask_yn() {
  local prompt="$1" default="${2:-y}" ans
  ans="$(ask "$prompt (y/n)" "$default")"
  [[ "$ans" =~ ^[Yy] ]]
}

note_skip() { echo "    skip: $*"; SKIPPED=$((SKIPPED + 1)); }
note_write() { echo "    $*"; WROTE=$((WROTE + 1)); }
note_reuse() { echo "    reuse: $*"; REUSED=$((REUSED + 1)); }

detect_magento_root() {
  local cand
  for cand in "$(pwd)" "$(pwd)/src" "$(pwd)/magento" "$(pwd)/htdocs" "$(pwd)/web"; do
    if [[ -d "$cand/app" ]] && { [[ -d "$cand/app/etc" ]] || [[ -f "$cand/bin/magento" ]]; }; then
      echo "$(cd "$cand" && pwd)"
      return 0
    fi
  done
  return 1
}

detect_code_paths() {
  local root="$1"
  local -a found=()
  [[ -d "$root/app/code/Aheadworks" ]] && found+=("app/code/Aheadworks")
  [[ -d "$root/app/code/aheadworks" ]] && found+=("app/code/aheadworks")
  if ls -d "$root"/vendor/aheadworks/* >/dev/null 2>&1; then
    found+=("vendor/aheadworks")
  fi
  if [[ -d "$root/app/code" ]]; then
    local d base
    for d in "$root"/app/code/*; do
      [[ -d "$d" ]] || continue
      base="$(basename "$d")"
      [[ "$base" == "Aheadworks" || "$base" == "aheadworks" || "$base" == "Magento" ]] && continue
      if find "$d" -mindepth 2 -maxdepth 2 -type d -name etc 2>/dev/null | head -1 | grep -q .; then
        found+=("app/code/$base")
      fi
    done
  fi
  printf '%s\n' "${found[@]}" | awk 'NF && !seen[$0]++'
}

# True if path looks like a usable MCP parent (contains wiring + cbm trees).
mcp_parent_usable() {
  local parent="$1"
  local w="$parent/magento-wiring-mcp" c="$parent/codebase-memory-mcp"
  [[ -d "$w" ]] || return 1
  [[ -d "$c" ]] || return 1
  # Prefer ready binaries; source-only still counts as reusable install
  [[ -e "$c/codebase-memory-mcp" || -d "$c" ]] || return 1
  return 0
}

wiring_bin_for() {
  local home="$1"
  echo "$home/.venv/bin/magento-wiring-mcp"
}

cbm_bin_for() {
  local home="$1"
  echo "$home/codebase-memory-mcp"
}

# Print lines: LABEL<TAB>MCP_PARENT_ABS  (folder that contains magento-wiring-mcp + codebase-memory-mcp)
discover_mcp_candidates() {
  local target="$1"
  local parent grand sibling src_cand mcp_json cmd wiring_home mcp_parent label
  parent="$(dirname "$target")"
  grand="$(dirname "$parent")"

  if mcp_parent_usable "$target/.harness/mcp"; then
    printf 'this-project\t%s\n' "$target/.harness/mcp"
  fi
  if mcp_parent_usable "$parent/.harness/mcp"; then
    printf 'parent-shared\t%s\n' "$parent/.harness/mcp"
  fi
  if mcp_parent_usable "$grand/.harness/mcp"; then
    printf 'grandparent-shared\t%s\n' "$grand/.harness/mcp"
  fi

  # Sibling trees: work/projA and work/projB (magento root or …/src)
  for sibling in "$parent"/*; do
    [[ -d "$sibling" ]] || continue
    [[ "$(cd "$sibling" && pwd)" == "$target" ]] && continue
    for src_cand in "$sibling" "$sibling/src" "$sibling/magento" "$sibling/htdocs"; do
      [[ -d "$src_cand/app" ]] || continue
      if mcp_parent_usable "$src_cand/.harness/mcp"; then
        printf 'sibling:%s\t%s\n' "$(basename "$sibling")" "$src_cand/.harness/mcp"
      fi
      mcp_json="$src_cand/.cursor/mcp.json"
      if [[ -f "$mcp_json" ]]; then
        cmd="$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("mcpServers",{}).get("magento-wiring",{}).get("command",""))' "$mcp_json" 2>/dev/null || true)"
        if [[ -n "$cmd" && -e "$cmd" ]]; then
          # …/magento-wiring-mcp/.venv/bin/magento-wiring-mcp → package dir → MCP parent
          wiring_home="$(cd "$(dirname "$cmd")/../.." && pwd)"
          mcp_parent="$(dirname "$wiring_home")"
          if mcp_parent_usable "$mcp_parent"; then
            printf 'sibling-mcp.json:%s\t%s\n' "$(basename "$sibling")" "$mcp_parent"
          fi
        fi
      fi
    done
  done

  # Machine-wide default (home) — preferred shared location
  if mcp_parent_usable "$DEFAULT_MCP_HOME"; then
    printf 'home-shared\t%s\n' "$DEFAULT_MCP_HOME"
  fi

  if mcp_parent_usable "$KIT_ROOT/mcp"; then
    printf 'kit-mcp\t%s\n' "$KIT_ROOT/mcp"
  fi
}

inventory_target() {
  local t="$1"
  echo "==> Existing pieces in $t"
  [[ -f "$t/AGENTS.md" ]] && echo "    [+] AGENTS.md" || echo "    [ ] AGENTS.md"
  [[ -d "$t/.cursor/agents/00-harness" ]] && echo "    [+] .cursor/agents/00-harness" || echo "    [ ] .cursor/agents/00-harness"
  [[ -f "$t/.cursor/skills/aw-task/SKILL.md" ]] && echo "    [+] .cursor/skills/aw-task" || echo "    [ ] .cursor/skills/aw-task"
  [[ -f "$t/docs/_harness/WORKFLOW.md" ]] && echo "    [+] docs/_harness" || echo "    [ ] docs/_harness"
  [[ -f "$t/docs/_harness/tools/env.local.sh" ]] && echo "    [+] env.local.sh" || echo "    [ ] env.local.sh"
  [[ -f "$t/.cursor/mcp.json" ]] && echo "    [+] .cursor/mcp.json" || echo "    [ ] .cursor/mcp.json"
  if mcp_parent_usable "$t/.harness/mcp"; then
    echo "    [+] local .harness/mcp"
    [[ -x "$(wiring_bin_for "$t/.harness/mcp/magento-wiring-mcp")" ]] && echo "    [+] wiring venv binary" || echo "    [ ] wiring venv binary"
  else
    echo "    [ ] local .harness/mcp"
  fi
  if [[ -f "$HOME/.cursor/mcp.json" ]] && grep -q 'codebase-memory-mcp' "$HOME/.cursor/mcp.json" 2>/dev/null; then
    echo "    [+] user ~/.cursor/mcp.json has codebase-memory-mcp"
  else
    echo "    [ ] user codebase-memory-mcp"
  fi
}

usage() {
  cat <<EOF
aw-harness installer v${VERSION}

Usage:
  harness-install [--target PATH] [options]     # after bootstrap-user-skills.sh
  $(basename "$0") [--target PATH] [options]
  $(basename "$0") --non-interactive --target PATH --runtime docker|host ...

Idempotent by default: existing agents/skills/docs/MCP/venv/AGENTS are left alone
unless --force. Sibling projects under the same parent can share MCP (reuse).
Merges codebase-memory-mcp into ~/.cursor/mcp.json when missing; best-effort CBM ensure-index.

Options:
  --target PATH              Magento root (app/, bin/, …)
  --code-path REL            Module vendor path under target
  --runtime docker|host
  --stack markshust|pystacker|other-docker|host
  --compose-dir PATH
  --compose-project NAME
  --php-container NAME
  --runtime-magento-root P
  --magento-version VER
  --mcp-mode shared|reuse|project
      shared  = install/use MCP outside Magento (default: ~/.aw-harness/mcp) — first install
      reuse   = point at an existing MCP parent (sibling / home / shared)
      project = Magento-local .harness/mcp (optional, not default)
  --mcp-shared-root PATH     MCP parent for shared mode (default: ~/.aw-harness/mcp)
  --mcp-reuse-from PATH      Existing MCP parent when mcp-mode=reuse
  --stack-hint TEXT
  --force                    Overwrite / re-rsync even if present
  --skip-venv
  --non-interactive
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --code-path) CODE_PATH="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --stack) STACK_KIND="$2"; shift 2 ;;
    --compose-dir) COMPOSE_DIR="$2"; shift 2 ;;
    --compose-project) COMPOSE_PROJECT="$2"; shift 2 ;;
    --php-container) PHP_CONTAINER="$2"; shift 2 ;;
    --runtime-magento-root) RUNTIME_MAGENTO_ROOT="$2"; shift 2 ;;
    --magento-version) MAGENTO_VERSION="$2"; shift 2 ;;
    --mcp-mode) MCP_MODE="$2"; shift 2 ;;
    --mcp-shared-root) MCP_SHARED_ROOT="$2"; shift 2 ;;
    --mcp-reuse-from) MCP_REUSE_FROM="$2"; shift 2 ;;
    --stack-hint) STACK_HINT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --skip-venv) SKIP_VENV=1; shift ;;
    --non-interactive) NONINTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

INTERACTIVE=0
if [[ $NONINTERACTIVE -eq 0 && -t 0 ]]; then
  INTERACTIVE=1
fi

echo "==> aw-harness v${VERSION}"

# --- resolve Magento root ---
if [[ -z "$TARGET" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    det="$(detect_magento_root || true)"
    TARGET="$(ask "Magento root on disk (folder with app/)" "${det:-}")"
  else
    echo "ERROR: --target required in non-interactive mode" >&2
    exit 1
  fi
fi
TARGET="$(cd "$TARGET" && pwd)"
if [[ ! -d "$TARGET/app" ]]; then
  echo "ERROR: $TARGET is not a Magento root (missing app/)" >&2
  exit 1
fi

inventory_target "$TARGET"

# Pre-load answers from existing env.local if re-init without force interview defaults
if [[ -f "$TARGET/docs/_harness/tools/env.local.sh" ]]; then
  # shellcheck disable=SC1091
  source "$TARGET/docs/_harness/tools/env.local.sh"
  CODE_PATH="${CODE_PATH:-${AW_MODULES_REL:-}}"
  RUNTIME="${RUNTIME:-${AW_RUNTIME:-}}"
  COMPOSE_DIR="${COMPOSE_DIR:-${AW_COMPOSE_DIR:-}}"
  COMPOSE_PROJECT="${COMPOSE_PROJECT:-${AW_COMPOSE_PROJECT:-}}"
  PHP_CONTAINER="${PHP_CONTAINER:-${AW_CONTAINER:-}}"
  RUNTIME_MAGENTO_ROOT="${RUNTIME_MAGENTO_ROOT:-${AW_MAGENTO_ROOT_IN_RUNTIME:-}}"
  STACK_HINT="${STACK_HINT:-${AW_STACK_HINT:-}}"
fi

# Discover sibling / nearby MCP
mapfile -t MCP_CAND_LINES < <(discover_mcp_candidates "$TARGET" | awk -F'\t' '!seen[$2]++')
if [[ ${#MCP_CAND_LINES[@]} -gt 0 ]]; then
  echo "==> Reusable MCP found nearby:"
  for line in "${MCP_CAND_LINES[@]}"; do
    echo "    - ${line//$'\t'/ → }"
  done
fi

# --- interview ---
if [[ -z "$CODE_PATH" ]]; then
  mapfile -t CANDS < <(detect_code_paths "$TARGET")
  if [[ $INTERACTIVE -eq 1 ]]; then
    echo "Aheadworks / module code path candidates:"
    local_i=1
    for c in "${CANDS[@]:-}"; do echo "  $local_i) $c"; local_i=$((local_i+1)); done
    echo "  0) enter custom relative path"
    def="${CANDS[0]:-app/code/Aheadworks}"
    choice="$(ask "Choose code path" "1")"
    if [[ "$choice" == "0" ]]; then
      CODE_PATH="$(ask "Relative code path" "$def")"
    elif [[ "$choice" =~ ^[0-9]+$ && -n "${CANDS[$((choice-1))]:-}" ]]; then
      CODE_PATH="${CANDS[$((choice-1))]}"
    else
      CODE_PATH="$def"
    fi
  else
    CODE_PATH="${CANDS[0]:-app/code/Aheadworks}"
  fi
fi

if [[ -z "$STACK_KIND" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    # Skip stack questions if env.local already complete and not forcing full reconfigure
    if [[ -f "$TARGET/docs/_harness/tools/env.local.sh" && $FORCE -eq 0 ]]; then
      if ask_yn "env.local.sh already set — keep stack/runtime as-is?" "y"; then
        STACK_KIND="${STACK_KIND:-markshust}"
        [[ "$RUNTIME" == "host" ]] && STACK_KIND="host"
      else
        STACK_KIND=""
      fi
    fi
  fi
fi

if [[ -z "$STACK_KIND" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    echo "PHP / stack type:"
    echo "  1) Mark Shust docker-magento (bin/start, *-phpfpm-1)"
    echo "  2) Pystacker / other docker-compose PHP"
    echo "  3) Host PHP (no container)"
    echo "  4) Other docker (manual container name)"
    sk="$(ask "Choose" "1")"
    case "$sk" in
      2) STACK_KIND="pystacker" ;;
      3) STACK_KIND="host" ;;
      4) STACK_KIND="other-docker" ;;
      *) STACK_KIND="markshust" ;;
    esac
  else
    STACK_KIND="${STACK_KIND:-markshust}"
  fi
fi

case "$STACK_KIND" in
  host) RUNTIME="${RUNTIME:-host}" ;;
  *) RUNTIME="${RUNTIME:-docker}" ;;
esac

if [[ "$RUNTIME" == "docker" ]]; then
  if [[ -z "$COMPOSE_DIR" ]]; then
    if [[ -x "$(dirname "$TARGET")/bin/start" || -f "$(dirname "$TARGET")/compose.yaml" || -f "$(dirname "$TARGET")/docker-compose.yml" ]]; then
      COMPOSE_DIR="$(cd "$(dirname "$TARGET")" && pwd)"
    elif [[ -f "$TARGET/docker-compose.yml" || -f "$TARGET/compose.yaml" ]]; then
      COMPOSE_DIR="$TARGET"
    fi
    if [[ $INTERACTIVE -eq 1 ]]; then
      COMPOSE_DIR="$(ask "Compose / stack directory (docker)" "${COMPOSE_DIR:-$TARGET}")"
    fi
  fi
  COMPOSE_DIR="$(cd "${COMPOSE_DIR:-$TARGET}" && pwd)"
  COMPOSE_PROJECT="${COMPOSE_PROJECT:-$(basename "$COMPOSE_DIR")}"

  if [[ -z "$PHP_CONTAINER" ]]; then
    case "$STACK_KIND" in
      markshust) PHP_CONTAINER="${COMPOSE_PROJECT}-phpfpm-1" ;;
      pystacker) PHP_CONTAINER="${COMPOSE_PROJECT}-php-1" ;;
      *) PHP_CONTAINER="${COMPOSE_PROJECT}-phpfpm-1" ;;
    esac
    if [[ $INTERACTIVE -eq 1 ]]; then
      echo "Running docker containers (php-ish):"
      docker ps --format '  {{.Names}}' 2>/dev/null | grep -iE 'php|fpm|magento' || docker ps --format '  {{.Names}}' 2>/dev/null | head -20 || true
      PHP_CONTAINER="$(ask "PHP container name" "$PHP_CONTAINER")"
    fi
  fi
  RUNTIME_MAGENTO_ROOT="${RUNTIME_MAGENTO_ROOT:-/var/www/html}"
  if [[ $INTERACTIVE -eq 1 ]]; then
    RUNTIME_MAGENTO_ROOT="$(ask "Magento path inside container" "$RUNTIME_MAGENTO_ROOT")"
  fi
  case "$STACK_KIND" in
    markshust) STACK_HINT="${STACK_HINT:-cd $COMPOSE_DIR && bin/start}" ;;
    pystacker) STACK_HINT="${STACK_HINT:-cd $COMPOSE_DIR && docker compose up -d}" ;;
    *) STACK_HINT="${STACK_HINT:-start container $PHP_CONTAINER}" ;;
  esac
  if [[ $INTERACTIVE -eq 1 ]]; then
    STACK_HINT="$(ask "Hint when container is down" "$STACK_HINT")"
  fi
else
  COMPOSE_DIR="${COMPOSE_DIR:-$TARGET}"
  COMPOSE_PROJECT="${COMPOSE_PROJECT:-$(basename "$TARGET")}"
  PHP_CONTAINER="${PHP_CONTAINER:-host}"
  RUNTIME_MAGENTO_ROOT="${RUNTIME_MAGENTO_ROOT:-$TARGET}"
  STACK_HINT="${STACK_HINT:-use host PHP from $TARGET}"
fi

MAGENTO_VERSION="${MAGENTO_VERSION:-2.4.x}"
if [[ $INTERACTIVE -eq 1 ]]; then
  if [[ ! -f "$TARGET/AGENTS.md" || $FORCE -eq 1 ]]; then
    MAGENTO_VERSION="$(ask "Magento version label for AGENTS.md" "$MAGENTO_VERSION")"
  fi
fi

# --- MCP mode ---
WIRING_SRC="$KIT_ROOT/mcp/magento-wiring-mcp"
CBM_SRC="$KIT_ROOT/mcp/codebase-memory-mcp"

pick_reuse_default() {
  local line label path
  # Prefer machine home shared, then siblings, then anything else except kit / this-project
  for line in "${MCP_CAND_LINES[@]:-}"; do
    label="${line%%$'\t'*}"; path="${line#*$'\t'}"
    [[ "$label" == "home-shared" ]] && { echo "$path"; return 0; }
  done
  for line in "${MCP_CAND_LINES[@]:-}"; do
    label="${line%%$'\t'*}"; path="${line#*$'\t'}"
    case "$label" in
      sibling:*|sibling-mcp.json:*|parent-shared|grandparent-shared)
        echo "$path"; return 0 ;;
    esac
  done
  return 1
}

expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  echo "$p"
}

ask_mcp_shared_root() {
  local def="${1:-$DEFAULT_MCP_HOME}"
  local p
  echo "MCP must live OUTSIDE the Magento project (shared by all your M2 trees)." >&2
  echo "  Will contain: <path>/magento-wiring-mcp and <path>/codebase-memory-mcp" >&2
  p="$(ask "MCP home directory (not inside Magento)" "$def")"
  p="$(expand_path "$p")"
  if [[ "$p" == "$TARGET" || "$p" == "$TARGET"/* ]]; then
    echo "ERROR: MCP home cannot be inside the Magento project ($TARGET)." >&2
    echo "       Use e.g. $DEFAULT_MCP_HOME" >&2
    exit 1
  fi
  if [[ -d "$p/app/etc" ]]; then
    echo "ERROR: path looks like a Magento root. Pick a dedicated MCP directory." >&2
    exit 1
  fi
  printf '%s\n' "$p"
}

if [[ -n "$MCP_REUSE_FROM" ]]; then
  MCP_MODE="reuse"
  MCP_REUSE_FROM="$(cd "$(expand_path "$MCP_REUSE_FROM")" && pwd)"
fi

if [[ -z "$MCP_MODE" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    echo "MCP servers (binaries — NOT inside Magento by default):"
    echo "  1) Reuse MCP already on this machine (home / sibling) — no second copy"
    echo "  2) Install or use a shared MCP home (default: $DEFAULT_MCP_HOME)  ← first install"
    echo "  3) Inside this Magento only (.harness/mcp) — optional / not recommended"
    def_mm="2"
    if pick_reuse_default >/dev/null 2>&1; then
      def_mm="1"
    fi
    # Local project MCP already present → offer keep via reuse/project
    if mcp_parent_usable "$TARGET/.harness/mcp" && ! pick_reuse_default >/dev/null 2>&1; then
      def_mm="3"
    fi
    mm="$(ask "Choose" "$def_mm")"
    case "$mm" in
      1) MCP_MODE="reuse" ;;
      3) MCP_MODE="project" ;;
      *) MCP_MODE="shared" ;;
    esac
  else
    # non-interactive: reuse if found; else shared under ~/.aw-harness/mcp (never project)
    if pick_reuse_default >/dev/null 2>&1; then
      MCP_MODE="reuse"
      MCP_REUSE_FROM="$(pick_reuse_default)"
    else
      MCP_MODE="shared"
      MCP_SHARED_ROOT="${MCP_SHARED_ROOT:-$DEFAULT_MCP_HOME}"
    fi
  fi
fi

if [[ "$MCP_MODE" == "reuse" ]]; then
  if [[ -z "$MCP_REUSE_FROM" ]]; then
    def_reuse="$(pick_reuse_default || true)"
    if [[ $INTERACTIVE -eq 1 ]]; then
      echo "Reusable MCP parents:"
      ri=1
      declare -a REUSE_PATHS=()
      for line in "${MCP_CAND_LINES[@]:-}"; do
        echo "  $ri) ${line//$'\t'/ → }"
        REUSE_PATHS+=("${line#*$'\t'}")
        ri=$((ri + 1))
      done
      if [[ ${#REUSE_PATHS[@]} -eq 0 ]]; then
        echo "No existing MCP found — switching to shared install at $DEFAULT_MCP_HOME"
        MCP_MODE="shared"
      else
        rchoice="$(ask "Choose MCP to reuse" "1")"
        if [[ "$rchoice" =~ ^[0-9]+$ && -n "${REUSE_PATHS[$((rchoice-1))]:-}" ]]; then
          MCP_REUSE_FROM="${REUSE_PATHS[$((rchoice-1))]}"
        else
          MCP_REUSE_FROM="${def_reuse:-${REUSE_PATHS[0]}}"
        fi
      fi
    else
      MCP_REUSE_FROM="${def_reuse:-}"
      if [[ -z "$MCP_REUSE_FROM" ]]; then
        MCP_MODE="shared"
        MCP_SHARED_ROOT="${MCP_SHARED_ROOT:-$DEFAULT_MCP_HOME}"
      fi
    fi
  fi
  if [[ "$MCP_MODE" == "reuse" ]]; then
    MCP_REUSE_FROM="$(cd "$(expand_path "$MCP_REUSE_FROM")" && pwd)"
    mcp_parent_usable "$MCP_REUSE_FROM" || { echo "ERROR: not a usable MCP parent: $MCP_REUSE_FROM" >&2; exit 1; }
    WIRING_HOME="$MCP_REUSE_FROM/magento-wiring-mcp"
    CBM_HOME="$MCP_REUSE_FROM/codebase-memory-mcp"
  fi
fi

if [[ "$MCP_MODE" == "shared" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    MCP_SHARED_ROOT="$(ask_mcp_shared_root "${MCP_SHARED_ROOT:-$DEFAULT_MCP_HOME}")"
  else
    MCP_SHARED_ROOT="$(expand_path "${MCP_SHARED_ROOT:-$DEFAULT_MCP_HOME}")"
    if [[ "$MCP_SHARED_ROOT" == "$TARGET" || "$MCP_SHARED_ROOT" == "$TARGET"/* ]]; then
      echo "ERROR: --mcp-shared-root cannot be inside Magento root" >&2
      exit 1
    fi
  fi
  mkdir -p "$MCP_SHARED_ROOT"
  MCP_SHARED_ROOT="$(cd "$MCP_SHARED_ROOT" && pwd)"
  WIRING_HOME="${MCP_SHARED_ROOT%/}/magento-wiring-mcp"
  CBM_HOME="${MCP_SHARED_ROOT%/}/codebase-memory-mcp"
fi

if [[ "$MCP_MODE" == "project" ]]; then
  if [[ $INTERACTIVE -eq 1 ]]; then
    echo "NOTE: project-local MCP duplicates binaries per Magento tree."
    ask_yn "Really install MCP inside $TARGET/.harness/mcp?" "n" || {
      MCP_MODE="shared"
      MCP_SHARED_ROOT="$(ask_mcp_shared_root "$DEFAULT_MCP_HOME")"
      mkdir -p "$MCP_SHARED_ROOT"
      MCP_SHARED_ROOT="$(cd "$MCP_SHARED_ROOT" && pwd)"
      WIRING_HOME="${MCP_SHARED_ROOT%/}/magento-wiring-mcp"
      CBM_HOME="${MCP_SHARED_ROOT%/}/codebase-memory-mcp"
    }
  fi
fi
if [[ "$MCP_MODE" == "project" ]]; then
  WIRING_HOME="$TARGET/.harness/mcp/magento-wiring-mcp"
  CBM_HOME="$TARGET/.harness/mcp/codebase-memory-mcp"
fi

if [[ $INTERACTIVE -eq 1 && $FORCE -eq 0 ]]; then
  if ask_yn "Force overwrite of existing harness files?" "n"; then
    FORCE=1
  fi
fi

echo
echo "==> Plan"
echo "    magento root:     $TARGET"
echo "    code path:        $CODE_PATH"
echo "    stack:            $STACK_KIND / runtime=$RUNTIME"
echo "    compose dir:      $COMPOSE_DIR"
echo "    php container:    $PHP_CONTAINER"
echo "    runtime m2 root:  $RUNTIME_MAGENTO_ROOT"
echo "    mcp mode:         $MCP_MODE"
echo "    wiring home:      $WIRING_HOME"
echo "    cbm home:         $CBM_HOME"
echo "    force:            $FORCE"
if [[ $INTERACTIVE -eq 1 ]]; then
  ask_yn "Proceed?" "y" || { echo "Aborted."; exit 1; }
fi

sync_dir() {
  local src="$1" dst="$2" label="$3"
  mkdir -p "$dst"
  if [[ $FORCE -eq 1 ]]; then
    rsync -a --delete "$src/" "$dst/"
    note_write "synced (force): $label → $dst"
  elif [[ -d "$dst" ]] && [[ -n "$(ls -A "$dst" 2>/dev/null || true)" ]]; then
    # Fill missing files only; do not delete project customizations
    rsync -a --ignore-existing "$src/" "$dst/"
    note_skip "$label (present; filled gaps only — use --force to refresh)"
  else
    rsync -a "$src/" "$dst/"
    note_write "synced: $label → $dst"
  fi
}

# 1) Cursor payload
mkdir -p "$TARGET/.cursor"
sync_dir "$KIT_ROOT/kit/.cursor/agents" "$TARGET/.cursor/agents" "agents"
mkdir -p "$TARGET/.cursor/rules/modules"
if [[ $FORCE -eq 1 ]]; then
  rsync -a "$KIT_ROOT/kit/.cursor/rules/" "$TARGET/.cursor/rules/"
  note_write "synced rules (force)"
elif [[ -f "$TARGET/.cursor/rules/aheadworks-code-style.mdc" ]]; then
  rsync -a --ignore-existing "$KIT_ROOT/kit/.cursor/rules/" "$TARGET/.cursor/rules/"
  note_skip "rules (present)"
else
  rsync -a "$KIT_ROOT/kit/.cursor/rules/" "$TARGET/.cursor/rules/"
  note_write "synced rules"
fi
mkdir -p "$TARGET/.cursor/skills"
sync_dir "$KIT_ROOT/kit/.cursor/skills" "$TARGET/.cursor/skills" "skills"

# 2) docs harness — never wipe env.local via --delete when not forcing whole tree carefully
mkdir -p "$TARGET/docs"
if [[ $FORCE -eq 1 ]]; then
  # Preserve env.local across force refresh of tools
  env_bak=""
  if [[ -f "$TARGET/docs/_harness/tools/env.local.sh" ]]; then
    env_bak="$(mktemp)"
    cp -a "$TARGET/docs/_harness/tools/env.local.sh" "$env_bak"
  fi
  rsync -a --delete --exclude 'tools/env.local.sh' "$KIT_ROOT/kit/docs/_harness/" "$TARGET/docs/_harness/"
  [[ -n "$env_bak" ]] && mv -f "$env_bak" "$TARGET/docs/_harness/tools/env.local.sh"
  note_write "synced docs/_harness (force, kept env.local)"
elif [[ -f "$TARGET/docs/_harness/WORKFLOW.md" ]]; then
  rsync -a --ignore-existing --exclude 'tools/env.local.sh' "$KIT_ROOT/kit/docs/_harness/" "$TARGET/docs/_harness/"
  note_skip "docs/_harness (present; gaps filled)"
else
  rsync -a --exclude 'tools/env.local.sh' "$KIT_ROOT/kit/docs/_harness/" "$TARGET/docs/_harness/"
  note_write "synced docs/_harness"
fi
mkdir -p "$TARGET/docs/tasks" "$TARGET/docs/_cards"
if [[ ! -f "$TARGET/docs/README.md" ]]; then
  [[ -f "$KIT_ROOT/kit/docs/README.md" ]] && cp -a "$KIT_ROOT/kit/docs/README.md" "$TARGET/docs/README.md"
  note_write "docs/README.md"
else
  note_skip "docs/README.md"
fi

# 3) env.local.sh
render_env_local() {
  sed -e "s|{{AW_RUNTIME}}|$RUNTIME|g" \
      -e "s|{{MAGENTO_CODE_PATH}}|$CODE_PATH|g" \
      -e "s|{{COMPOSE_DIR}}|$COMPOSE_DIR|g" \
      -e "s|{{COMPOSE_PROJECT}}|$COMPOSE_PROJECT|g" \
      -e "s|{{PHP_CONTAINER}}|$PHP_CONTAINER|g" \
      -e "s|{{RUNTIME_MAGENTO_ROOT}}|$RUNTIME_MAGENTO_ROOT|g" \
      -e "s|{{STACK_HINT}}|$STACK_HINT|g" \
      "$KIT_ROOT/kit/docs/_harness/tools/env.local.sh.template"
}
if [[ ! -f "$TARGET/docs/_harness/tools/env.local.sh" || $FORCE -eq 1 ]]; then
  # If force but user chose keep earlier — still rewrite when FORCE
  render_env_local > "$TARGET/docs/_harness/tools/env.local.sh"
  note_write "wrote env.local.sh"
else
  note_skip "env.local.sh"
fi

# 4) AGENTS + ENVIRONMENT
render_file() {
  local in="$1" out="$2"
  sed -e "s|{{MAGENTO_ROOT}}|$TARGET|g" \
      -e "s|{{COMPOSE_DIR}}|$COMPOSE_DIR|g" \
      -e "s|{{COMPOSE_PROJECT}}|$COMPOSE_PROJECT|g" \
      -e "s|{{PHP_CONTAINER}}|$PHP_CONTAINER|g" \
      -e "s|{{MAGENTO_CODE_PATH}}|$CODE_PATH|g" \
      -e "s|{{MAGENTO_VERSION}}|$MAGENTO_VERSION|g" \
      -e "s|{{AW_RUNTIME}}|$RUNTIME|g" \
      -e "s|{{STACK_KIND}}|$STACK_KIND|g" \
      -e "s|{{STACK_HINT}}|$STACK_HINT|g" \
      -e "s|{{RUNTIME_MAGENTO_ROOT}}|$RUNTIME_MAGENTO_ROOT|g" \
      "$in" > "$out"
}

if [[ ! -f "$TARGET/AGENTS.md" || $FORCE -eq 1 ]]; then
  render_file "$KIT_ROOT/kit/AGENTS.md.template" "$TARGET/AGENTS.md"
  note_write "wrote AGENTS.md"
else
  note_skip "AGENTS.md"
fi
# ENVIRONMENT always refreshed to match env.local (cheap, project-local)
render_file "$KIT_ROOT/kit/docs/_harness/ENVIRONMENT.md.template" "$TARGET/docs/_harness/ENVIRONMENT.md"
note_write "wrote ENVIRONMENT.md"

# Ensure CBM binary exists under $1 (download from GitHub releases if kit has no binary).
ensure_cbm_binary() {
  local home="$1"
  local bin="$home/codebase-memory-mcp"
  mkdir -p "$home"
  if [[ -x "$bin" ]]; then
    return 0
  fi
  # Prefer kit-local binary (gitignored, present on maintainer machines)
  if [[ -x "$CBM_SRC/codebase-memory-mcp" ]]; then
    cp -a "$CBM_SRC/codebase-memory-mcp" "$bin"
    chmod +x "$bin"
    note_write "CBM binary copied from kit"
    return 0
  fi
  local arch os asset url tmp
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$os-$arch" in
    linux-x86_64|linux-amd64) asset="codebase-memory-mcp-linux-amd64-portable.tar.gz" ;;
    linux-aarch64|linux-arm64) asset="codebase-memory-mcp-linux-arm64-portable.tar.gz" ;;
    darwin-x86_64|darwin-amd64) asset="codebase-memory-mcp-darwin-amd64.tar.gz" ;;
    darwin-arm64) asset="codebase-memory-mcp-darwin-arm64.tar.gz" ;;
    *)
      echo "    WARN: unsupported platform $os/$arch — place CBM binary at $bin" >&2
      return 1
      ;;
  esac
  url="${CBM_DOWNLOAD_URL:-https://github.com/DeusData/codebase-memory-mcp/releases/latest/download}/${asset}"
  tmp="$(mktemp -d)"
  echo "    downloading CBM ($asset)…"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$tmp/$asset" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp/$asset" "$url"
  else
    echo "    WARN: curl/wget missing — cannot download CBM" >&2
    rm -rf "$tmp"
    return 1
  fi
  tar -xzf "$tmp/$asset" -C "$tmp"
  # tarball usually contains the binary at top level or in a subdir
  if [[ -x "$tmp/codebase-memory-mcp" ]]; then
    cp -a "$tmp/codebase-memory-mcp" "$bin"
  else
    found="$(find "$tmp" -type f -name 'codebase-memory-mcp' | head -1 || true)"
    if [[ -n "$found" ]]; then
      cp -a "$found" "$bin"
    else
      echo "    WARN: CBM binary not found inside $asset" >&2
      rm -rf "$tmp"
      return 1
    fi
  fi
  chmod +x "$bin"
  rm -rf "$tmp"
  # Keep LICENSE/notices from kit when present
  rsync -a --ignore-existing --exclude 'codebase-memory-mcp' "$CBM_SRC/" "$home/" 2>/dev/null || true
  note_write "CBM binary downloaded → $bin"
}

# 5) MCP payloads
if [[ "$MCP_MODE" == "reuse" ]]; then
  note_reuse "wiring+CBM at $MCP_REUSE_FROM (no copy)"
elif [[ "$MCP_MODE" == "shared" ]]; then
  if mcp_parent_usable "$(dirname "$WIRING_HOME")" && [[ $FORCE -eq 0 ]]; then
    note_skip "shared MCP already at $(dirname "$WIRING_HOME")"
  else
    mkdir -p "$(dirname "$WIRING_HOME")" "$(dirname "$CBM_HOME")"
    rsync -a --exclude '.venv' --exclude '__pycache__' --exclude '*.egg-info' --exclude '.git' \
      "$WIRING_SRC/" "$WIRING_HOME/"
    rsync -a --exclude 'codebase-memory-mcp' "$CBM_SRC/" "$CBM_HOME/"
    ensure_cbm_binary "$CBM_HOME" || true
    note_write "shared MCP → $(dirname "$WIRING_HOME")"
  fi
else
  # project mode
  if mcp_parent_usable "$TARGET/.harness/mcp" && [[ $FORCE -eq 0 ]]; then
    note_skip "project .harness/mcp (already installed)"
  else
    mkdir -p "$(dirname "$WIRING_HOME")" "$(dirname "$CBM_HOME")"
    if [[ $FORCE -eq 1 ]]; then
      rsync -a --delete --exclude '.venv' --exclude '__pycache__' --exclude '*.egg-info' --exclude '.git' \
        "$WIRING_SRC/" "$WIRING_HOME/"
      rsync -a --delete --exclude 'codebase-memory-mcp' "$CBM_SRC/" "$CBM_HOME/"
    else
      rsync -a --exclude '.venv' --exclude '__pycache__' --exclude '*.egg-info' --exclude '.git' \
        "$WIRING_SRC/" "$WIRING_HOME/"
      rsync -a --exclude 'codebase-memory-mcp' "$CBM_SRC/" "$CBM_HOME/"
    fi
    ensure_cbm_binary "$CBM_HOME" || true
    note_write "project MCP → $TARGET/.harness/mcp"
  fi
fi

WIRING_BIN="$(wiring_bin_for "$WIRING_HOME")"
CBM_BIN="$(cbm_bin_for "$CBM_HOME")"

if [[ $SKIP_VENV -eq 0 ]]; then
  if [[ -x "$WIRING_BIN" ]]; then
    note_skip "wiring venv ($WIRING_BIN)"
  else
    echo "    creating wiring venv (python3)…"
    python3 -m venv "$WIRING_HOME/.venv"
    "$WIRING_HOME/.venv/bin/pip" -q install -U pip
    "$WIRING_HOME/.venv/bin/pip" -q install -e "$WIRING_HOME"
    note_write "wiring venv ready"
  fi
fi

# 6) mcp.json — always rewrite paths for THIS Magento root (cheap, correct)
mkdir -p "$TARGET/.cursor"
NEED_MCP_JSON=1
if [[ -f "$TARGET/.cursor/mcp.json" && $FORCE -eq 0 ]]; then
  # Keep if it already points at the chosen WIRING_BIN and same MAGENTO_ROOT
  if grep -qF "$WIRING_BIN" "$TARGET/.cursor/mcp.json" 2>/dev/null && grep -qF "$TARGET" "$TARGET/.cursor/mcp.json" 2>/dev/null; then
    note_skip ".cursor/mcp.json (already points at chosen wiring + this root)"
    NEED_MCP_JSON=0
  fi
fi
if [[ $NEED_MCP_JSON -eq 1 ]]; then
  sed -e "s|{{WIRING_MCP_BIN}}|$WIRING_BIN|g" \
      -e "s|{{MAGENTO_ROOT}}|$TARGET|g" \
      -e "s|{{MAGENTO_CODE_PATH}}|$CODE_PATH|g" \
      "$KIT_ROOT/kit/.cursor/mcp.json.template" > "$TARGET/.cursor/mcp.json"
  note_write "wrote .cursor/mcp.json → $WIRING_BIN"
fi

sed -e "s|{{CBM_BIN}}|$CBM_BIN|g" \
    "$KIT_ROOT/kit/mcp.user.json.template" > "$TARGET/.cursor/mcp.user-codebase-memory.snippet.json"

USER_MCP="${HOME}/.cursor/mcp.json"
merge_user_cbm_mcp() {
  local user_mcp="$1" snippet="$2" force_update="$3"
  python3 - "$user_mcp" "$snippet" "$force_update" <<'PY'
import json, sys
user_path, snippet_path, force = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
with open(snippet_path, encoding="utf-8") as f:
    snip = json.load(f)
servers = snip.get("mcpServers") or {}
if not servers:
    print("empty-snippet")
    raise SystemExit(0)
try:
    with open(user_path, encoding="utf-8") as f:
        user = json.load(f)
except FileNotFoundError:
    user = {}
if not isinstance(user, dict):
    print("invalid-user-mcp")
    raise SystemExit(2)
user.setdefault("mcpServers", {})
if not isinstance(user["mcpServers"], dict):
    print("invalid-user-mcp")
    raise SystemExit(2)
changed = False
for name, cfg in servers.items():
    if name not in user["mcpServers"]:
        user["mcpServers"][name] = cfg
        changed = True
    elif force and user["mcpServers"].get(name) != cfg:
        user["mcpServers"][name] = cfg
        changed = True
if not changed:
    print("unchanged")
    raise SystemExit(0)
with open(user_path, "w", encoding="utf-8") as f:
    json.dump(user, f, indent=2)
    f.write("\n")
print("merged")
PY
}
if [[ ! -f "$USER_MCP" ]]; then
  mkdir -p "$(dirname "$USER_MCP")"
  cp -a "$TARGET/.cursor/mcp.user-codebase-memory.snippet.json" "$USER_MCP"
  note_write "created $USER_MCP"
else
  merge_rc=0
  merge_out="$(merge_user_cbm_mcp "$USER_MCP" "$TARGET/.cursor/mcp.user-codebase-memory.snippet.json" "$FORCE")" || merge_rc=$?
  case "$merge_out" in
    merged) note_write "merged codebase-memory-mcp into $USER_MCP" ;;
    unchanged) note_skip "user ~/.cursor/mcp.json already has codebase-memory-mcp" ;;
    *)
      echo "    WARN: could not auto-merge CBM into $USER_MCP (rc=$merge_rc out=$merge_out)"
      echo "    Merge manually from .cursor/mcp.user-codebase-memory.snippet.json"
      ;;
  esac
fi

# 7) gitignore
if [[ -f "$TARGET/.gitignore" ]]; then
  if ! grep -q '.harness/' "$TARGET/.gitignore" 2>/dev/null; then
    {
      echo ""
      echo "# aw-harness local MCP / caches"
      echo ".harness/mcp/**/.venv/"
      echo ".harness/phpunit/"
    } >> "$TARGET/.gitignore"
    note_write "updated .gitignore"
  else
    note_skip ".gitignore harness entries"
  fi
fi

# 8) Best-effort CBM indexes (non-fatal)
CBM_ENSURE="$TARGET/docs/_harness/tools/cbm-ensure-index.sh"
if [[ -x "$CBM_ENSURE" && -x "$CBM_BIN" ]]; then
  echo "==> Ensuring CBM indexes ($CODE_PATH + docs)…"
  if ( cd "$TARGET" && CBM_BIN="$CBM_BIN" "$CBM_ENSURE" ); then
    note_write "CBM ensure-index ok"
  else
    echo "    WARN: cbm-ensure-index failed (non-fatal). Run later: docs/_harness/tools/cbm-ensure-index.sh"
  fi
else
  note_skip "CBM ensure-index (script or binary missing)"
fi

cat > "$TARGET/docs/_harness/status.md" <<EOF
# Harness status

- installed: aw-harness **${VERSION}**
- date: $(date -Iseconds)
- magento_root: \`$TARGET\`
- code_path: \`$CODE_PATH\`
- stack: \`$STACK_KIND\` / runtime=\`$RUNTIME\`
- php: \`$PHP_CONTAINER\` (in-runtime root \`$RUNTIME_MAGENTO_ROOT\`)
- wiring_mcp: \`$WIRING_BIN\`
- cbm: \`$CBM_BIN\`
- mcp_mode: \`$MCP_MODE\`
- mcp_home: \`$WIRING_HOME\` / \`$CBM_HOME\`
- wrote: ${WROTE} · skipped: ${SKIPPED} · reused: ${REUSED} · force: ${FORCE}
EOF

echo
echo "==> Done (wrote=$WROTE skipped=$SKIPPED reused=$REUSED)."
echo "    1) Reload Cursor MCP (Command Palette → reload MCP / restart Cursor)"
echo "    2) If CBM indexes were skipped: docs/_harness/tools/cbm-ensure-index.sh"
echo "    3) Gates: docs/_harness/tools/gates.sh <Module>"
echo "    4) Work: /aw-task  |  /aw-document-module  |  /aw-cbm-ensure-index"
