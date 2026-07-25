#!/usr/bin/env bash
# Build the FULL odin_godot extension (core + godot binding + the project's compiled
# scripts) into ONE Emscripten SIDE_MODULE wasm for the Godot web/wasm target.
#
# Unlike the native build (a stable core dll + a swappable scripts dll loaded via
# dlopen), the browser has no dynamic loader we control and no compiler: everything is
# linked AOT into a single side module. The build root is the project's `scripts`
# package; a generated wasm32-only file (`odin_godot_web_wasm32.odin`) force-imports the
# `core` package so its `@(export) odin_godot_init` entry + all registration code link
# in alongside the scripts. `-define:ODIN_GODOT_WEB=true` selects the in-module manifest
# path (no dlopen) and excludes the editor/export + hot-reload code.
#
# Usage: build_web.sh [PROJECT_DIR] [SCRIPTS_DIR] [OUT_WASM]
#   defaults: PROJECT_DIR=tests/web  SCRIPTS_DIR=<proj>/scripts  OUT=<proj>/bin/libodin_godot.wasm
#
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash build/build_web.sh'
#
# EMSCRIPTEN VERSION: Godot 4.6.2's web templates were built with emscripten 4.0.20.
# VERIFIED (docs/design/web-internals.md): a module linked with the dev shell's emscripten (5.0.6)
# ALSO loads and runs in the browser against the 4.0.20-built engine — with
# `-sSUPPORT_LONGJMP=wasm` the longjmp ABI is self-contained in the wasm and the dylink
# format is cross-compatible. 4.0.20 remains the exact-match (use `EMCC=/path/to/4.0.20/emcc
# bash build/build_web.sh` to pin it, e.g. an emsdk install); the default `emcc` works too.
set -euo pipefail
# Toolchain binaries. Both are overridable so a caller that resolved absolute paths (the
# editor's export plugin, which can't rely on `odin`/`emcc` being on the editor's PATH when
# it's launched from Finder/Steam) can pass them through as `ODIN=...`/`EMCC=...`.
# (ODIN's default + the shared helpers come from build/common.sh, sourced below.)
EMCC="${EMCC:-emcc}"
# Odin optimization for the wasm object. Default none (fast dev/test builds); the editor's
# export plugin forwards `odin_godot/export_optimization` as ODIN_EXPORT_OPT (default speed)
# so a shipped web build is optimized. emcc's own -O2 (below) still runs regardless.
OPT="${ODIN_EXPORT_OPT:-none}"

# Repo/addon root: derive from THIS script's location (build/ -> root), overridable via
# ODIN_GODOT_ROOT. (Never hardcode a checkout path — this script ships inside the addon and
# runs on machines that have never seen the maintainer's filesystem.)
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Shared helpers (ODIN, ODIN_GD_ATTRS, build_scriptgen/run_scriptgen, cleanup registry).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
PROJ="${1:-$ROOT/tests/web}"
SCRIPTS="${2:-$PROJ/scripts}"
OUT="${3:-$PROJ/bin/libodin_godot.wasm}"

mkdir -p "$(dirname "$OUT")"

# Preflight: a web build needs Emscripten. Fail FAST with an actionable message instead of
# dying deep in the emcc link. Godot 4.6's web templates were built with emscripten 4.0.20
# (an exact-match is most reliable; newer also works — see the header note).
if ! command -v "$EMCC" >/dev/null 2>&1; then
    echo "build_web.sh: Emscripten '$EMCC' not found." >&2
    echo "  Web export compiles the extension to wasm with emcc. Install the Emscripten SDK" >&2
    echo "  (https://emscripten.org/docs/getting_started/downloads.html) and activate 4.0.20" >&2
    echo "  to match Godot 4.6's web templates, then either put emcc on PATH or pass it:" >&2
    echo "    EMCC=/path/to/emsdk/upstream/emscripten/emcc bash build/build_web.sh $PROJ" >&2
    echo "  In the editor, set the 'odin_godot/emcc_bin' project setting to that path." >&2
    exit 1
