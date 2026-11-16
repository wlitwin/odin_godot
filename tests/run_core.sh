#!/usr/bin/env bash
# Component selection only; run_all owns execution, limits, logs, and reporting.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
component=all
component_set=0
unit=0
list=0
for argument in "$@"; do
    case "$argument" in
        bridge|kit|replay|utilities|all)
            if [[ "$component_set" == 1 ]]; then
                echo 'run_core: choose one component' >&2; exit 2
            fi
            component="$argument"; component_set=1 ;;
        --unit) unit=1 ;;
        --list) list=1 ;;
        *) echo 'Usage: bash tests/run_core.sh [bridge|kit|replay|utilities|all] [--unit] [--list]' >&2; exit 2 ;;
    esac
done

checks=()
known='|'
count=0
while IFS=$'\t' read -r group name needs_godot extra; do
    [[ -n "$group" && "$group" != \#* ]] || continue
    case "$group" in bridge|kit|replay|utilities) ;; *) echo "run_core: invalid component: $group" >&2; exit 2 ;; esac
    if [[ ! "$name" =~ ^[a-zA-Z0-9_]+$ || ! "$needs_godot" =~ ^[01]$ || -n "${extra:-}" ]]; then
        echo "run_core: invalid core row: $group $name $needs_godot" >&2; exit 2
    fi
    if [[ "$known" == *"|$name|"* ]]; then echo "run_core: duplicate check: $name" >&2; exit 2; fi
    known="$known$name|"
    count=$((count + 1))
    if [[ "$component" == all || "$component" == "$group" ]] &&
       [[ "$unit" == 0 || "$needs_godot" == 0 ]]; then
        checks+=("$name")
    fi
done < "$ROOT/tests/core.tsv"
if [[ "$count" != 20 || ${#checks[@]} == 0 ]]; then
    echo 'run_core: expected 20 unique core checks and a nonempty selection' >&2; exit 2
fi

# Component focus must not inherit a CI shard that silently omits its checks.
unset SUITE_SHARD_INDEX SUITE_SHARD_COUNT
suffix=''
if [[ "$unit" == 1 ]]; then suffix=-unit; fi
export SUITE_LOGDIR="${SUITE_LOGDIR:-$ROOT/tests/.logs/core/$component$suffix}"
arguments=()
if [[ "$list" == 1 ]]; then arguments+=(--list); fi
exec bash "$ROOT/tests/run_all.sh" ${arguments[@]+"${arguments[@]}"} "${checks[@]}"
