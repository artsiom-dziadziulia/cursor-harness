#!/usr/bin/env bash
# Compare a module on the host with the PHP runtime tree.
# Bind-mounted app/code → identical. Host runtime → always identical (single tree).
# Usage: drift.sh <Module>
# Exit codes: 0 = identical, 1 = drift found, 2 = usage/environment error.

source "$(dirname "$0")/env.sh"
export LC_ALL=C

module="${1:-}"
aw_require_module "$module"
aw_require_container

if [[ "$AW_RUNTIME" == "host" ]]; then
  echo "Drift for $module (host runtime — single tree): identical"
  exit 0
fi

host_dir="$AW_PROJECT_ROOT/$AW_MODULES_REL/$module"
cont_dir="$AW_MAGENTO_ROOT/$AW_MODULES_REL/$module"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

to_tsv() { sed -E 's/^([0-9a-f]{32})  (.*)$/\2\t\1/'; }
(cd "$host_dir" && find . -type f ! -path './.git/*' ! -path './.idea/*' -print0 | xargs -0 -r md5sum) \
    | to_tsv | sort -t $'\t' -k1,1 > "$tmp/host"
docker exec "$AW_CONTAINER" sh -c "[ -d '$cont_dir' ] && cd '$cont_dir' && find . -type f ! -path './.git/*' ! -path './.idea/*' -exec md5sum {} +" \
    | to_tsv | sort -t $'\t' -k1,1 > "$tmp/cont" || true

join -t $'\t' -j1 -v1 <(cut -f1 "$tmp/host") <(cut -f1 "$tmp/cont") > "$tmp/only_host" || true
join -t $'\t' -j1 -v1 <(cut -f1 "$tmp/cont") <(cut -f1 "$tmp/host") > "$tmp/only_cont" || true
join -t $'\t' -j1 "$tmp/host" "$tmp/cont" | awk -F'\t' '$2 != $3 {print $1}' > "$tmp/changed"

n_host=$(wc -l < "$tmp/only_host"); n_cont=$(wc -l < "$tmp/only_cont"); n_chg=$(wc -l < "$tmp/changed")
echo "Drift for $module (host vs $AW_CONTAINER):"
echo "  differs:              $n_chg"
echo "  only on host:         $n_host   (not uploaded yet)"
echo "  only in container:    $n_cont   (deleted on host, still present in container)"
for kind in changed only_host only_cont; do
    if [[ -s "$tmp/$kind" ]]; then
        echo "--- $kind"
        sed "s#^\./#$AW_MODULES_REL/$module/#" "$tmp/$kind"
    fi
done

[[ $((n_host + n_cont + n_chg)) -eq 0 ]]
