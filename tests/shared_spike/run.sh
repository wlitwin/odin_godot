#!/usr/bin/env bash
# Build + run the SHARED VOCABULARY spike test. Greps for SHARED_SPIKE_OK.
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/shared_spike/run.sh'
#
# res://shared/<pkg> is the ONE exemption from module isolation: a package there may be
# imported by every script module, because it holds no state to fork per dll. Five phases:
#
#   1. LAYOUT   — the build passes the isolation checks with shared imports from the main
#                 module, from a SUBPACKAGE of it, and from res://modules/enemies; and the
#                 shared tree itself gets NO generated artifacts (it belongs to no module).
#   2. MAIN     — test_shared.gd: two dlls, one vocabulary. The shared constant, enum,
#                 payload struct and pure proc agree across the main module, its
#                 subpackage and the separate module; cross-module talk stays
#                 engine-mediated.
#   3. RELOAD   — a headless EDITOR: ONE edit to res://shared/ids/ids.odin rebuilds and
#                 swaps BOTH module dlls in-process (core/reload.odin folds the shared
#                 tree's hash into every module's).
#   4. NEGATIVE — scriptgen driven DIRECTLY over bad shared trees, asserting the exact
#                 teaching error each time: a mutable global, an @(init), a //gd: marker,
#                 and a shared package importing a module. Each must leave NO generated
#                 file behind.
#   5. BASH     — the build-script backstop (check_module_isolation in build/common.sh):
#                 a genuine cross-module import is still rejected, while the shared
#                 imports of phase 1 passed it.
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/shared_spike"
ODIN="${ODIN:-odin}"
# The build, the mid-test editor rebuild and the export plugin all resolve the collection
# root from this env (the test project keeps no root setting so it works from any
# checkout) — exactly what tests/run_all.sh does suite-wide.
export ODIN_GODOT_ROOT="$ROOT"

fail() { echo "SHARED_SPIKE_FAIL: $1"; exit 1; }

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
RLOG="$(mktemp)"
ILOG="$(mktemp)"
# The reload phase EDITS res://shared/ids/ids.odin (its driver restores it); a run killed
# mid-phase must not leave the checkout modified either, so keep a pristine copy here and
# put it back unconditionally. (Copy, not `git checkout`: this works before the spike is
# committed and in a copied-out tree.)
SHARED_SRC="$PROJ/shared/ids/ids.odin"
SHARED_BAK="$(mktemp)"
cp "$SHARED_SRC" "$SHARED_BAK"
cleanup() {
    cp "$SHARED_BAK" "$SHARED_SRC" 2>/dev/null || true
    rm -rf "$work" "$PROJ/modules/sneak" "$PROJ/bin/libodinscripts_sneak".*
    rm -f "$LOG" "$RLOG" "$ILOG" "$SHARED_BAK"
}
trap cleanup EXIT
rm -rf "$PROJ/modules/sneak" "$PROJ/bin/libodinscripts_sneak".* 2>/dev/null || true

# ---- phase 1: the build (isolation checks included) + the shared tree's layout ----
bash "$ROOT/build/build_scripts.sh" "$PROJ" || fail "build_scripts.sh failed (shared imports must pass the isolation checks)"

[[ -f "$PROJ/bin/libodinscripts.dylib" ]] || fail "the main scripts dll was not built"
[[ -f "$PROJ/bin/libodinscripts_enemies.dylib" ]] || fail "the enemies module dll was not built"
if [ -n "$(find "$PROJ/shared" -name '*.gen.odin' -print -quit)" ]; then
    fail "the shared tree was given generated code (it belongs to no module)"
fi
if grep -qE '#load_hash\("(\.\.|shared)/' "$PROJ/scripts/odin_godot_guard.gen.odin"; then
    fail "the staleness guard #load_hashes a source outside the module (shared files generate nothing)"
fi
echo "  ok  layout: both dlls built with shared imports, no artifacts under shared/, no shared guard entries"

# ---- phase 2: headless main ----
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

"$GODOT" --headless --path "$PROJ" --script test_shared.gd 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
[ "$RC" -eq 0 ] || fail "main phase exited non-zero ($RC)"
grep -q "SHARED_SPIKE_MAIN_OK" "$LOG" || fail "main phase did not print SHARED_SPIKE_MAIN_OK"
echo "  ok  one vocabulary across two dlls: constant, enum, payload struct and pure proc agree; cross-module call still engine-mediated"

# ---- phase 3: a shared edit rebuilds + swaps EVERY module (headless editor) ----
# Capped: a wedged headless editor must fail this phase, not sit until the suite's own
# timeout kills the whole test (`timeout` ships in the nix dev shell; degrade without it).
TIMEOUT_BIN="$(command -v timeout || true)"
if [[ -n "$TIMEOUT_BIN" ]]; then
    "$TIMEOUT_BIN" 300 "$GODOT" --editor --headless --path "$PROJ" --script test_shared_reload.gd >"$RLOG" 2>&1