fi

# Actionable failure when there are no scripts to compile (mirrors build_scripts.sh): the
# wasm is the project's scripts + the engine core AOT-linked together, so an empty scripts
# dir means there's nothing to export. Point the user at the bundled starter.
if [ ! -d "$SCRIPTS" ] || [ -z "$(ls "$SCRIPTS"/*.odin 2>/dev/null)" ]; then
    echo "build_web.sh: no Odin scripts found at '$SCRIPTS'." >&2
    echo "  Your .odin gameplay code (plus the required boot.odin) goes in a scripts/ folder." >&2
    echo "  Quick start: cp -r \"$ROOT/template/scripts\" \"$PROJ/scripts\", then re-run." >&2
    exit 1
fi

# Preflight: catch imports of core packages that do NOT exist on the wasm target BEFORE
# the compiler spews cryptic "Undeclared name: _read_directory_iterator"-style errors
# from inside Odin's own core library. Each hit is reported file:line with the portable
# alternative. Files excluded from wasm builds by Odin's filename platform gates
# (foo_darwin.odin etc.) are skipped; `when ODIN_OS == ...` gating is invisible to this
# scan, so ODIN_WEB_PREFLIGHT=0 skips it for code you know is unreachable on web.
if [[ "${ODIN_WEB_PREFLIGHT:-1}" != "0" ]]; then
    SCAN_DIRS=("$SCRIPTS")
    [ -d "$PROJ/modules" ] && SCAN_DIRS+=("$PROJ/modules")
    BAD_IMPORTS="$(
        find "${SCAN_DIRS[@]}" -name '*.odin' \
            ! -name '*.gen.odin' \
            ! -name '*_windows.odin' ! -name '*_darwin.odin' ! -name '*_linux.odin' \
            ! -name '*_freebsd.odin' ! -name '*_openbsd.odin' ! -name '*_netbsd.odin' \
            ! -name '*_haiku.odin' ! -name '*_amd64.odin' ! -name '*_arm64.odin' \
            ! -name '*_i386.odin' ! -name '*_riscv64.odin' \
            -print0 2>/dev/null |
        xargs -0 grep -nE '^[[:space:]]*(@\(require\)[[:space:]]*)?import([[:space:]]+[A-Za-z_][A-Za-z0-9_]*)?[[:space:]]+"core:(os|os/os2|dynlib|thread|net|sys/[^"]*)"' 2>/dev/null || true
    )"
    if [ -n "$BAD_IMPORTS" ]; then
        echo "build_web.sh: scripts import core packages that do not exist on the wasm target:" >&2
        echo "$BAD_IMPORTS" | sed 's/^/  /' >&2
        cat >&2 <<'EOM'
  These compile natively but have no wasm implementation, so the web build would fail
  with cryptic "Undeclared name: ..." errors from inside Odin's core library. Portable
  routes (docs/exporting.md, web section):
    core:os / core:os/os2  -> engine calls: gd.singleton_os() + gd.os_get_environment(...);
                              files via gd.File_Access
    core:net               -> engine networking: HTTPRequest / WebSocketPeer / WebRTC
    core:thread            -> no OS threads in the web side module
    core:dynlib            -> no dynamic loading on web
    core:sys/*             -> platform-specific by definition
  If an import really is unreachable on web (e.g. inside `when ODIN_OS == .Darwin`),
  re-run with ODIN_WEB_PREFLIGHT=0.
EOM
        exit 1
    fi
fi

# 1. Build the scriptgen preprocessor to a writable TEMP dir (never into the addon, which may
#    be read-only when installed under res://addons/). SGEN_BIN env reuses a prebuilt one.
build_scriptgen

# 2. Generate the odin_godot_scripts.gen.odin artifact beside the authored sources — for the main scripts dir
#    AND each optional res://modules/<name> script module (multi-module spike). On web all
#    modules link into this ONE side module: the compose file below @(require)-imports each
#    module package, and web_startup's @(init) chain runs their registrations too.
run_scriptgen "$SCRIPTS"
MODULE_IMPORT_LINES=""
if [ -d "$PROJ/modules" ]; then
    if [ "$SCRIPTS" != "$PROJ/scripts" ]; then
        echo "build_web.sh: WARNING: modules/ present but SCRIPTS ($SCRIPTS) is not \$PROJ/scripts — module compose skipped" >&2
    else
        for mdir in "$PROJ/modules"/*/; do
            mdir="${mdir%/}"
            mname="$(basename "$mdir")"
            [ -z "$(ls "$mdir"/*.odin 2>/dev/null)" ] && continue
            run_scriptgen "$mdir"
            MODULE_IMPORT_LINES="$MODULE_IMPORT_LINES@(require) import mod_$mname \"../modules/$mname\"
