#!/usr/bin/env bash
# Push host files into the PHP runtime. Bind-mounted paths are skipped (same inode).
# Host runtime: no-op (single tree).
#
# Usage:
#   sync.sh --files <path> [<path> ...]
#   sync.sh --module <Module> [--mirror]

source "$(dirname "$0")/env.sh"

mode="${1:-}"; shift || true
aw_require_container

if [[ "$AW_RUNTIME" == "host" ]]; then
  echo "host runtime — nothing to sync (single Magento tree at $AW_PROJECT_ROOT)"
  exit 0
fi

case "$mode" in
    --files)
        [[ $# -gt 0 ]] || aw_die "no files given"
        for rel in "$@"; do
            rel="${rel#./}"
            if [[ -f "$AW_PROJECT_ROOT/$rel" ]]; then
                if aw_is_shared "$rel"; then
                    echo "shared    $rel (bind mount, no copy)"
                else
                    aw_push_file "$AW_PROJECT_ROOT/$rel" "$AW_MAGENTO_ROOT/$rel"
                    echo "uploaded  $rel"
                fi
            elif [[ ! -e "$AW_PROJECT_ROOT/$rel" ]]; then
                docker exec "$AW_CONTAINER" rm -f "$AW_MAGENTO_ROOT/$rel"
                echo "deleted   $rel"
            else
                aw_die "$rel is not a regular file"
            fi
        done
        ;;
    --module)
        module="${1:-}"; shift || true
        aw_require_module "$module"
        if aw_is_shared "$AW_MODULES_REL/$module"; then
            echo "shared    $AW_MODULES_REL/$module (bind mount, no copy)"
            exit 0
        fi
        mirror="${1:-}"
        if [[ "$mirror" == "--mirror" ]]; then
            while IFS= read -r rel; do
                docker exec "$AW_CONTAINER" rm -f "$AW_MAGENTO_ROOT/$rel"
                echo "deleted   $rel"
            done < <("$AW_TOOLS_DIR/drift.sh" "$module" | awk '/^--- only_cont/{f=1;next} /^---/{f=0} f')
        fi
        tar -C "$AW_PROJECT_ROOT/$AW_MODULES_REL" --exclude=.git --exclude=.idea -cf - "$module" \
            | docker exec -i "$AW_CONTAINER" tar -o -xf - -C "$AW_MAGENTO_ROOT/$AW_MODULES_REL"
        echo "uploaded  $AW_MODULES_REL/$module"
        ;;
    *)
        sed -n '2,10p' "$0"; exit 2 ;;
esac

echo "Reminder: after di.xml / constructor / db_schema changes run the matching commands from docs/_harness/ENVIRONMENT.md"
