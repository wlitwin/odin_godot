#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# Apply authored style checks to the recipes; imported generated bindings retain
# their generator's style. Global -strict-style/-disallow-do also cover imports.
STYLE_FLAGS=(-vet -vet-style -vet-semicolon -vet-tabs -warnings-as-errors -vet-packages:replay_recipes)
odin check "$ROOT/examples/replay_recipes" -collection:godot="$ROOT" -no-entry-point "${STYLE_FLAGS[@]}"
odin check "$ROOT/examples/replay_recipes" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${STYLE_FLAGS[@]}"

# The experimental descriptor has one diagnostic-producing validation callback.
# Guard the removed boolean spelling so compatibility aliases cannot grow back.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/current" "$work/legacy"
cat >"$work/current/binding.odin" <<'ODIN'
package script_view_contract
import rgd "godot:replay/godot"
import defs "godot:replay/definitions"
Script :: struct {}
binding :: proc() -> rgd.Script_View(u8, Script) {
	return {validate = proc(_: ^Script) -> defs.Report {return {}}}
}
ODIN
cat >"$work/legacy/binding.odin" <<'ODIN'
package script_view_contract
import rgd "godot:replay/godot"
Script :: struct {}
binding :: proc() -> rgd.Script_View(u8, Script) {
	return {valid = proc(_: ^Script) -> bool {return true}}
}
ODIN
for target in native wasm; do
    target_flags=()
    if [[ "$target" == wasm ]]; then target_flags=(-target:freestanding_wasm32); fi
    odin check "$work/current" -collection:godot="$ROOT" -no-entry-point "${target_flags[@]}"
    if odin check "$work/legacy" -collection:godot="$ROOT" -no-entry-point "${target_flags[@]}" >"$work/$target.log" 2>&1; then
        echo "Legacy Script_View.valid unexpectedly compiled ($target)" >&2
        exit 1
    fi
    if ! rg -qi 'field.*valid|valid.*field' "$work/$target.log"; then
        cat "$work/$target.log" >&2
        exit 1
    fi
done

mkdir -p "$work/private"
for symbol in browser_checkpoint_fail view_pool_fail party_scope script_view_resolve View_Pool_Entry Effect_Identity; do
    printf 'package private_surface\nimport replaygd "godot:replay/godot"\nLeaked :: replaygd.%s\n' \
        "$symbol" >"$work/private/probe.odin"
    if odin check "$work/private" -collection:godot="$ROOT" -no-entry-point >"$work/private.log" 2>&1; then
        echo "Unexpected public Replay Godot API: $symbol" >&2
        exit 1
    fi
    if ! grep -Fq "'$symbol' is not exported" "$work/private.log"; then
        cat "$work/private.log" >&2
        exit 1
    fi
done
echo REPLAY_RECIPES_OK
