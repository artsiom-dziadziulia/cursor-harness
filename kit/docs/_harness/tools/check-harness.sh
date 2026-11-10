#!/usr/bin/env bash
# Self-check of the harness: module documentation coverage, module rules, links and referenced rule files.
# Runs on the host (bash + python3), does not touch the container.
# Usage: check-harness.sh [--strict]
#   --strict  treat undocumented modules as errors (default: reported as pending)
# Exit codes: 0 = OK, 1 = errors found.

set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

REQUIRED_FILES="README.md AGENTS.md ARCHITECTURE.md DATABASE.md CONFIGURATION.md INTEGRATIONS.md FRONTEND.md TESTING.md KNOWN_ISSUES.md"
errors=0
documented=0
partial=0
pending=0
total=0
pending_list=""

kebab() { echo "$1" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr 'A-Z' 'a-z'; }

echo "== Module documentation coverage"
for dir in "$ROOT"/app/code/Aheadworks/*/; do
    module="$(basename "$dir")"
    total=$((total + 1))
    doc_dir="$ROOT/docs/$module"
    rule="$ROOT/.cursor/rules/modules/$(kebab "$module").mdc"
    if [ ! -d "$doc_dir" ]; then
        pending=$((pending + 1))
        pending_list="$pending_list $module"
        continue
    fi
    missing=""
    for f in $REQUIRED_FILES; do
        [ -f "$doc_dir/$f" ] || missing="$missing $f"
    done
    rule_problem=""
    if [ ! -f "$rule" ]; then
        rule_problem="rule missing: ${rule#$ROOT/}"
    elif ! grep -q "docs/$module/AGENTS.md" "$rule"; then
        rule_problem="rule does not point to docs/$module/AGENTS.md"
    elif grep -q "^@docs/" "$rule"; then
        rule_problem="rule @-includes docs (loads AGENTS.md twice) — use a plain path"
    elif ! grep -q "globs: app/code/Aheadworks/$module/\*\*" "$rule"; then
        rule_problem="rule globs do not match app/code/Aheadworks/$module/**"
    fi
    fresh=""
    if [ -f "$doc_dir/README.md" ] && ! grep -q "Актуально на:" "$doc_dir/README.md"; then
        fresh="README.md has no 'Актуально на:' header"
    fi
    if [ -z "$missing" ] && [ -z "$rule_problem" ] && [ -z "$fresh" ]; then
        documented=$((documented + 1))
        echo "  OK       $module"
    else
        partial=$((partial + 1))
        errors=$((errors + 1))
        echo "  PARTIAL  $module${missing:+ | missing:$missing}${rule_problem:+ | $rule_problem}${fresh:+ | $fresh}"
    fi
done
echo "  documented: $documented / $total, partial: $partial, pending: $pending"
[ -n "$pending_list" ] && echo "  pending:$pending_list"
if [ "$STRICT" = 1 ] && [ "$pending" -gt 0 ]; then
    errors=$((errors + pending))
fi

echo
echo "== Links and referenced rules"
python3 - "$ROOT" <<'PY'
import os, re, sys, unicodedata

root = sys.argv[1]
scan_roots = [
    "AGENTS.md",
    "docs/README.md",
    "docs/_harness",
    "docs/tasks",
    ".cursor/agents/00-harness",
    ".cursor/rules/modules",
    ".cursor/skills",
]
scan_roots += [os.path.join("docs", d) for d in sorted(os.listdir(os.path.join(root, "docs")))
               if os.path.isdir(os.path.join(root, "app/code/Aheadworks", d))]

files = []
for rel in scan_roots:
    p = os.path.join(root, rel)
    if os.path.isfile(p):
        files.append(p)
    elif os.path.isdir(p):
        for dp, _, fns in os.walk(p):
            files += [os.path.join(dp, f) for f in fns if f.endswith((".md", ".mdc"))]

def slugify(text):
    text = re.sub(r"`([^`]*)`", r"\1", text).strip().lower()
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE)
    return text.replace(" ", "-")

anchor_cache = {}
def anchors(path):
    if path not in anchor_cache:
        seen, result = {}, set()
        in_code = False
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.lstrip().startswith("```"):
                    in_code = not in_code
                    continue
                m = None if in_code else re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
                if m:
                    s = slugify(m.group(2))
                    n = seen.get(s, 0)
                    result.add(s if n == 0 else f"{s}-{n}")
                    seen[s] = n + 1
        anchor_cache[path] = result
    return anchor_cache[path]

link_re = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)\)")
rule_re = re.compile(r"(\.cursor/rules/[\w./-]+\.mdc)")
include_re = re.compile(r"^@([\w./-]+)\s*$", re.M)

modules = set(os.listdir(os.path.join(root, "app/code/Aheadworks")))
docs_root = os.path.join(root, "docs")

def pending_module_link(dest):
    rel = os.path.relpath(dest, docs_root)
    head = rel.split(os.sep)[0]
    return head in modules and not os.path.isdir(os.path.join(docs_root, head))

broken = []
pending_links = 0
for f in sorted(set(files)):
    rel_f = os.path.relpath(f, root)
    with open(f, encoding="utf-8") as fh:
        content = fh.read()
    stripped = re.sub(r"```.*?```", "", content, flags=re.S)
    for target in link_re.findall(stripped):
        if re.match(r"^[a-z]+://|^mailto:", target):
            continue
        path_part, _, anchor = target.partition("#")
        if path_part:
            dest = os.path.normpath(os.path.join(os.path.dirname(f), path_part))
            if not os.path.exists(dest):
                if pending_module_link(dest):
                    pending_links += 1
                else:
                    broken.append(f"{rel_f}: link -> {target} (file not found)")
                continue
        else:
            dest = f
        if anchor and dest.endswith((".md", ".mdc")) and os.path.isfile(dest):
            if anchor not in anchors(dest):
                broken.append(f"{rel_f}: link -> {target} (anchor not found)")
    for ref in set(rule_re.findall(content)):
        if "<" in ref or "*" in ref:
            continue
        if not os.path.exists(os.path.join(root, ref)):
            broken.append(f"{rel_f}: referenced rule {ref} does not exist")
    if f.endswith(".mdc"):
        for inc in include_re.findall(content):
            if not os.path.exists(os.path.join(root, inc)):
                broken.append(f"{rel_f}: @include {inc} does not exist")

print(f"  scanned files: {len(set(files))}")
print(f"  links to not-yet-documented modules (pending, not errors): {pending_links}")
if broken:
    print(f"  broken: {len(broken)}")
    for b in broken:
        print(f"    {b}")
    sys.exit(1)
print("  broken: 0")
PY
[ $? -ne 0 ] && errors=$((errors + 1))

echo
echo "== Task status size (warning only: status.md is a dashboard, history belongs in journal.md)"
oversized=0
for status in "$ROOT"/docs/tasks/*/status.md; do
    [ -f "$status" ] || continue
    lines=$(wc -l < "$status"); chars=$(wc -m < "$status")
    if [ "$lines" -gt 80 ] || [ "$chars" -gt 12000 ]; then
        oversized=$((oversized + 1))
        echo "  WARN  ${status#$ROOT/}: $lines lines, $chars chars (limit 80 / 12000)"
    fi
done
[ "$oversized" -eq 0 ] && echo "  OK"

echo
if [ "$errors" -gt 0 ]; then
    echo "RESULT: FAIL ($errors problem group(s))"
    exit 1
fi
echo "RESULT: OK"
