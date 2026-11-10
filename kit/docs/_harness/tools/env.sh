#!/usr/bin/env bash
# Shared settings for harness tools. Source it: `source "$(dirname "$0")/env.sh"`.
# Override via environment or docs/_harness/tools/env.local.sh (written by aw-harness-init).

set -euo pipefail

AW_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AW_PROJECT_ROOT="$(cd "$AW_TOOLS_DIR/../../.." && pwd)"

# Optional project overrides (portable across markshust / pystacker / host)
if [[ -f "$AW_TOOLS_DIR/env.local.sh" ]]; then
  # shellcheck disable=SC1091
  source "$AW_TOOLS_DIR/env.local.sh"
fi

# Defaults match classic Mark Shust layout (src/ + parent compose project) when env.local.sh is absent
AW_RUNTIME="${AW_RUNTIME:-docker}"
AW_MODULES_REL="${AW_MODULES_REL:-app/code/Aheadworks}"
AW_COMPOSE_DIR="${AW_COMPOSE_DIR:-$(dirname "$AW_PROJECT_ROOT")}"
AW_COMPOSE_PROJECT="${AW_COMPOSE_PROJECT:-$(basename "$AW_COMPOSE_DIR")}"
AW_CONTAINER="${AW_CONTAINER:-${AW_COMPOSE_PROJECT}-phpfpm-1}"
AW_MAGENTO_ROOT_IN_RUNTIME="${AW_MAGENTO_ROOT_IN_RUNTIME:-/var/www/html}"
# Back-compat alias used by drift/sync/gates
AW_MAGENTO_ROOT="${AW_MAGENTO_ROOT:-$AW_MAGENTO_ROOT_IN_RUNTIME}"
AW_STACK_HINT="${AW_STACK_HINT:-}"

if [[ "$AW_RUNTIME" == "host" ]]; then
  AW_HARNESS_TMP="${AW_HARNESS_TMP:-$AW_PROJECT_ROOT/.harness/phpunit}"
  AW_MAGENTO_ROOT="${AW_MAGENTO_ROOT:-$AW_PROJECT_ROOT}"
  AW_MAGENTO_ROOT_IN_RUNTIME="${AW_MAGENTO_ROOT_IN_RUNTIME:-$AW_PROJECT_ROOT}"
else
  AW_HARNESS_TMP="${AW_HARNESS_TMP:-/tmp/aw-harness}"
fi

aw_die() { echo "ERROR: $*" >&2; exit 2; }

aw_require_container() {
  [[ "$AW_RUNTIME" == "host" ]] && return 0
  local state
  state="$(docker inspect -f '{{.State.Running}}' "$AW_CONTAINER" 2>/dev/null || true)"
  if [[ "$state" != "true" ]]; then
    local hint="$AW_STACK_HINT"
    [[ -z "$hint" && -n "$AW_COMPOSE_DIR" ]] && hint="from $AW_COMPOSE_DIR start your PHP container ($AW_CONTAINER)"
    aw_die "runtime '$AW_CONTAINER' is not running. ${hint}"
  fi
}

# True when the host path and the container path are the same inode (bind mount).
aw_is_shared() {
  local rel="$1" remote host_path="$AW_PROJECT_ROOT/$rel"
  [[ "$AW_RUNTIME" == "host" ]] && return 0
  [[ -e "$host_path" ]] || return 1
  remote="$(docker exec "$AW_CONTAINER" stat -c '%d:%i' "$AW_MAGENTO_ROOT/$rel" 2>/dev/null || true)"
  [[ -n "$remote" && "$remote" == "$(stat -c '%d:%i' "$host_path")" ]]
}

aw_exec() {
  if [[ "$AW_RUNTIME" == "host" ]]; then
    (
      cd "$AW_PROJECT_ROOT"
      env XDEBUG_MODE=off "$@"
    )
  else
    aw_require_container
    docker exec -e XDEBUG_MODE=off -w "$AW_MAGENTO_ROOT" "$AW_CONTAINER" "$@"
  fi
}

aw_require_module() {
  local module="$1"
  [[ -n "$module" ]] || aw_die "module name is required (directory under $AW_MODULES_REL)"
  [[ -d "$AW_PROJECT_ROOT/$AW_MODULES_REL/$module" ]] || aw_die "unknown module '$module' (expected $AW_PROJECT_ROOT/$AW_MODULES_REL/$module)"
}

aw_push_file() {
  local host_path="$1" dest_path="$2"
  if [[ "$AW_RUNTIME" == "host" ]]; then
    mkdir -p "$(dirname "$dest_path")"
    cp -a "$host_path" "$dest_path"
    return 0
  fi
  docker exec "$AW_CONTAINER" mkdir -p "$(dirname "$dest_path")"
  docker exec -i "$AW_CONTAINER" sh -c "cat > '$dest_path'" < "$host_path"
}

aw_push_phpunit_harness() {
  local f
  if [[ "$AW_RUNTIME" == "host" ]]; then
    mkdir -p "$AW_HARNESS_TMP"
    for f in bootstrap.php phpunit.xml MockCreationTrait.php; do
      cp -a "$AW_TOOLS_DIR/phpunit/$f" "$AW_HARNESS_TMP/$f"
    done
    return 0
  fi
  docker exec "$AW_CONTAINER" mkdir -p "$AW_HARNESS_TMP"
  for f in bootstrap.php phpunit.xml MockCreationTrait.php; do
    aw_push_file "$AW_TOOLS_DIR/phpunit/$f" "$AW_HARNESS_TMP/$f"
  done
}
