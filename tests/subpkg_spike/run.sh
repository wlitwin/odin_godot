#!/usr/bin/env bash
# Build + run the SCRIPT SUBPACKAGE spike test. Greps for SUBPKG_SPIKE_OK.
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/subpkg_spike/run.sh'
#
# Three phases:
#   1. LAYOUT   — scriptgen's artifacts for a module TREE: one consolidated
#                 odin_godot_scripts.gen.odin per ANNOTATED package dir (root and ui/),
#                 nothing at all for the pure helper util/, and the boot shim + staleness
#                 guard in the ROOT only. The guard carries the import manifest that links
#                 the subpackage, and #load_hash entries for the whole tree by relative path.
#   2. MAIN     — test_subpkg.gd: a subfolder script attaches and runs; its exports,
#                 methods and typed signal work; the root reads it TYPED in-dll via
#                 rt.script_of; a helper subpackage is shared by both; and reloading the
#                 subfolder script swaps the module dll with instance state preserved.
#   3. NEGATIVE — scriptgen driven DIRECTLY over four bad trees, asserting the exact
#                 teaching error each time: a kit annotation in a subpackage, a subpackage
#                 importing the module root, a duplicate package name, a duplicate class
#                 name. Each must also leave NO generated file behind.
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/subpkg_spike"
ODIN="${ODIN:-odin}"
# The build + the mid-test rebuild resolve the collection root from this env (the test
# project keeps no root setting so it works from any checkout) — exactly what run_all does.
export ODIN_GODOT_ROOT="$ROOT"

fail() { echo "SUBPKG_SPIKE_FAIL: $1"; exit 1; }

# Reuse a pre-built scriptgen (run_all sets SGEN_BIN) or build one for the negative phase.
SGEN="${SGEN_BIN:-}"
if [[ -z "$SGEN" || ! -x "$SGEN" ]]; then
    tmpsg="$(mktemp -d)"
    SGEN="$tmpsg/scriptgen"
    if ! "$ODIN" build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$SGEN" -debug >/dev/null 2>&1; then
        fail "scriptgen build failed"
    fi
fi

work="$(mktemp -d)"
LOG="$(mktemp)"
trap 'rm -rf "$work"; rm -f "$LOG"' EXIT

# Build core + the module (root package + the ui/ subpackage + the util/ helper, one dll).
bash "$ROOT/build/build_scripts.sh" "$PROJ" || fail "build_scripts.sh failed"

# ---- phase 1: the generated layout of a module TREE ----
G_ROOT="$PROJ/scripts/odin_godot_scripts.gen.odin"
G_UI="$PROJ/scripts/ui/odin_godot_scripts.gen.odin"
GUARD="$PROJ/scripts/odin_godot_guard.gen.odin"
[[ -f "$G_ROOT" ]] || fail "no consolidated artifact in the module root"
[[ -f "$G_UI" ]] || fail "no consolidated artifact in the ANNOTATED subpackage scripts/ui"
[[ -f "$GUARD" ]] || fail "no staleness guard in the module root"
[[ -f "$PROJ/scripts/odin_godot_boot.gen.odin" ]] || fail "no boot shim in the module root"
if [ -n "$(find "$PROJ/scripts/util" -name '*.gen.odin' -print -quit)" ]; then
    fail "the pure HELPER subpackage util/ was given generated code"
fi
for leaked in "$PROJ/scripts/ui/odin_godot_boot.gen.odin" "$PROJ/scripts/ui/odin_godot_guard.gen.odin"; do
    if [ -f "$leaked" ]; then fail "a subpackage got a root-only shim: $leaked"; fi
done
grep -q 'package subpkg_ui' "$G_UI" || fail "the subpackage artifact does not declare package subpkg_ui"
grep -q '^import _ "ui"$' "$GUARD" || fail "the guard has no import manifest line for the ui subpackage"
grep -q '#load_hash("ui/hud.odin"' "$GUARD" || fail "the guard does not hash the subpackage source by relative path"
grep -q '#load_hash("util/util.odin"' "$GUARD" || fail "the guard does not hash the helper subpackage source"
echo "  ok  layout: one artifact per annotated package dir, root-only guard+boot, manifest + tree-wide #load_hash"

