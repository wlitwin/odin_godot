#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "diag"

import "base:runtime"

// ----------------------------------------------------------------------------
// `_validate` — REAL Odin compiler diagnostics surfaced as editor squiggles.
//
// The editor calls `OdinLanguage._validate(script, path, ...)` as the user types
// (debounced). We type/parse-check the script's PACKAGE with the real `odin` compiler and
// return `{ valid: bool, errors: [ { line, column, message } ] }`. A broken script then
// shows a red squiggle + an Errors-panel entry instead of silently compiling to nothing.
//
// Why the whole package (not the single file): a `.odin` file is not a standalone compile
// unit — its package needs the sibling scripts, the scriptgen `*.gen.odin`, and the `godot`
// collection. So we type-check the package DIRECTORY.
//
// LIVE buffer overlay: `script` (args[0]) is the possibly-UNSAVED editor text. To validate
// what the user is typing we copy the package dir to a temp overlay, overwrite the edited
// file with `script`, run `odin check` there, and map errors back by file basename. The
// actual overlay+check+parse pipeline lives in the `diag` sub-package (so it is unit-
// testable headless — the `_validate` virtual itself is engine-dispatched and NOT callable
// from GDScript; see tests/validate/).
//
// Robustness: ANY failure returns `{ valid: true, errors: [] }` — a dev-experience feature
// must NEVER break the editor. v1 spawns one `odin check` per (debounced) validate call;
// an ols-backed incremental check is a later autocomplete-phase improvement.
// ----------------------------------------------------------------------------

// The odin_collection_root / resolve_odin_bin resolvers this file used to own now live in
// core/resolve.odin (shared with complete/lookup/reload/export_plugin).

// One-time guard so the "odin not found" warning isn't spammed on every keystroke.
@(private = "file")
warned_no_odin: bool

@(private = "file")
vd_set_int :: proc(d: ^godot.Dictionary, key: cstring, value: i64) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    iv := godot.Int(value)
    vv := godot.variant_from_int(&iv)
    godot.dictionary_set(d, kv, vv)
}

@(private = "file")
vd_set_str :: proc(d: ^godot.Dictionary, key: cstring, value: string) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    s := godot.new_string_odin(value)
    sv := godot.variant_from_string(&s)
    godot.dictionary_set(d, kv, sv)
}

@(private = "file")
vd_set_bool :: proc(d: ^godot.Dictionary, key: cstring, value: bool) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    b := value
    bv := godot.variant_from_bool(&b)
    godot.dictionary_set(d, kv, bv)
}

@(private = "file")
vd_set_arr :: proc(d: ^godot.Dictionary, key: cstring, value: ^godot.Array) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    av := godot.variant_from_array(value)
    godot.dictionary_set(d, kv, av)
}

// `_validate(script, path, validate_functions, validate_errors, validate_warnings,
//  validate_safe_lines) -> Dictionary`. args[0]=script(String), args[1]=path(String).
lv_validate :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()

    result := godot.new_dictionary_default()
    errors := godot.new_array_default()

    script := (cast(^godot.String)args[0])^
    path := (cast(^godot.String)args[1])^

    source := string_to_odin(script)
    defer delete(source)

    // Globalize the (possibly res://) path to an absolute filesystem path.
    global := godot.project_settings_globalize_path(godot.singleton_project_settings(), path)
    abs_path := string_to_odin(global)
    defer delete(abs_path)

    n := 0
    odin_bin, found := resolve_odin_bin()
    defer if found {delete(odin_bin)}

    if !found {
        // `odin` is unreachable from the editor process — validation can't run. Do NOT
        // fail silently (that just looks like "validation does nothing"): warn ONCE, with
        // an actionable fix, then return valid so the editor is never blocked. Common cause:
        // launching the editor outside the toolchain shell (e.g. the macOS app from Finder),
        // so the nix-store `odin` isn't on PATH.
        if !warned_no_odin {
            warned_no_odin = true
            msg := godot.new_string_cstring(
                "odin_godot: `odin` not found — Odin script validation is OFF. Fix: set the " +
                "`odin_godot/odin_bin` project setting to your odin binary (absolute path), or " +
                "launch the editor from a shell where `odin` is on PATH.",
            )
            godot.gd_push_warning(godot.variant_from_string(&msg))
        }
    } else if abs_path != "" {
        root := odin_collection_root()
        defer delete(root)
        // NON-BLOCKING: returns the last-known diagnostics instantly and (re)schedules a
        // single background worker to run the slow `odin check` off the main thread. The
        // editor re-validates on its debounce timer, so a freshly-computed result is picked
        // up on a later call — the UI never freezes waiting on the check. See core/diag/async.
        ds, _ := diag.validate_async(&diag.g_validate, source, abs_path, root, odin_bin)
        defer {
            for d in ds {delete(d.message)}
            delete(ds)
        }
        for d in ds {
            ed := godot.new_dictionary_default()
            vd_set_int(&ed, "line", i64(d.line))
            vd_set_int(&ed, "column", i64(d.column))
            vd_set_str(&ed, "message", d.message)
            ev := godot.variant_from_dictionary(&ed)
            godot.array_push_back(&errors, ev)
            n += 1
        }
    }

    vd_set_bool(&result, "valid", n == 0)
    vd_set_arr(&result, "errors", &errors)
    (cast(^godot.Dictionary)ret)^ = result
}
