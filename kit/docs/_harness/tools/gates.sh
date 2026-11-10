#!/usr/bin/env bash
# Local quality gates for one module (mirrors module CI). Runs via aw_exec:
# docker PHP container or host PHP (AW_RUNTIME in env.local.sh).
#
# Usage: gates.sh <Module> [--files <path>...] [--di] [--no-unit] [--verbose] [--report <host-file.md>]
#   --files   changed files (project-relative): php -l + informational phpcs (severity 5) on them
#   --di      also run bin/magento setup:di:compile (CI "install Magento" step; ~5-10 min)
#   --no-unit skip PHPUnit
#   --verbose print the last 60 lines of every gate in the tools' default formats
#             (default: PASS = one line, FAIL = only the reported problems, one per line)
#   --report  append a markdown report to this host file (e.g. docs/tasks/<ID>/05_test_report.md)
#
# Blocking gates (same commands/levels as CI): phpcs Magento2 severity 9, phpstan level 0,
# PHPUnit Test/Unit, optional di:compile. Exit 0 only if every blocking gate passed.

source "$(dirname "$0")/env.sh"

module="${1:-}"; shift || true
aw_require_module "$module"
aw_require_container

files=(); run_di=0; run_unit=1; report=""; verbose=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --files) shift; while [[ $# -gt 0 && "$1" != --* ]]; do files+=("${1#./}"); shift; done ;;
        --di) run_di=1; shift ;;
        --no-unit) run_unit=0; shift ;;
        --verbose) verbose=1; shift ;;
        --report) report="$2"; shift 2 ;;
        *) aw_die "unknown option $1" ;;
    esac
done

mod_rel="$AW_MODULES_REL/$module"
results=()
failed=0
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

phpcs_report=emacs; stan_format=raw
[[ $verbose -eq 1 ]] && { phpcs_report=full; stan_format=table; }

# Prints the problems of a failed gate. Filters: list (one problem per line, from the top), phpunit, tail.
# `|| true`: env.sh sets -e/pipefail, and head closing the pipe early must not abort the run.
print_failure() {
    case "$1" in
        list) { grep -v '^\s*$' "$log" | head -n 40; } || true ;;
        phpunit)
            if grep -qE '^There (was|were) [0-9]+ (failure|error)' "$log"; then
                { awk '/^There (was|were) [0-9]+ (failure|error)/{p=1} p' "$log" | head -n 60; } || true
                tail -n 3 "$log"
            else
                tail -n 30 "$log"
            fi ;;
        *) tail -n 20 "$log" ;;
    esac
}

gate() {
    local name="$1" blocking="$2" filter="$3"; shift 3
    local rc=0 note=""
    "$@" > "$log" 2>&1 || rc=$?
    if [[ "$filter" == "phpunit" ]]; then
        note="$( { grep -Eo 'OK \([0-9]+ tests?, [0-9]+ assertions?\)|Tests: [0-9]+, Assertions: [0-9]+[^.]*' "$log" | tail -n 1; } || true)"
    fi
    if [[ $verbose -eq 1 ]]; then
        echo "=== $name"
        tail -n 60 "$log"
    elif [[ $rc -eq 0 ]]; then
        echo "=== $name: PASS${note:+ — $note}"
    else
        echo "=== $name: exit $rc"
        print_failure "$filter"
    fi
    if [[ $rc -eq 0 ]]; then
        results+=("| $name | PASS${note:+ ($note)} |")
    elif [[ "$blocking" == "1" ]]; then
        results+=("| $name | **FAIL** (exit $rc)${note:+ ($note)} |"); failed=1
    else
        results+=("| $name | WARN (exit $rc, informational) |")
    fi
}

drift_state="identical"
"$AW_TOOLS_DIR/drift.sh" "$module" > "$log" 2>&1 || drift_state="DRIFT (see drift.sh $module)"
results+=("| host/container drift | $drift_state |")

php_files=()
for f in "${files[@]}"; do
    [[ "$f" == *.php || "$f" == *.phtml ]] && [[ -f "$AW_PROJECT_ROOT/$f" ]] && php_files+=("$f")
done
if [[ ${#php_files[@]} -gt 0 ]]; then
    _aw_php_lint() {
        local f
        for f in "$@"; do
            aw_exec php -l "$f" || return 1
        done
    }
    gate "php -l (changed files)" 1 tail _aw_php_lint "${php_files[@]}"
    gate "phpcs severity 5 (changed files, informational)" 0 list \
        aw_exec vendor/bin/phpcs --standard=Magento2 --extensions=php,phtml --severity=5 --report="$phpcs_report" "${php_files[@]}"
fi

gate "phpcs Magento2 severity 9 (CI)" 1 list \
    aw_exec vendor/bin/phpcs "$mod_rel" --severity=9 --standard=Magento2 --extensions=php,phtml --report="$phpcs_report"

stan_cfg=()
[[ -f "$AW_PROJECT_ROOT/$mod_rel/phpstan.neon" ]] && stan_cfg=(--configuration "$mod_rel/phpstan.neon")
gate "phpstan level 0 (CI)" 1 list \
    aw_exec php -d memory_limit=-1 vendor/bin/phpstan analyse "$mod_rel" "${stan_cfg[@]}" --level 0 \
    --autoload-file dev/tests/integration/framework/autoload.php --no-progress --error-format="$stan_format"

is_hyva=0
# CI: jq '.require' | grep hyva-themes/ — only "require" counts, "suggest" does not
python3 -c 'import json,sys; sys.exit(0 if any(k.startswith("hyva-themes/") for k in json.load(open(sys.argv[1])).get("require", {})) else 1)' \
    "$AW_PROJECT_ROOT/$mod_rel/composer.json" 2>/dev/null && is_hyva=1
if [[ $run_unit -eq 1 && $is_hyva -eq 0 && -d "$AW_PROJECT_ROOT/$mod_rel/Test/Unit" ]]; then
    aw_push_phpunit_harness
    gate "phpunit Test/Unit (CI)" 1 phpunit \
        aw_exec php vendor/bin/phpunit -c "$AW_HARNESS_TMP/phpunit.xml" "$mod_rel/Test/Unit"
else
    results+=("| phpunit Test/Unit | SKIPPED (no tests / Hyva module / --no-unit) |")
fi

if [[ $run_di -eq 1 ]]; then
    gate "bin/magento setup:di:compile (CI install step)" 1 tail aw_exec php -d memory_limit=-1 bin/magento setup:di:compile
fi

summary="$(printf '%s\n' "## Quality gates: $module ($(date '+%Y-%m-%d %H:%M'))" "" "| Gate | Result |" "|---|---|" "${results[@]}")"
echo; echo "$summary"
if [[ -n "$report" ]]; then
    mkdir -p "$(dirname "$AW_PROJECT_ROOT/$report")"
    printf '\n%s\n' "$summary" >> "$AW_PROJECT_ROOT/$report"
    echo "Report appended to $report"
fi
exit $failed
