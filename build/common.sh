# build/common.sh — shared helpers for the odin_godot bash build scripts.
#
# SOURCED (not executed) by build/build_scripts.sh, build/build_web.sh,
# build/build_export_scripts.sh, build/build_cross.sh, build/build_phase{2,3}.sh and
# core/build.sh. Callers must set ROOT (the `godot:` collection root) BEFORE calling
# any helper; everything else defaults here. Written to run on macOS's stock bash 3.2
# too (the addon ships these scripts to machines without Nix), hence the
# `${arr[@]+"${arr[@]}"}` empty-array expansions.

# The `odin` compiler. Overridable via env so callers that resolved an absolute compiler
# path (e.g. the editor reload-on-save coordinator or the export plugin, which can't rely
# on `odin` being on the editor's PATH when launched from Finder/Steam) can pass it
# through as `ODIN=/abs/path/to/odin`.
ODIN="${ODIN:-odin}"

# The custom-attribute flags EVERY scripts build (native dll, wasm object, cross object)
# needs so authors can mark procs with @(gd_method) / @(gd_connect) / @(gd_rpc) — the
# codegen markers scriptgen consumes.
# KEEP IN SYNC with:
#   - build/build_scripts.ps1  (the Windows-native build hardcodes the same three flags)
#   - core/diag/diag.odin      (the in-editor `odin check` diagnostics pass hardcodes them
#                               so @(gd_*) attributes don't produce phantom errors)
ODIN_GD_ATTRS=(-custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc)

# Host shared-library extension for NATIVE builds (cross builds pick their own — see
# build/build_cross.sh). Windows native builds use build_scripts.ps1, not these scripts.
case "$(uname -s)" in
    Darwin) DLL_EXT="dylib" ;;
    *)      DLL_EXT="so" ;;
esac

# ----------------------------------------------------------------------------
# Cleanup registry. bash keeps only ONE EXIT trap, so scripts must not set their own
# `trap … EXIT` after sourcing this file — register paths here instead.
# ----------------------------------------------------------------------------
_ODIN_GD_CLEANUP=()
odin_gd_cleanup_on_exit() { _ODIN_GD_CLEANUP+=("$@"); }
_odin_gd_do_cleanup() {
    local p
    for p in ${_ODIN_GD_CLEANUP[@]+"${_ODIN_GD_CLEANUP[@]}"}; do
        rm -rf "$p"
    done
}
trap _odin_gd_do_cleanup EXIT

# ----------------------------------------------------------------------------
# build_scriptgen — build the //gd: codegen preprocessor and set SGEN to its path.
#
# Builds to a writable TEMP dir, NEVER into the addon: when odin_godot is installed
# under res://addons/ that dir may be read-only (and shouldn't collect build artifacts
# or leak a binary into res:// that the exporter would pack).
#
# SGEN_BIN (env): if set to an executable, use it as-is and SKIP the rebuild — a test
# runner can pre-build scriptgen once and fan it out across many script builds. Default
# (unset) keeps today's behavior: build fresh per invocation.
# ----------------------------------------------------------------------------
build_scriptgen() {
    if [[ -n "${SGEN_BIN:-}" && -x "${SGEN_BIN}" ]]; then
        SGEN="$SGEN_BIN"
        echo "common.sh: using prebuilt scriptgen (SGEN_BIN=$SGEN)"
        return 0
    fi
    local dir
    dir="$(mktemp -d)"
    odin_gd_cleanup_on_exit "$dir"
    SGEN="$dir/scriptgen"
    # -debug is cheap for a small host tool and makes a scriptgen crash debuggable.
    "$ODIN" build "$ROOT/scriptgen" \
        -collection:godot="$ROOT" \
        -out:"$SGEN" \
        -debug
}

# run_scriptgen <scripts_dir> — emit the *.gen.odin siblings beside the authored sources.
run_scriptgen() {
    "$SGEN" "$1"
}

# ----------------------------------------------------------------------------
# atomic_odin_dll <pkg_dir> <out_lib> [extra odin flags...]
#
# Build a shared library with `odin build -build-mode:dll` to a TEMP path beside
# <out_lib>, then atomically `mv -f` it into place (+ the matching .dSYM on macOS
# -debug builds). Why not build straight to <out_lib>:
#   - `odin build -out:X` is NOT atomic — it truncates/creates X up front and writes
#     over several seconds. The editor's reload-on-save coordinator (core/reload.odin)
#     kicks builds on a worker thread; if one is interrupted (editor quits, headless
#     import exits) or fails, building in place leaves NO loadable dll and the core's
#     next load prints "failed to load scripts dll" / "No loader found". temp+mv means
#     an interrupted/failed build simply leaves the previously-built dll alone.
#   - a stale intermediate `.o` built against an OLD runtime layout can survive an
#     incremental `-out:` build and crash at extension init; the temp path is scrubbed
#     before AND after, so every publish is a clean build.
# (Mirrored in build/build_scripts.ps1 BuildDll — keep them in sync.)
#
# The install_name / .dSYM handling keys off the OUTPUT extension: .dylib gets
# `-Wl,-install_name,<final path>` so the published LC_ID_DYLIB never carries the tmp
# name (the dylib is dlopen'd by absolute path, so the ID is informational anyway);
# .so/.dll outputs get neither flag nor dSYM handling.
# ----------------------------------------------------------------------------
atomic_odin_dll() {
    local pkg="$1" out="$2"; shift 2
    local dir leaf base ext tmp
    dir="$(dirname "$out")"
    leaf="$(basename "$out")"
    ext="${leaf##*.}"
    base="${leaf%.*}"
    tmp="$dir/.$base.tmp.$ext"

    local link_flags=()
    if [[ "$ext" == "dylib" ]]; then
        link_flags=(-extra-linker-flags:"-Wl,-install_name,$out")
    fi

    rm -f "$tmp" "$dir/.$base.tmp-"*.o
    "$ODIN" build "$pkg" \
        -collection:godot="$ROOT" \
        -build-mode:dll \
        -out:"$tmp" \
        ${link_flags[@]+"${link_flags[@]}"} \
        "$@"
    # Reached only if the build succeeded (callers run under set -e). Publish the .dSYM
    # first (rm the old one even if the new build emitted none — no stale symbols), then
    # the library itself, then scrub the temp intermediates.
    rm -rf "$out.dSYM"
    if [[ -d "$tmp.dSYM" ]]; then
        mv -f "$tmp.dSYM" "$out.dSYM"
    fi
    mv -f "$tmp" "$out"
    rm -f "$dir/.$base.tmp-"*.o
}
