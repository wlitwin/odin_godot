#+build darwin, linux, windows
package core

import "godot:godot"

import "core:os"
import "core:strings"

// ----------------------------------------------------------------------------
// Toolchain / addon-root resolution — the ONE shared implementation used by validate,
// complete, lookup, reload and the export plugin (they previously carried near-identical
// copies that could and did drift — the export plugin fell back to a hardcoded path).
// ----------------------------------------------------------------------------

// Resolve the odin_godot collection root: ProjectSetting `odin_godot/root` ->
// env `ODIN_GODOT_ROOT` -> derived from the core dll's own location (dladdr).
// A consuming project must satisfy one of these so the `godot` collection resolves
// for validation/completion/builds. Returns "" (after a one-shot editor warning)
// when nothing resolves.
odin_collection_root :: proc(allocator := context.allocator) -> string {
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/root")
    if bool(godot.project_settings_has_setting(ps, key)) {
        def := godot.Variant{}
        v := godot.project_settings_get_setting(ps, key, def)
        s := godot.variant_to_string(&v)
        os_s := string_to_odin(s, allocator)
        if os_s != "" {
            return os_s
        }
        delete(os_s, allocator)
    }
    if v, ok := os.lookup_env("ODIN_GODOT_ROOT", allocator); ok && v != "" {
        return v
    }
    return derive_collection_root(allocator)
}

// Historical name used by the completion/lookup glue — same resolver.
godot_collection_root :: odin_collection_root

// One-shot "couldn't find the addon root" warning guard.
@(private = "file")
warned_no_root: bool

// Fallback collection root when neither `odin_godot/root` nor $ODIN_GODOT_ROOT is set: derive
// it from the core dll's OWN on-disk location (via dladdr / GetModuleFileNameW). The core lives
// at <addon>/bin/<platform>/libodin_godot.<ext>, so the addon root — which carries the
// godot/gdext/runtime collection a project compiles against — is two directories up. This
// makes an installed addon zero-config. Returns "" + a one-shot editor warning if it can't be
// derived; NEVER a hardcoded maintainer path, which silently produced false squiggles on
// a consumer's `import "godot:godot"` line.
@(private)
derive_collection_root :: proc(allocator := context.allocator) -> string {
    if dir, ok := core_dll_dir(allocator); ok {
        defer delete(dir, allocator)
        // The INSTALLED layout is <addon>/bin/<platform>/libodin_godot.<ext>, so the addon root
        // is two dirs up. VALIDATE it by checking for the `godot/` collection it must contain —
        // otherwise (e.g. the in-repo dev layout, where the core sits in <project>/bin/) we'd
        // hand back a path with no collection. On a miss, fall through to the warning.
        if up := dir_up_n(dir, 2); up != "" {
            marker := strings.concatenate({up, "/godot"}, allocator)
            defer delete(marker, allocator)
            if os.exists(marker) {
                return strings.clone(up, allocator)
            }
        }
    }
    if !warned_no_root {
        warned_no_root = true
        msg := godot.new_string_cstring(
            "odin_godot: couldn't locate the addon root automatically — set the `odin_godot/root` " +
            "project setting (or the ODIN_GODOT_ROOT env var) to your odin_godot / " +
            "addons/odin_godot directory so validation + autocomplete can resolve " +
            "`import \"godot:godot\"`.",
        )
        godot.gd_push_warning(godot.variant_from_string(&msg))
    }
    return strings.clone("", allocator)
}

// Strip `n` trailing path components ("/a/b/c", 2 -> "/a"). Returns "" if it runs out.
@(private = "file")
dir_up_n :: proc(path: string, n: int) -> string {
    p := path
    for _ in 0 ..< n {
        idx := strings.last_index_byte(p, '/')
        when ODIN_OS == .Windows {
            if bidx := strings.last_index_byte(p, '\\'); bidx > idx {
                idx = bidx
            }
        }
        if idx < 0 {return ""}
        p = p[:idx]
    }
    return p
}

// `$PATH` entry separator (";" on Windows, ":" elsewhere).
when ODIN_OS == .Windows {
    PATH_LIST_SEP :: ";"
} else {
    PATH_LIST_SEP :: ":"
}

// Resolve a `<dir>/<name>` binary the editor process can reach without inheriting a dev PATH:
// ProjectSetting `<setting>` -> env `<envvar>` -> a `<dir>/<name>` on `$PATH` (also
// `<name>.exe` on Windows). Returns ("", false) when nothing resolves to an existing file.
@(private)
resolve_bin :: proc(setting: cstring, envvar: string, name: string, allocator := context.allocator) -> (string, bool) {
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring(setting)
    if bool(godot.project_settings_has_setting(ps, key)) {
        def := godot.Variant{}
        v := godot.project_settings_get_setting(ps, key, def)
        s := godot.variant_to_string(&v)
        cand := string_to_odin(s, allocator)
        if cand != "" && os.exists(cand) {return cand, true}
        delete(cand, allocator)
    }
    if v, ok := os.lookup_env(envvar, allocator); ok && v != "" {
        if os.exists(v) {return v, true}
        delete(v, allocator)
    }
    if pathv, ok := os.lookup_env("PATH", allocator); ok {
        defer delete(pathv, allocator)
        it := pathv
        for dir in strings.split_iterator(&it, PATH_LIST_SEP) {
            if dir == "" {continue}
            cand := strings.concatenate({dir, "/", name}, allocator)
            if os.exists(cand) {return cand, true}
            delete(cand, allocator)
            when ODIN_OS == .Windows {
                cand_exe := strings.concatenate({dir, "/", name, ".exe"}, allocator)
                if os.exists(cand_exe) {return cand_exe, true}
                delete(cand_exe, allocator)
            }
        }
    }
    return "", false
}

// Resolve the absolute path to the `odin` binary so validation/builds don't depend on the
// editor process inheriting a PATH that contains it (it usually won't when launched from
// the macOS app rather than a toolchain shell — odin lives in the nix store). Order:
// ProjectSetting `odin_godot/odin_bin` -> env `ODIN` -> `odin` on `$PATH`.
@(private)
resolve_odin_bin :: proc(allocator := context.allocator) -> (string, bool) {
    return resolve_bin("odin_godot/odin_bin", "ODIN", "odin", allocator)
}
