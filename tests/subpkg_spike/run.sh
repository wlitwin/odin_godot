#!/usr/bin/env bash
# Build + run the SCRIPT SUBPACKAGE spike test. Greps for SUBPKG_SPIKE_OK.
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/subpkg_spike/run.sh'
#
# Four phases:
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
#                 name. Each must also leave NO generated file behind. The kit refusal
#                 must also LEAD: it is the root cause of the root's own resolve failures,
#                 so it is the first error on screen and they are gone.
#   4. FINGERPRINT — NET_FINGERPRINT is the join door (Deny_Reason.Version), so ORGANIZATION
#                 must not knock on it: moving a class between the module root and a
#                 subfolder leaves the hash identical, a flat module hashes to what it
#                 always did, and a real wire-surface change still changes it.
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
neg() { # neg <name> <expected-substring> [lead]  — `lead`: must be the FIRST error line
    local name="$1" want="$2" lead="${3:-}" out rc
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
    if [ -n "$lead" ] && ! grep -m1 'scriptgen: error:' <<<"$out" | grep -qF -- "$want"; then
        echo "$out"
        fail "[$name] the refusal is not the FIRST error — the root cause must lead"
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

# (a) a KIT annotation in a subpackage — with the DERIVED errors it causes upstream.
# The root here is a real game shape: it tags the moved class as a wire entity and
# carries the half that pairs with it. Both of those fail once the class is in a
# subfolder, and they used to print FIRST — three complaints (one of them dumping the
# shell's thirty-odd pairing names) before the one that explains them. The refusal is
# the root cause, so it leads and they are gone.
mkdir -p "$work/kit/scripts/ui"
cat >"$work/kit/scripts/game.odin" <<'EOF'
//gd:extends Node
//gd:class Game
package neg_kit_main
import gd "godot:godot"
import kboot "godot:kit/boot"
Game :: struct {
	owner:     gd.Node,
	boot:      kboot.Boot,
	hud_scene: gd.PackedScene `gd:"entity=Hud:1"`,
}
@(gd_half)
hud_spawned :: proc(game: ^Game, self: ^Hud) {}
EOF
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
neg kit 'Hud declares a gd:"replicate" field tag in the script subpackage "ui" — kit wiring is part of the MODULE'"'"'s wire contract' lead
kit_out="$("$SGEN" "$work/kit/scripts" "-godot:$ROOT" 2>&1)"
if grep -qE 'no script struct named|pairs with nothing' <<<"$kit_out"; then
    echo "$kit_out"
    fail "[kit] the derived errors survived the refusal — they are noise once the cause is named"
fi
echo "  ok  refused [kit]: the refusal LEADS and the derived root errors are suppressed"

# (a2) the SAME move without any kit surface: no refusal to fire, so the root's own
# errors are what the author sees — and each must name where the class actually went
# rather than claim it does not exist.
mkdir -p "$work/subword/scripts/ui"
cat >"$work/subword/scripts/game.odin" <<'EOF'
//gd:extends Node
//gd:class Game
package neg_subword_main
import gd "godot:godot"
import kboot "godot:kit/boot"
Game :: struct {
	owner:     gd.Node,
	boot:      kboot.Boot,
	hud_scene: gd.PackedScene `gd:"entity=Hud:1"`,
}
@(gd_half)
hud_spawned :: proc(game: ^Game, self: ^Hud) {}
EOF
cat >"$work/subword/scripts/ui/hud.odin" <<'EOF'
//gd:extends Node
//gd:class Hud
package neg_subword_ui
import gd "godot:godot"
Hud :: struct { owner: gd.Node, label: string `gd:"export"` }
EOF
neg subword 'entity Hud: "Hud" is declared in the script subpackage "ui", not the module root'
sub_out="$("$SGEN" "$work/subword/scripts" "-godot:$ROOT" 2>&1)"
grep -qF 'is written against Hud, which is declared in the script subpackage "ui"' <<<"$sub_out" \
    || { echo "$sub_out"; fail "[subword] the stranded half does not say where its class went"; }
grep -qF 'in this module' <<<"$sub_out" \
    && { echo "$sub_out"; fail "[subword] a resolution error still says \"in this module\" where it means the module root"; }
echo "  ok  refused [subword]: entity + stranded half both name the subpackage the class moved to"

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

# ---- phase 4: NET_FINGERPRINT survives a pure layout move ----
# The fingerprint is the join door: two builds whose hashes differ refuse each other with
# Deny_Reason.Version. It must therefore answer to the WIRE CONTRACT and to nothing else —
# and a class in a subfolder has no wire contract (phase 3's first refusal is why). So
# scriptgen folds subpackage CLASS NAMES into the same sorted class stream as the root's:
# moving a class between the root and a subfolder writes the same line in the same place.
#
# Three fixtures, one class each: `Game` carries the module's whole wire surface (net_id +
# a replicated field) and stays put; `Hud` is engine-native and moves.
fp_fixture() { # fp_fixture <name> <hp-type> <hud-subdir|"">
    local n="$1" hp="$2" sub="$3"
    mkdir -p "$work/$n/scripts${sub:+/$sub}"
    cat >"$work/$n/scripts/game.odin" <<EOF
//gd:extends Node
//gd:class Game
package fp_root
import gd "godot:godot"
import knet "godot:kit/net"

Game :: struct {
	owner:  gd.Node,
	net_id: knet.Net_Id,
	hp:     $hp \`gd:"replicate"\`,
}
EOF
    cat >"$work/$n/scripts${sub:+/$sub}/hud.odin" <<EOF
//gd:extends Control
//gd:class Hud
package fp_${sub:-root}
import gd "godot:godot"

Hud :: struct {
	owner: gd.Control,
	label: string \`gd:"export"\`,
}
EOF
}
fp() { # fp <name> -> the NET_FINGERPRINT literal
    "$SGEN" "$work/$1/scripts" "-godot:$ROOT" >/dev/null 2>&1 || return 1
    sed -n 's/^NET_FINGERPRINT :: u64(\(0x[0-9a-f]*\)).*/\1/p' "$work/$1/scripts/odin_godot_guard.gen.odin"
}

fp_fixture fpflat  f32 ""    # Hud beside Game, in the module root
fp_fixture fpmoved f32 "ui"  # the SAME Hud, one folder down — nothing else differs
fp_fixture fpwire  f64 ""    # flat again, but the replicated field changed type

FP_FLAT="$(fp fpflat)"   || fail "the flat fingerprint fixture did not generate"
FP_MOVED="$(fp fpmoved)" || fail "the moved fingerprint fixture did not generate"
FP_WIRE="$(fp fpwire)"   || fail "the wire-change fingerprint fixture did not generate"
[ -n "$FP_FLAT" ] || fail "no NET_FINGERPRINT in the flat fixture's guard"

# (i) A FLAT module hashes to exactly what it always did. This literal was produced by the
# scriptgen that shipped BEFORE subpackage names folded in; if it moves, every already-
# released build of every flat game stops being able to join the next one.
if [ "$FP_FLAT" != "0x7b40b20d96a35e4b" ]; then
    fail "the FLAT fingerprint changed ($FP_FLAT, expected 0x7b40b20d96a35e4b) — every shipped flat build would now be refused at the join door (Deny_Reason.Version). Only a deliberate wire-contract change may edit this literal."
fi
echo "  ok  fingerprint: a flat module still hashes to $FP_FLAT"

# (ii) Organization is not a wire change.
[ "$FP_FLAT" == "$FP_MOVED" ] || fail "moving Hud into scripts/ui changed NET_FINGERPRINT ($FP_FLAT -> $FP_MOVED) — a pure layout refactor would version-break the join door"
echo "  ok  fingerprint: moving a class root <-> subfolder leaves it identical"

# (iii) ...but a real one still is.
[ "$FP_FLAT" != "$FP_WIRE" ] || fail "changing a gd:\"replicate\" field's type did NOT change NET_FINGERPRINT — the version door is blind"
echo "  ok  fingerprint: a replicated field's type change still moves it ($FP_WIRE)"

echo "SUBPKG_SPIKE_OK"