"
        done
    fi
fi

# 3. Emit the wasm-only compose file that pulls `core` into the scripts build. Named
#    *_wasm32.odin so Odin's arch-gated file selection keeps it OUT of native builds.
#    It only needs to exist DURING the odin build below, so it is removed on exit —
#    otherwise Godot's filesystem scanner claims it as a project script and users end
#    up committing a build artifact.
PKG="$(grep -h -m1 '^package ' "$SCRIPTS"/*.odin | head -1 | awk '{print $2}')"
if [[ -z "$PKG" ]]; then
    echo "build_web.sh: could not determine scripts package name" >&2
    exit 1
fi
odin_gd_cleanup_on_exit "$SCRIPTS/odin_godot_web_wasm32.odin"
cat > "$SCRIPTS/odin_godot_web_wasm32.odin" <<EOF
package $PKG

// GENERATED by build/build_web.sh — wasm32-only. Forces the core GDExtension (its
// @(export) odin_godot_init entry + all registration) to link into this module
// alongside the scripts. Excluded from native builds by the _wasm32 filename gate.
@(require) import core "godot:core"
$MODULE_IMPORT_LINES
EOF

# 4. Odin -> wasm object. Freestanding wasm32, PIC (required: SIDE_MODULE data
#    relocations), object mode, no entry point, ODIN_GODOT_WEB define. The object is an
#    intermediate — keep it in a temp dir (cleaned on exit), not in the project's bin/.
#    `SCRIPT_BUILD_FLAGS` (env, optional) forwards extra odin flags, matching the
#    native/export/cross script builds.
OBJ_DIR="$(mktemp -d)"
odin_gd_cleanup_on_exit "$OBJ_DIR"
ODIN_OBJ="$OBJ_DIR/$(basename "${OUT%.wasm}").wasm.o"
"$ODIN" build "$SCRIPTS" \
    -collection:godot="$ROOT" \
    -target:freestanding_wasm32 \
    -build-mode:obj \
    -o:"$OPT" \
    -no-entry-point \
    -reloc-mode:pic \
    -define:ODIN_GODOT_WEB=true \
    ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
    -out:"$ODIN_OBJ" \
    ${SCRIPT_BUILD_FLAGS:-}

# 5. Object -> Emscripten SIDE_MODULE. -sSUPPORT_LONGJMP=wasm matches the binding's
#    setjmp/longjmp -> invoke_* ABI. The entry symbol odin_godot_init is exported via
#    its Odin @(export) attribute. Link to a temp beside $OUT, then publish atomically
#    (same invariant as atomic_odin_dll: the live wasm is never missing/half-written).
TMP_WASM="$(dirname "$OUT")/.$(basename "$OUT").tmp"
odin_gd_cleanup_on_exit "$TMP_WASM"
"$EMCC" "$ODIN_OBJ" \
    -sSIDE_MODULE=1 \
    -sSUPPORT_LONGJMP=wasm \
    -O2 \
    -o "$TMP_WASM"
mv -f "$TMP_WASM" "$OUT"

echo "build_web.sh: built $OUT"
file "$OUT" || true
