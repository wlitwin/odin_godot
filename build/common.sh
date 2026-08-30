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
ODIN_GD_ATTRS=(-custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_input -custom-attribute:gd_sample -custom-attribute:gd_step -custom-attribute:gd_cue -custom-attribute:gd_fact -custom-attribute:gd_half -custom-attribute:gd_message)

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

# Remove staging directories abandoned by a process that no longer exists. Every helper
# names its stages `.<base>.build.<pid>.*`; a live producer is never touched, while an
# editor/compiler killed too abruptly to run EXIT cleanup does not leak artifacts forever.
odin_gd_prune_stale_stages() {
    local dir="$1" base="$2" stage tail pid
    for stage in "$dir/.$base.build."*; do
        [[ -d "$stage" ]] || continue
        tail="${stage##*/.$base.build.}"
        pid="${tail%%.*}"
        case "$pid" in
            ''|*[!0-9]*) continue ;;
        esac
        if kill -0 "$pid" 2>/dev/null; then
            continue
        fi
        rm -rf "$stage"
    done
}

# ----------------------------------------------------------------------------
# odin_build_filtered <odin build args...> — run `odin build`, and on SUCCESS strip
# the wall of benign dsymutil warnings that otherwise makes every first macOS build
# look half-broken. `-use-single-module` (and Odin's per-symbol object stabs on any
# -debug build) leaves dsymutil unable to find runtime helpers it inlined out of the
# final image, so it warns once each — over a thousand lines of
#   warning: (arm64)  could not find symbol '_runtime::...' in object file '...'
# that mean nothing and bury any real message. We capture stderr and, ONLY when the
# build SUCCEEDS, drop exactly that one line shape; a FAILED build passes its stderr
# through verbatim (a genuine compile/link error is NEVER hidden) and returns odin's
# exit code so callers under `set -e` abort exactly as before.
# macOS-only cosmetic — no mirror needed in build_scripts.ps1 (Windows has no dsymutil).
# ----------------------------------------------------------------------------
odin_build_filtered() {
    local errf rc=0
    errf="$(mktemp)"
    odin_gd_cleanup_on_exit "$errf"
    "$ODIN" build "$@" 2>"$errf" || rc=$?
    if [[ "$rc" != "0" ]]; then
        cat "$errf" >&2
    else
        grep -vE "^warning: \([a-z0-9_]+\)  ?could not find symbol '.*' in object file '.*'\$" "$errf" >&2 || true
    fi
    rm -f "$errf"
    return "$rc"
}

# ----------------------------------------------------------------------------
# build_scriptgen — build the //gd: codegen preprocessor and set SGEN to its path.
#
# Builds to a writable user cache, NEVER into the addon: when odin_godot is installed
# under res://addons/ that dir may be read-only (and shouldn't collect build artifacts
# or leak a binary into res:// that the exporter would pack). The content-addressed key
# covers the host/compiler binary + version and every scriptgen/godot:decl source, so a
# hit is safe across projects while edits/toolchain changes rebuild automatically.
#
# SGEN_BIN (env): if set to an executable, use it as-is and SKIP the rebuild — a test
# runner can still provide and fan out an explicit binary.
# ----------------------------------------------------------------------------
_odin_gd_sha256_stdin() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    else
        return 1
    fi
}

