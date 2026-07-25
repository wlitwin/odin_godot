#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THE WEB-TARGET COMPILE PIN. Type-checks the whole shipped Odin surface — every
# godot:kit/* package plus core/play/flowgd — for freestanding_wasm32, the target
# build/build_web.sh compiles a project's scripts to.
#
# WHY THIS SUITE EXISTS. `core:fmt`'s println family lives in fmt_os.odin
# (`#+build !freestanding !js !orca`), so `fmt.println`/`fmt.printfln` simply are not
# declared on the web target. A single unguarded call anywhere in the kit compiles and
# tests GREEN natively and breaks EVERY user's web export — and it happened: a
# `fmt.printfln` in kit/netgd/succession.odin shipped for days, because the existing
# web suites (tests/web, tests/modules_web, the example web runs) export toy projects
# that never link the full kit. The fix each time is
# `when ODIN_OS != .Freestanding { … }` — wasm gets silence, not a broken build.
#
# FAST + TOOLCHAIN-FREE. This is `odin check`, not a build: no Emscripten, no emcc
# link, no browser, no Godot. It is seconds, so it belongs in run_all unconditionally
# (no skip sentinel — unlike the browser-gated web tests, nothing here is optional).
#
# Two phases:
#   1. THE PIN     — `odin check` the fixture scripts dir for the wasm target. Any
#                    not-on-freestanding call in ANY imported package fails here,
#                    reported file:line.
#   2. THE TEETH   — the same check over a fixture that imports a package with a
#                    deliberate unguarded `fmt.println` MUST fail, proving the check
#                    reaches into imported package bodies (which is the whole claim).
#
# Prints KITWASM_OK on success. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitwasm/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# ODIN + ODIN_GD_ATTRS (the @(gd_*) custom-attribute flags every scripts build needs)
# come from the shared build helpers, so this pin can never drift from the real web
# build's flag set. common.sh owns the EXIT trap; register cleanups with it.
source "$ROOT/build/common.sh"

fail() { echo "KITWASM_FAIL: $1"; exit 1; }

# The wasm compile shape, lifted from build/build_web.sh step 4. Only the flags that
# can change what the CHECKER sees are here: the target triple, the ODIN_GODOT_WEB
# define (it selects the in-module manifest path and excludes the editor/export +
# hot-reload code) and no-entry-point. The codegen-only flags of the real build
# (-build-mode:obj, -reloc-mode:pic, -o:<opt>) cannot affect type checking.
check_wasm() { # check_wasm <pkg_dir> -> odin's exit code, output on stdout
    "$ODIN" check "$1" \
        -collection:godot="$ROOT" \
        -target:freestanding_wasm32 \
        -define:ODIN_GODOT_WEB=true \
        -no-entry-point \
        ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} 2>&1
}

# ---- phase 1: the pin ----
# The fixture is a plain hand-written package: a scriptgen artifact here (repo-wide
# sweep) would pin stale #load_hash bytes into the check. Sweep strays first.
rm -f "$ROOT"/tests/kitwasm/scripts/*.gen.odin
OUT="$(check_wasm "$ROOT/tests/kitwasm/scripts")"
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "$OUT"
    echo
    echo "  ^ the shipped Odin surface does not compile for the WEB target (freestanding_wasm32)."
    echo "    If this is a println-family call: core:fmt's stdio lives in fmt_os.odin"
    echo "    (#+build !freestanding !js !orca) and does not exist here. Wrap the site in"
    echo "      when ODIN_OS != .Freestanding { ... }"
    echo "    like kit/sim/lane.odin and kit/session/session.odin do — wasm gets silence,"
    echo "    not a broken build. For core:os / core:net / core:thread reach for the"
    echo "    portable route instead (docs/exporting.md, web section)."
    fail "kit + core do not type-check for freestanding_wasm32"
fi
echo "  ok  every godot:kit/* package + core/play/flowgd type-checks for freestanding_wasm32"

# ---- phase 2: the teeth ----
# A check that passed because it never LOOKED at the imported bodies would be a pin
# that pins nothing. Import a package holding exactly the offending line class and
# require the same invocation to reject it.
work="$(mktemp -d)"
odin_gd_cleanup_on_exit "$work"
mkdir -p "$work/bait" "$work/scripts"
cat >"$work/bait/bait.odin" <<'ODIN'
package kitwasm_bait
import "core:fmt"
bait :: proc() { fmt.println("this call does not exist on freestanding_wasm32") }
ODIN
cat >"$work/scripts/main.odin" <<'ODIN'
package kitwasm_teeth
@(require) import _ "../bait"
ODIN
OUT="$(check_wasm "$work/scripts")"
RC=$?
if [ "$RC" -eq 0 ]; then
    fail "the wasm check ACCEPTED an unguarded fmt.println in an imported package — the pin has no teeth"
fi
grep -q "not declared by 'fmt'" <<<"$OUT" || {
    echo "$OUT"
    fail "the wasm check rejected the bait for the wrong reason"
}
echo "  ok  teeth: an unguarded fmt.println in an IMPORTED package fails the same check"

echo "KITWASM_OK"
