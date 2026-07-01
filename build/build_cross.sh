#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Cross-compile the odin_godot extension (CORE dll + a project's SCRIPTS dll) for
# linux_amd64 / windows_amd64 from a macOS (or Linux) host.
#
# WHY a separate script: Odin's built-in linker driver refuses to CROSS-LINK a dll
# ("Linking for cross compilation for this platform is not yet supported"). So we
# split the job: Odin emits a single relocatable OBJECT (`-build-mode:obj
# -use-single-module`) for the target, then we hand that object to the matching Nix
# CROSS LINKER (a gcc wrapper that knows the target glibc / mingw sysroot) to produce
# the final `.so` / `.dll`. The gdext boundary is pure C-ABI, so no headers/libs from
# the host leak in — only the target's libc/libgcc (Linux) or mingw CRT (Windows).
#
# The cross C compilers come from the Nix dev shell, exported as:
#   ODIN_CROSS_LINUX_CC    (pkgsCross.gnu64.stdenv.cc      -> x86_64-unknown-linux-gnu-cc)
#   ODIN_CROSS_WINDOWS_CC  (pkgsCross.mingwW64.stdenv.cc   -> x86_64-w64-mingw32-cc)
# If unset, the script falls back to the conventional triple-prefixed name on PATH and
# SKIPS (exit 3) with a clear message when the toolchain is unavailable — so callers /
# tests can gate on it exactly like the browser-gated web tests.
#
# Usage:
#   build_cross.sh <linux|windows> [PROJECT_DIR] [OUT_DIR]
#     PROJECT_DIR defaults to tests/phase35 (a project with a scripts/ dir).
#     OUT_DIR     defaults to <PROJECT_DIR>/bin/<linux|windows>.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash build/build_cross.sh linux'
#   nix develop --command bash -c 'bash build/build_cross.sh windows'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Shared helpers (ODIN, ODIN_GD_ATTRS, build_scriptgen/run_scriptgen, cleanup registry).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
TARGET="${1:?usage: build_cross.sh <linux|windows> [PROJECT_DIR] [OUT_DIR]}"
PROJ="${2:-$ROOT/tests/phase35}"
SCRIPTS="$PROJ/scripts"

case "$TARGET" in
    linux)
        ODIN_TARGET="linux_amd64"
        EXT=".so"
        CC="${ODIN_CROSS_LINUX_CC:-$(command -v x86_64-unknown-linux-gnu-cc x86_64-unknown-linux-gnu-gcc x86_64-linux-gnu-gcc 2>/dev/null | head -1 || true)}"
        # glibc >=2.34 folds libdl/libpthread/libm into libc, but naming them is harmless
        # on older sysroots and documents the dependency.
        LINK_LIBS=(-ldl -lm -lpthread)
        ;;
    windows)
        ODIN_TARGET="windows_amd64"
        EXT=".dll"
        CC="${ODIN_CROSS_WINDOWS_CC:-$(command -v x86_64-w64-mingw32-cc x86_64-w64-mingw32-gcc 2>/dev/null | head -1 || true)}"
        # The DLL must be SELF-CONTAINED: a target Windows box has no /nix mingw DLLs. So
        # statically link libgcc + the gcc thread runtime (mcfgthreads, pulled in by mingw's
        # default `mcf` thread model); only system DLLs (msvcrt/kernel32/bcrypt) stay dynamic.
        #   -lbcrypt                       : BCryptGenRandom (core:crypto/rand seeding)
        #   --defsym __chkstk=___chkstk_ms : Odin/LLVM emits the MSVC stack-probe symbol
        #     `__chkstk`; mingw ships the interface-compatible `___chkstk_ms` (x86-64: both
        #     probe RAX bytes, leave RSP to the caller). Aliasing is the standard fix that
        #     Rust/Zig also use when linking LLVM output against mingw.
        LINK_LIBS=(-static-libgcc -lbcrypt -Wl,--defsym,__chkstk=___chkstk_ms)
        # mcfgthreads lib dir(s) — from the flake (ODIN_CROSS_WINDOWS_LIBDIRS); static-link.
        for d in ${ODIN_CROSS_WINDOWS_LIBDIRS:-}; do LINK_LIBS+=(-L"$d"); done
        LINK_LIBS+=(-Wl,-Bstatic -lmcfgthread -Wl,-Bdynamic)
        ;;
    *)
        echo "build_cross.sh: unknown target '$TARGET' (expected linux|windows)" >&2
        exit 2
        ;;