# ---- phase 2: headless main ----
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

"$GODOT" --headless --path "$PROJ" --script test_subpkg.gd 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
    fail "main phase exited non-zero ($RC)"
fi
grep -q "SUBPKG_SPIKE_MAIN_OK" "$LOG" || fail "main phase did not print SUBPKG_SPIKE_MAIN_OK"
echo "  ok  subfolder script: attachable, exports/methods/signal live, typed in-dll read, reload preserves state"

# Leave the checkout on v1 (the mid-test rebuild left the dll on -define:HUD_V=2).
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null 2>&1 || fail "v1 restore build failed"

# ---- phase 3: the four refusals ----
# Each fixture is a throwaway module tree; scriptgen is driven directly (no Godot).
neg() { # neg <name> <expected-substring>
    local name="$1" want="$2" out rc
    out="$("$SGEN" "$work/$name/scripts" "-godot:$ROOT" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$out"
        fail "[$name] scriptgen accepted a tree it must refuse"
    fi
    if ! grep -qF -- "$want" <<<"$out"; then
        echo "$out"
        fail "[$name] refused, but without the expected message: $want"
    fi
    if [ -n "$(find "$work/$name/scripts" -name '*.gen.odin' -print -quit)" ]; then
        fail "[$name] a refused tree still left generated code on disk"
    fi
    echo "  ok  refused [$name]: $want"
}

mk_root() { # mk_root <name> <package>
    mkdir -p "$work/$1/scripts"
    cat >"$work/$1/scripts/game.odin" <<EOF
//gd:extends Node
//gd:class Game
package $2
import gd "godot:godot"
Game :: struct { owner: gd.Node }
SHARED :: 3
EOF
}

# (a) a KIT annotation in a subpackage
mk_root kit neg_kit_main
mkdir -p "$work/kit/scripts/ui"
cat >"$work/kit/scripts/ui/hud.odin" <<'EOF'
//gd:extends Node
//gd:class Hud
package neg_kit_ui
import gd "godot:godot"
import knet "godot:kit/net"
Hud :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     f32 `gd:"replicate"`,
}
EOF
neg kit 'Hud declares a gd:"replicate" field tag in the script subpackage "ui" — kit wiring is part of the MODULE'"'"'s wire contract'

# (b) a subpackage importing the module ROOT (the manifest makes it a cycle)
mk_root cycle neg_cycle_main
mkdir -p "$work/cycle/scripts/ui"
cat >"$work/cycle/scripts/ui/hud.odin" <<'EOF'
//gd:extends Node
//gd:class Hud
package neg_cycle_ui
import gd "godot:godot"
import root ".."
Hud :: struct { owner: gd.Node }
@(gd_method)
hud_v :: proc(self: ^Hud) -> int { return root.SHARED }
EOF
neg cycle 'a subfolder script package cannot import the module root'

# (c) two dirs claiming one package name
mk_root pkgname neg_pkg_main
mkdir -p "$work/pkgname/scripts/ui"
cat >"$work/pkgname/scripts/ui/hud.odin" <<'EOF'
//gd:extends Node
//gd:class Hud
package neg_pkg_main
import gd "godot:godot"
Hud :: struct { owner: gd.Node }
EOF
neg pkgname 'duplicate package name "neg_pkg_main"'

# (d) two dirs claiming one //gd:class
mk_root clsname neg_cls_main
mkdir -p "$work/clsname/scripts/ui"
cat >"$work/clsname/scripts/ui/hud.odin" <<'EOF'
//gd:extends Node
//gd:class Game
package neg_cls_ui
import gd "godot:godot"
Hud :: struct { owner: gd.Node }
EOF
neg clsname 'duplicate //gd:class "Game"'

echo "SUBPKG_SPIKE_OK"