else
    "$GODOT" --editor --headless --path "$PROJ" --script test_shared_reload.gd >"$RLOG" 2>&1
fi
echo "----- reload driver output -----"; grep -vE "^warning: |could not find symbol" "$RLOG" | tail -25; echo "--------------------------------"
if grep -qE "signal 11|Segmentation|must be overridden|Required virtual" "$RLOG"; then
    fail "crash / missing-virtual error during the editor reload phase"
fi
grep -q "SHARED_RELOAD_OK" "$RLOG" || fail "one shared edit did not rebuild+swap BOTH modules in-process (see the driver output above)"
echo "  ok  rebuild-on-save: ONE edit under shared/ rebuilt and swapped BOTH module dlls"

# The reload phase left the dlls built from the EDITED shared source; restore the tree.
cp "$SHARED_BAK" "$SHARED_SRC"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null 2>&1 || fail "restore build failed"

# ---- phase 4: the refusals (scriptgen driven directly, no Godot) ----
neg() { # neg <name> <expected-substring>
    local name="$1" want="$2" out rc
    out="$("$SGEN" "$work/$name/scripts" "-godot:$ROOT" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$out"
        fail "[$name] scriptgen accepted a shared tree it must refuse"
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

mk_project() { # mk_project <name> <shared-body>
    mkdir -p "$work/$1/scripts" "$work/$1/shared/ids" "$work/$1/modules/other"
    cat >"$work/$1/scripts/game.odin" <<EOF
//gd:extends Node
//gd:class Game
package neg_${1}_main
import gd "godot:godot"
import ids "../shared/ids"
Game :: struct { owner: gd.Node }
@(gd_method)
game_v :: proc(self: ^Game) -> int { return ids.STEP }
EOF
    cat >"$work/$1/modules/other/other.odin" <<EOF
package neg_${1}_other
OTHER :: 1
EOF
    printf 'package neg_%s_ids\nSTEP :: 7\n%s' "$1" "$2" >"$work/$1/shared/ids/ids.odin"
}

# (a) a MUTABLE package global in a shared package
mk_project mutable 'counter: int
'
neg mutable 'declares the file-scope variable "counter" — every module that links this package gets its OWN copy'

# (b) an @(init) proc — one run PER DLL
mk_project initproc '@(init)
setup :: proc() { }
'
neg initproc 'declares the @(init) proc "setup" — it would run ONCE PER DLL'

# (c) a //gd: marker — scripts belong to a module
mk_project marker '//gd:class Sneaky
'
neg marker 'carries the script marker "//gd:class Sneaky" — an attachable script class belongs to a MODULE'

# (d) a shared package importing a MODULE — the forked-globals hazard verbatim
mk_project intomodule 'import other "../../modules/other"
leak :: proc() -> int { return other.OTHER }
'
neg intomodule 'OUTSIDE the shared tree'

# (e) a gd-tagged BUNDLE embedded from shared/ — out of scope, but never silent
mkdir -p "$work/bundle/scripts" "$work/bundle/shared/ids"
printf 'package neg_bundle_ids\nBundle :: struct { hp: i32 `gd:"replicate"` }\n' >"$work/bundle/shared/ids/ids.odin"
cat >"$work/bundle/scripts/game.odin" <<'EOF'
//gd:extends Node
//gd:class Game
package neg_bundle_main
import gd "godot:godot"
import knet "godot:kit/net"
import ids "../shared/ids"
Game :: struct {
	owner:   gd.Node,
	net_id:  knet.Net_Id,
	using b: ids.Bundle,
}
EOF
neg bundle 'comes from the SHARED package'

# ---- phase 5: the bash backstop still rejects a GENUINE cross-module import ----
# (The shared imports already passed it in phase 1 — that build ran check_module_isolation
# over the main module, the subpackage's module root and the enemies module.)
mkdir -p "$PROJ/modules/sneak"
cat >"$PROJ/modules/sneak/sneak.odin" <<'EOF'
package spike_shared_sneak

// GENERATED BY run.sh (isolation phase) — an ILLEGAL cross-module import. The shared
// tree is an exemption for res://shared/<pkg>, NOT a hole: importing another module
// still duplicates its globals into this dll.

import other "../enemies"

sneak_probe :: proc() -> int {
	return other.local_hits
}
EOF
if SKIP_CORE=1 BUILD_MODULES=0 bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/modules/sneak" >"$ILOG" 2>&1; then
    cat "$ILOG"
    fail "a cross-module import was NOT rejected by the build"
fi
grep -q "ILLEGAL cross-module import" "$ILOG" || {
    cat "$ILOG"
    fail "cross-module import failed the build but without the clear message"
}
grep -q "put the package under" "$ILOG" || {
    cat "$ILOG"
    fail "the rejection did not mention the res://shared/ alternative"
}
rm -rf "$PROJ/modules/sneak" "$PROJ/bin/libodinscripts_sneak".*
echo "  ok  bash backstop: shared imports pass, a genuine cross-module import is rejected and points at res://shared/"

echo "SHARED_SPIKE_OK"
