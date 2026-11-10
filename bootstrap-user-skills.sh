#!/usr/bin/env bash
# One-time: put /aw-harness-init and /aw-harness-pack into the developer's
# user-level Cursor skills so they work in ANY project (even before harness install).
# Also installs harness-install / harness-pack wrappers into ~/.local/bin when possible.
#
# Usage:
#   /path/to/aw-harness/bootstrap-user-skills.sh
#   AW_HARNESS_KIT=/path/to/aw-harness ./bootstrap-user-skills.sh
#   ./bootstrap-user-skills.sh --no-path   # skip ~/.local/bin symlinks
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
KIT_ROOT="${AW_HARNESS_KIT:-$KIT_ROOT}"
DEST="${HOME}/.cursor/skills"
INSTALL_PATH=1
[[ "${1:-}" == "--no-path" ]] && INSTALL_PATH=0

mkdir -p "$DEST"
for S in aw-harness-init aw-harness-pack; do
  src="$KIT_ROOT/kit/.cursor/skills/$S"
  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "ERROR: missing $src/SKILL.md — is this a full aw-harness kit?" >&2
    exit 1
  fi
  mkdir -p "$DEST/$S"
  rsync -a "$src/" "$DEST/$S/"
  echo "    installed ~/.cursor/skills/$S"
done

# Remember kit location for agents (optional hint file)
echo "$KIT_ROOT" > "$DEST/aw-harness-init/KIT_ROOT.txt"
echo "$KIT_ROOT" > "$DEST/aw-harness-pack/KIT_ROOT.txt"

if [[ $INSTALL_PATH -eq 1 ]]; then
  BIN_DIR="${HOME}/.local/bin"
  mkdir -p "$BIN_DIR"
  for wrap in harness-install harness-pack; do
    src="$KIT_ROOT/scripts/$wrap"
    if [[ ! -x "$src" ]]; then
      echo "    WARN: missing $src — skip PATH wrapper"
      continue
    fi
    ln -sfn "$src" "$BIN_DIR/$wrap"
    echo "    linked $BIN_DIR/$wrap → $src"
  done
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      echo
      echo "    NOTE: $BIN_DIR is not on PATH. Add to ~/.bashrc:"
      echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
      ;;
  esac
fi

echo
echo "==> Done. Restart Cursor or reload skills, then in any Magento project:"
echo "    /aw-harness-init"
echo "    or: harness-install --target /path/to/magento-root"
echo "    Kit path recorded: $KIT_ROOT"
