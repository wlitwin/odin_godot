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
# needs so authors can mark procs with @(gd_method) / @(gd_connect) / @(gd_rpc) /
# @(gd_command) — the codegen markers scriptgen consumes.
# KEEP IN SYNC with:
#   - build/build_scripts.ps1  (the Windows-native build hardcodes the same five flags)
#   - core/diag/diag.odin      (the in-editor `odin check` diagnostics pass hardcodes them
#                               so @(gd_*) attributes don't produce phantom errors)
#   - core/export_plugin.odin  (the generated ols.json checker_args)
ODIN_GD_ATTRS=(-custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_sample -custom-attribute:gd_step -custom-attribute:gd_fact)

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
# -godot:<root> lets scriptgen resolve nested `using` bundles imported from godot:kit/*
# (nested-replicate-fields Phase 2) — the same collection root the binding compiles against.
run_scriptgen() {
    "$SGEN" "$1" -godot:"$ROOT"
}

# ----------------------------------------------------------------------------
# check_module_isolation <scripts_dir>
#
# HARD RULE: no imports between script modules. Odin happily compiles a relative
# `import "../other_module"` — but a package imported by two script dlls duplicates its
# package GLOBALS per dll (the shared blackboard would silently fork). So any `..`
# relative import in a script module is rejected here, at build time. Cross-module
# communication goes through the ENGINE: signals, methods (gd.object_call), autoloads.
#
# The CANONICAL bash implementation, shared by build_scripts.sh (dev loop) and
# build_export_scripts.sh (export) — ported in build/build_scripts.ps1
# (CheckModuleIsolation; KEEP IN SYNC, including the regex). This grep is the fast
# BACKSTOP: scriptgen enforces the same rule STRUCTURALLY from the AST (absolute-path
# imports and any relative import escaping the module included). docs/modules.md
# quotes the message.
#
# TOP-LEVEL FILES ONLY (-maxdepth 1): at the module root a `..` import always escapes
# the module, so the grep has no false positives there. In SUBDIRECTORIES a `..` import
# can be a legal sibling-helper import (`helpers/a` importing `../b`) — only scriptgen's
# lexical resolution can tell those apart, so subdir depth is left entirely to it.
# ----------------------------------------------------------------------------
check_module_isolation() {
    local dir="$1" hits
    hits="$(find "$dir" -maxdepth 1 -name '*.odin' ! -name '*.gen.odin' -print0 2>/dev/null |
        xargs -0 grep -nE \
        '^[[:space:]]*(@\(require\)[[:space:]]*)?import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*[[:space:]]+)?"\.\.' \
        2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
        echo "build_scripts: ILLEGAL cross-module import in '$dir':" >&2
        echo "$hits" >&2
        echo "  Script modules are ISOLATED packages: a package imported by two script dlls" >&2
        echo "  duplicates its globals per dll (shared state would silently fork). Talk to" >&2
        echo "  other modules through the engine (signals / methods / autoloads) instead," >&2
        echo "  or move the shared state into exactly one module." >&2
        exit 1
    fi
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
    # PID-scoped temp: the EDITOR's reload builds and a CLI gate build race on
    # the same output dir constantly (a live playtest plus an agent gate is
    # the normal state of this project) — fixed temp names made each one eat
    # the other's intermediates mid-link.
    tmp="$dir/.$base.tmp.$$.$ext"

    local link_flags=()
    if [[ "$ext" == "dylib" ]]; then
        link_flags=(-extra-linker-flags:"-Wl,-install_name,$out")
    fi

    rm -f "$tmp" "$dir/.$base.tmp.$$"*.o
    # -use-single-module: REQUIRED for usable debug info on macOS. Odin's default for
    # -o:none/-o:minimal is separate modules (one .o per package), and ld then emits a
    # broken one-entry debug map (a single N_OSO stab pointing at one arbitrary .o), so
    # dsymutil produces a near-empty .dSYM: no line tables -> no `b file:line`, no
    # stepping, no `frame variable`. One build unit gives a complete .dSYM with source
    # lines AND named/valued proc arguments in lldb, for ~0.2s extra per dll.
    # (Mirrored in build/build_scripts.ps1 BuildDll — keep them in sync.)
    "$ODIN" build "$pkg" \
        -collection:godot="$ROOT" \
        -build-mode:dll \
        -use-single-module \
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
    rm -f "$dir/.$base.tmp.$$"*.o
}