build_scriptgen() {
    if [[ -n "${SGEN_BIN:-}" && -x "${SGEN_BIN}" ]]; then
        SGEN="$SGEN_BIN"
        echo "common.sh: using prebuilt scriptgen (SGEN_BIN=$SGEN)"
        return 0
    fi

    local compiler_path compiler_version key cache_base cache_dir candidate_dir candidate src rel
    compiler_path="$(command -v "$ODIN" 2>/dev/null || true)"
    [[ -n "$compiler_path" ]] || compiler_path="$ODIN"
    compiler_version="$("$ODIN" version 2>&1)"

    # Paths are included relative to ROOT, followed by their bytes. `decl` is the only
    # godot: package scriptgen imports; compiler-bundled core packages are pinned by the
    # exact compiler binary digest in the same stream.
    key="$({
        printf 'odin_godot-scriptgen-cache-v1\0'
        printf 'host=%s/%s\0' "$(uname -s)" "$(uname -m)"
        printf 'compiler-path=%s\0compiler-version=%s\0' "$compiler_path" "$compiler_version"
        printf 'compiler-bytes\0'
        cat "$compiler_path"
        find "$ROOT/scriptgen" "$ROOT/decl" -type f -name '*.odin' -print | LC_ALL=C sort |
            while IFS= read -r src; do
                rel="${src#"$ROOT"/}"
                printf '\0source=%s\0' "$rel"
                cat "$src"
            done
    } | _odin_gd_sha256_stdin)" || key=""

    # A minimal host without a SHA-256 utility still works; it simply gets the old
    # per-invocation temp build rather than an unsafely keyed cache entry.
    if [[ -z "$key" ]]; then
        cache_dir="$(mktemp -d)"
        odin_gd_cleanup_on_exit "$cache_dir"
        SGEN="$cache_dir/scriptgen"
        odin_build_filtered "$ROOT/scriptgen" \
            -collection:godot="$ROOT" \
            -out:"$SGEN" \
            -debug
        return 0
    fi

    if [[ -n "${ODIN_GODOT_TOOL_CACHE_DIR:-}" ]]; then
        cache_base="$ODIN_GODOT_TOOL_CACHE_DIR"
    elif [[ -n "${XDG_CACHE_HOME:-}" ]]; then
        cache_base="$XDG_CACHE_HOME/odin_godot"
    else
        cache_base="${TMPDIR:-/tmp}/odin_godot-tools-${UID:-user}"
    fi
    cache_dir="$cache_base/scriptgen/$key"
    SGEN="$cache_dir/scriptgen"
    if [[ -x "$SGEN" ]]; then
        echo "common.sh: scriptgen cache hit ($key)"
        return 0
    fi

    mkdir -p "$cache_dir"
    chmod 700 "$cache_dir" 2>/dev/null || true
    odin_gd_prune_stale_stages "$cache_dir" "scriptgen"
    candidate_dir="$(mktemp -d "$cache_dir/.scriptgen.build.$$.XXXXXX")"
    candidate="$candidate_dir/scriptgen"
    odin_gd_cleanup_on_exit "$candidate_dir"
    # -debug is cheap for a small host tool and makes a scriptgen crash debuggable.
    local build_rc=0
    odin_build_filtered "$ROOT/scriptgen" \
        -collection:godot="$ROOT" \
        -out:"$candidate" \
        -debug || build_rc=$?
    if [[ "$build_rc" != "0" ]]; then
        rm -rf "$candidate_dir"
        return "$build_rc"
    fi
    # Publish the primary artifact first. If that move cannot replace the cache entry,
    # its matching old symbols remain untouched too.
    mv -f "$candidate" "$SGEN"
    # A successful build which emitted no symbols invalidates an older cached sidecar.
    rm -rf "$SGEN.dSYM"
    if [[ -d "$candidate.dSYM" ]]; then
        mv -f "$candidate.dSYM" "$SGEN.dSYM"
    fi
    chmod 700 "$SGEN"
    rm -rf "$candidate_dir"
    echo "common.sh: cached scriptgen ($key)"
}

# run_scriptgen <scripts_dir> [project_dir] — emit the one odin_godot_scripts.gen.odin
# (plus the guard and boot shims) beside the authored sources. The optional project root
# gives every generated class its canonical res:// source identity.
# -godot:<root> lets scriptgen resolve nested `using` bundles imported from godot:kit/*
# (nested-replicate-fields Phase 2) — the same collection root the binding compiles against.
run_scriptgen() {
    if [[ $# -ge 2 && -n "$2" ]]; then
        "$SGEN" "$1" -godot:"$ROOT" -project:"$2"
    else
        "$SGEN" "$1" -godot:"$ROOT"
    fi
}

# authored_sources_fingerprint <scripts_dir> — a deterministic, path-aware digest of
# compiler-authored inputs. Build scripts use it as a transaction fence around
# scriptgen+compile: if a save/delete lands mid-build, regenerate and retry rather than
# surfacing a transient stale-generated-code failure. Empty means SHA-256 unavailable.
authored_sources_fingerprint() {
    local dir="$1" src rel
    {
        find "$dir" \
            \( -type d \( -name '.*' -o -name bin \) -prune \) -o \
            \( -type f -name '*.odin' ! -name '*.gen.odin' -print \) |
            LC_ALL=C sort |
            while IFS= read -r src; do
                rel="${src#"$dir"/}"
                printf 'source=%s\0' "$rel"
                # A delete between find and cat is itself a fingerprint change, not a
                # reason for this observation pass to abort.
                if ! cat "$src" 2>/dev/null; then
                    printf '\0missing-during-scan\0'
                fi
            done
    } | _odin_gd_sha256_stdin
}

# ----------------------------------------------------------------------------
# lex_norm_path <path> — normalize `.`/`..` segments PURELY LEXICALLY (no filesystem
# access, so a target that doesn't exist still normalizes). The bash twin of
# scriptgen's resolve_lexical; input must be absolute.
# ----------------------------------------------------------------------------
lex_norm_path() {
    local rest="$1" out="" seg
    while [[ -n "$rest" ]]; do
        seg="${rest%%/*}"
        if [[ "$rest" == */* ]]; then rest="${rest#*/}"; else rest=""; fi
        case "$seg" in
            ''|.) ;;
            ..)   out="${out%/*}" ;;
            *)    out="$out/$seg" ;;
        esac
    done
    echo "$out"
}