esac

OUT_DIR="${3:-$PROJ/bin/$TARGET}"
mkdir -p "$OUT_DIR"

if [[ -z "$CC" || ! -x "$(command -v "$CC" 2>/dev/null || echo /nonexistent)" ]]; then
    echo "build_cross.sh: no $TARGET cross C compiler found." >&2
    echo "  Set ODIN_CROSS_${TARGET^^}_CC, or enter the Nix dev shell (it exports it)." >&2
    echo "  e.g. nix develop --command bash -c 'bash build/build_cross.sh $TARGET'" >&2
    exit 3   # SKIP sentinel: toolchain unavailable (gate on this, like the web tests).
fi
echo "build_cross.sh: $TARGET cross CC = $CC"

# ----------------------------------------------------------------------------
# odin_obj_link <pkg_dir> <out_lib> [extra odin flags...]
#   Emit ONE relocatable object for the target, then cross-link it into a shared lib.
#   The link goes to a TEMP path and is published with an atomic `mv -f` (same
#   invariant as atomic_odin_dll in common.sh: the live lib is never missing or
#   half-written if the build fails or is interrupted).
# ----------------------------------------------------------------------------
odin_obj_link() {
    local pkg="$1" out="$2"; shift 2
    local dir leaf tmp obj
    dir="$(dirname "$out")"
    leaf="$(basename "$out")"
    tmp="$dir/.$leaf.tmp$EXT"
    obj="$dir/.$leaf.tmp.o"
    rm -f "$tmp" "$obj"

    "$ODIN" build "$pkg" \
        -collection:godot="$ROOT" \
        -build-mode:obj \
        -target:"$ODIN_TARGET" \
        -use-single-module \
        -reloc-mode:pic \
        -out:"$obj" \
        "$@"

    # -shared: a loadable module Godot dlopen/LoadLibrary's. The cross gcc wrapper
    # supplies the target crt/libc/libgcc + dynamic linker for us.
    "$CC" -shared -o "$tmp" "$obj" "${LINK_LIBS[@]}"
    mv -f "$tmp" "$out"
    rm -f "$obj"
}

# CORE dll (always built — the stable C-ABI entry the .gdextension points at).
CORE_OUT="$OUT_DIR/libodin_godot$EXT"
odin_obj_link "$ROOT/core" "$CORE_OUT"

# CORE_ONLY=1 (used by the dist assembly): the scripts dll is compiled per CONSUMER
# project, not shipped, so stop after the core.
if [[ "${CORE_ONLY:-0}" == "1" ]]; then
    echo "build_cross.sh: built (core only)"
    echo "  $CORE_OUT"
    file "$CORE_OUT" || true
    exit 0
fi

# SCRIPTS dll: scriptgen preprocess the project's scripts, then build the dll (same
# custom attributes as the native/web builds). scriptgen goes to a writable TEMP dir, never
# into the addon (read-only when installed under res://addons/); SGEN_BIN reuses a prebuilt one.
build_scriptgen
run_scriptgen "$SCRIPTS"
SCRIPTS_OUT="$OUT_DIR/libodinscripts$EXT"
odin_obj_link "$SCRIPTS" "$SCRIPTS_OUT" \
    ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
    ${SCRIPT_BUILD_FLAGS:-}

echo "build_cross.sh: built"
echo "  $CORE_OUT"
echo "  $SCRIPTS_OUT"
file "$CORE_OUT" "$SCRIPTS_OUT" || true