# ----------------------------------------------------------------------------
# check_module_isolation <scripts_dir>
#
# HARD RULE: no imports between script modules. Odin happily compiles a relative
# `import "../other_module"` — but a package imported by two script dlls duplicates its
# package GLOBALS per dll (the shared blackboard would silently fork). So a `..`
# relative import in a script module is rejected here, at build time. Cross-module
# communication goes through the ENGINE: signals, methods (gd.object_call), autoloads.
#
# THE ONE EXEMPTION: `<project>/shared/…`. A package there is read-only VOCABULARY —
# types, constants and pure procs, with no state to fork — so any module may import it
# (`../shared/<pkg>` from res://scripts, `../../shared/<pkg>` from res://modules/<name>).
# A `..` import is allowed here exactly when it RESOLVES into that tree; scriptgen then
# verifies the tree really is state-free (scriptgen/shared.odin). An import whose target
# cannot be resolved is treated as illegal, like any other escape.
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
    local dir="$1" hits abs parent proj shared line imp resolved bad=""
    hits="$(find "$dir" -maxdepth 1 -name '*.odin' ! -name '*.gen.odin' -print0 2>/dev/null |
        xargs -0 grep -nE \
        '^[[:space:]]*(@\(require\)[[:space:]]*)?import[[:space:]]+([A-Za-z_][A-Za-z0-9_]*[[:space:]]+)?"\.\.' \
        2>/dev/null || true)"
    [[ -z "$hits" ]] && return 0

    # The project dir is the module dir's PARENT, or its GRANDPARENT when that parent is
    # `modules` — the same structural rule scriptgen uses (shared_root_of).
    abs="$(cd "$dir" 2>/dev/null && pwd)" || abs="$dir"
    parent="$(dirname "$abs")"
    if [[ "$(basename "$parent")" == "modules" ]]; then
        proj="$(dirname "$parent")"
    else
        proj="$parent"
    fi
    shared="$proj/shared"

    # Every hit is `path:line:text`; keep the ones that do NOT resolve into shared/.
    # (The importing file is at the module root by construction — -maxdepth 1 above.)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        imp="$(printf '%s\n' "$line" | sed -n 's/.*"\(\.\.[^"]*\)".*/\1/p')"
        resolved=""
        [[ -n "$imp" ]] && resolved="$(lex_norm_path "$abs/$imp")"
        if [[ -n "$resolved" && ( "$resolved" == "$shared" || "$resolved" == "$shared"/* ) ]]; then
            continue
        fi
        bad="$bad$line"$'\n'
    done <<EOF
$hits
EOF

    if [[ -n "$bad" ]]; then
        echo "build_scripts: ILLEGAL cross-module import in '$dir':" >&2
        printf '%s' "$bad" >&2
        echo "  Script modules are ISOLATED packages: a package imported by two script dlls" >&2
        echo "  duplicates its globals per dll (shared state would silently fork). Talk to" >&2
        echo "  other modules through the engine (signals / methods / autoloads) instead," >&2
        echo "  or move the shared state into exactly one module." >&2
        echo "  For types, constants and pure procs — a vocabulary with no state to fork —" >&2
        echo "  put the package under '$shared' instead: any module may import it, and" >&2
        echo "  scriptgen verifies that tree stays state-free." >&2
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# atomic_odin_dll <pkg_dir> <out_lib> [extra odin flags...]
#
# Build a shared library with `odin build -build-mode:dll` in a unique TEMP directory
# beside <out_lib>, then atomically `mv -f` it into place (+ the matching .dSYM on macOS
# -debug builds). Why not build straight to <out_lib>:
#   - `odin build -out:X` is NOT atomic — it truncates/creates X up front and writes
#     over several seconds. The editor's reload-on-save coordinator (core/reload.odin)
#     kicks builds on a worker thread; if one is interrupted (editor quits, headless
#     import exits) or fails, building in place leaves NO loadable dll and the core's
#     next load prints "failed to load scripts dll" / "No loader found". temp+mv means
#     an interrupted/failed build simply leaves the previously-built dll alone.
#   - a stale intermediate `.o` built against an OLD runtime layout can survive an
#     incremental `-out:` build and crash at extension init; every invocation gets an
#     isolated staging directory which is removed on success, failure, or shell exit.
#     Concurrent editor/CLI builds therefore cannot delete each other's intermediates.
# (Mirrored in build/build_scripts.ps1 BuildDll — keep them in sync.)
#
# The install_name / .dSYM handling keys off the OUTPUT extension: .dylib gets
# `-Wl,-install_name,<final path>` so the published LC_ID_DYLIB never carries the tmp
# name (the dylib is dlopen'd by absolute path, so the ID is informational anyway);
# .so/.dll outputs get neither flag nor dSYM handling.
# ----------------------------------------------------------------------------
atomic_odin_dll() {
    local pkg="$1" out="$2"; shift 2
    local dir leaf base ext stage tmp
    dir="$(dirname "$out")"
    leaf="$(basename "$out")"
    ext="${leaf##*.}"
    base="${leaf%.*}"
    mkdir -p "$dir"
    # A directory (rather than only a unique output leaf) contains every compiler
    # sidecar too. mktemp creates it on the destination filesystem, so the final move
    # stays atomic; the EXIT registry is the interruption fallback.
    odin_gd_prune_stale_stages "$dir" "$base"
    stage="$(mktemp -d "$dir/.$base.build.$$.XXXXXX")"
    tmp="$stage/$leaf"
    odin_gd_cleanup_on_exit "$stage"

    local link_flags=()
    if [[ "$ext" == "dylib" ]]; then
        link_flags=(-extra-linker-flags:"-Wl,-install_name,$out")
    fi

    # -use-single-module: REQUIRED for usable debug info on macOS. Odin's default for
    # -o:none/-o:minimal is separate modules (one .o per package), and ld then emits a
    # broken one-entry debug map (a single N_OSO stab pointing at one arbitrary .o), so
    # dsymutil produces a near-empty .dSYM: no line tables -> no `b file:line`, no
    # stepping, no `frame variable`. One build unit gives a complete .dSYM with source
    # lines AND named/valued proc arguments in lldb, for ~0.2s extra per dll.
    # (Mirrored in build/build_scripts.ps1 BuildDll — keep them in sync.)
    # odin_build_filtered drops the benign dsymutil warning wall on success and passes
    # a real error through verbatim (see its header). Capture the code so a failed build
    # returns exactly as the bare `odin build` did under set -e.
    local build_rc=0
    odin_build_filtered "$pkg" \
        -collection:godot="$ROOT" \
        -build-mode:dll \
        -use-single-module \
        -out:"$tmp" \
        ${link_flags[@]+"${link_flags[@]}"} \
        "$@" || build_rc=$?
    if [[ "$build_rc" != "0" ]]; then
        rm -rf "$stage"
        return "$build_rc"         # caller runs under set -e — abort exactly as before
    fi
    # Reached only if the build succeeded (callers run under set -e). Publish the primary
    # library first, then replace/remove its .dSYM so stale symbols never survive a
    # successful build, then scrub the isolated stage.
    mv -f "$tmp" "$out"
    rm -rf "$out.dSYM"
    if [[ -d "$tmp.dSYM" ]]; then
        mv -f "$tmp.dSYM" "$out.dSYM"
    fi
    rm -rf "$stage"
}
