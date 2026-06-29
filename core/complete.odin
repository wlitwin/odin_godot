#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "complete"

import "base:runtime"
import "core:os"
import "core:strings"

// ----------------------------------------------------------------------------
// `_complete_code` — REAL editor autocomplete backed by the `ols` Odin language server.
//
// As the user types in a `.odin` script, the editor calls
// `OdinLanguage._complete_code(code, path, owner)` and shows the returned options. We drive
// `ols` over a LIVE-buffer overlay of the script's PACKAGE and map its LSP CompletionItems to
// Godot completion options — so typing `gd.node2d_set_p` offers `node2d_set_position`, etc.
//
// Mirrors the `_validate` engine (validate.odin / diag): the fiddly part — the overlay, the
// batched LSP JSON-RPC handshake, and the CompletionItem parsing — lives in the `complete`
// sub-package (no Godot dep, unit-tested headless by tests/complete/). This file is the thin
// glue: globalize the path, resolve the `ols` binary + collection roots ROBUSTLY, build the
// result Dictionary, and warn ONCE if `ols` can't be found.
//
// Contract: returns `{ result:int(Error), force:bool, call_hint:String, options:Array }`.
// The engine does `ERR_FAIL_COND(!ret.has("result"))`, so "result" is ALWAYS present. ANY
// internal failure returns `{ result: FAILED }` — completion must NEVER break/hang the editor.
// ----------------------------------------------------------------------------

OK :: i64(0)
FAILED :: i64(1)

// Godot collection root (where the `godot` package lives): ProjectSetting `odin_godot/root`
// -> env `ODIN_GODOT_ROOT` -> repo default. (Same resolution validate.odin uses.)
// Package-visible (not file-private) so core/lookup.odin resolves the root the SAME way.
godot_collection_root :: proc(allocator := context.allocator) -> string {
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/root")
    if bool(godot.project_settings_has_setting(ps, key)) {
        def := godot.Variant{}
        v := godot.project_settings_get_setting(ps, key, def)
        s := godot.variant_to_string(&v)
        os_s := string_to_odin(s, allocator)
        if os_s != "" {return os_s}
        delete(os_s, allocator)
    }
    if v, ok := os.lookup_env("ODIN_GODOT_ROOT", allocator); ok && v != "" {
        return v
    }
    return derive_collection_root(allocator)
}

// Resolve a `<dir>/<name>` binary the editor process can reach without inheriting a dev PATH:
// ProjectSetting `<setting>` -> env `<envvar>` -> a `<dir>/<name>` on `$PATH`. Returns
// ("", false) when nothing resolves to an existing file.
// Package-visible (not file-private) so core/lookup.odin resolves ols + share the SAME way.
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
        for dir in strings.split_iterator(&it, ":") {
            if dir == "" {continue}
            cand := strings.concatenate({dir, "/", name}, allocator)
            if os.exists(cand) {return cand, true}
            delete(cand, allocator)
        }
    }
    return "", false
}

// Derive the Odin distribution `share` dir (holding the base/core/vendor/shared collections)
// so ols.json can point at them WITHOUT relying on `odin root` (the editor usually can't reach
// `odin` either). Order: env `ODIN_SHARE` -> ProjectSetting `odin_godot/odin_share` ->
// `<dir(dir(odin))>/share` derived from the resolved `odin` binary (symlinks followed).
// Returns "" if none exists (completion degrades to godot-only collection).
@(private)
resolve_odin_share :: proc(allocator := context.allocator) -> string {
    if v, ok := os.lookup_env("ODIN_SHARE", allocator); ok && v != "" {
        if os.exists(v) {return v}
        delete(v, allocator)
    }
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/odin_share")
    if bool(godot.project_settings_has_setting(ps, key)) {
        def := godot.Variant{}
        v := godot.project_settings_get_setting(ps, key, def)
        s := godot.variant_to_string(&v)
        cand := string_to_odin(s, allocator)
        if cand != "" && os.exists(cand) {return cand}
        delete(cand, allocator)
    }
    odin_bin, found := resolve_bin("odin_godot/odin_bin", "ODIN", "odin", allocator)
    if !found {return ""}
    defer delete(odin_bin, allocator)
    // Follow up to a few symlink levels to the real binary (nix profiles symlink it).
    real := strings.clone(odin_bin, allocator)
    for _ in 0 ..< 8 {
        target, err := os.read_link(real, allocator)
        if err != nil {break}
        // resolve relative symlink against its dir
        if len(target) > 0 && target[0] != '/' {
            if slash := strings.last_index_byte(real, '/'); slash >= 0 {
                joined := strings.concatenate({real[:slash + 1], target}, allocator)
                delete(target, allocator)
                target = joined
            }
        }
        delete(real, allocator)
        real = target
    }
    defer delete(real, allocator)
    // dir(dir(real)) + "/share"
    s1 := strings.last_index_byte(real, '/')
    if s1 <= 0 {return ""}
    parent := real[:s1]
    s2 := strings.last_index_byte(parent, '/')
    if s2 <= 0 {return ""}
    share := strings.concatenate({parent[:s2], "/share"}, allocator)
    if os.exists(share) {return share}
    delete(share, allocator)
    return ""
}

@(private = "file")
warned_no_ols: bool

@(private = "file")
cd_set_int :: proc(d: ^godot.Dictionary, key: cstring, value: i64) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    iv := godot.Int(value)
    vv := godot.variant_from_int(&iv)
    godot.dictionary_set(d, kv, vv)
}

@(private = "file")
cd_set_str :: proc(d: ^godot.Dictionary, key: cstring, value: string) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    s := godot.new_string_odin(value)
    sv := godot.variant_from_string(&s)
    godot.dictionary_set(d, kv, sv)
}

@(private = "file")
cd_set_bool :: proc(d: ^godot.Dictionary, key: cstring, value: bool) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    b := value
    bv := godot.variant_from_bool(&b)
    godot.dictionary_set(d, kv, bv)
}

@(private = "file")
cd_set_arr :: proc(d: ^godot.Dictionary, key: cstring, value: ^godot.Array) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    av := godot.variant_from_array(value)
    godot.dictionary_set(d, kv, av)
}

@(private = "file")
cd_set_color :: proc(d: ^godot.Dictionary, key: cstring, value: godot.Color) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    c := value
    cv := godot.variant_from_color(&c)
    godot.dictionary_set(d, kv, cv)
}

// Set a key to a NIL Variant (the zero value). Used for the option `icon` (an empty
// `Ref<Texture2D>`) and `default_value` (no default) — both keys the engine REQUIRES to be
// present but for which Odin completions carry no value.
@(private = "file")
cd_set_nil :: proc(d: ^godot.Dictionary, key: cstring) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    godot.dictionary_set(d, kv, godot.Variant{})
}

// CodeCompletionLocation::LOCATION_OTHER (1 << 10) — the engine's default "unknown scope"
// bucket. ols gives us no scope-distance info, so every option lands here.
@(private = "file")
LOCATION_OTHER :: i64(1 << 10)

// `_finish` — the engine tears the language down. Kill the persistent ols subprocess (and its
// reader thread + temp workspace) so the editor session leaves nothing behind. Idempotent and
// safe even if the session was never started. Runs on the main thread.
lv_finish_session :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()
    complete.session_shutdown(&complete.g_session)
}

// `_complete_code(code: String, path: String, owner: Object) -> Dictionary`.
// args[0]=code(String, full buffer with a U+FFFF caret marker), args[1]=path(String).
lv_complete_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()

    result := godot.new_dictionary_default()
    options := godot.new_array_default()
    result_code := FAILED

    code := string_to_odin((cast(^godot.String)args[0])^)
    defer delete(code)

    global := godot.project_settings_globalize_path(godot.singleton_project_settings(), (cast(^godot.String)args[1])^)
    abs_path := string_to_odin(global)
    defer delete(abs_path)

    ols_bin, found := resolve_bin("odin_godot/ols_bin", "OLS", "ols")
    defer if found {delete(ols_bin)}

    if !found {
        // ols is unreachable from the editor process — completion can't run. Warn ONCE with
        // an actionable fix (not silently nothing). Common cause: launching the editor from
        // Finder, where the nix-store `ols` isn't on PATH.
        if !warned_no_ols {
            warned_no_ols = true
            msg := godot.new_string_cstring(
                "odin_godot: `ols` not found — Odin script autocomplete is OFF. Fix: set the " +
                "`odin_godot/ols_bin` project setting to your ols binary (absolute path), or " +
                "launch the editor from a shell where `ols` is on PATH.",
            )
            godot.gd_push_warning(godot.variant_from_string(&msg))
        }
    } else if abs_path != "" {
        root := godot_collection_root()
        defer delete(root)
        share := resolve_odin_share()
        defer delete(share)
        // FAST PATH: the persistent ols session (warm ~30-70 ms; no per-request re-index). If
        // the session can't start / died / timed out it returns ok=false and we transparently
        // fall back to the (slower but self-contained) fresh-spawn `run_completion` so
        // completion never regresses. See core/complete/session.odin.
        cs, ok := complete.session_complete(&complete.g_session, code, abs_path, root, share, ols_bin)
        if !ok {
            for c in cs {delete(c.label); delete(c.insert_text); delete(c.detail)}
            delete(cs)
            cs = complete.run_completion(code, abs_path, root, share, ols_bin)
        }
        defer {
            for c in cs {
                delete(c.label)
                delete(c.insert_text)
                delete(c.detail)
            }
            delete(cs)
        }
        // Thin an over-long list (a bare `gd.` is the whole ~24k-proc godot API) to
        // what the user is typing, and cap it — building each option's Dictionary is
        // ~20 FFI calls and the editor renders every row, so an unbounded list stalls
        // the editor for 1-2s. Lists already under MAX_OPTIONS pass through untouched.
        prefix := complete.prefix_at_caret(code)
        filter := len(cs) > complete.MAX_OPTIONS
        emitted := 0
        for c in cs {
            if emitted >= complete.MAX_OPTIONS {break}
            if filter && !complete.matches_prefix(c.label, prefix) {continue}
            od := godot.new_dictionary_default()
            // Emit EVERY key Godot's ScriptLanguageExtension::complete_code ERR_CONTINUEs on
            // (else the option is dropped + the editor log is spammed — the font_color bug).
            // Iterate the canonical field set (core/complete/option_shape.odin) so the emitted
            // keys can never silently drift from what tests/complete asserts. The engine
            // recomputes the SHOWN font_color/icon in CodeTextEditor::_complete_request, so the
            // placeholder values here are cosmetically irrelevant — only the KEYS must exist.
            for f in complete.Completion_Option_Field {
                key := complete.completion_option_field_key(f)
                switch f {
                case .Kind:
                    cd_set_int(&od, key, i64(c.kind))
                case .Display:
                    // Surface the ols type/signature (`detail`) inline in the popup row so
                    // autocomplete shows what a symbol IS, not just its name. Matching/insert
                    // are unaffected (filtering uses c.label; insert_text stays the bare name).
                    if c.detail != "" {
                        disp := strings.concatenate({c.label, "  ", c.detail}, context.temp_allocator)
                        cd_set_str(&od, key, disp)
                    } else {
                        cd_set_str(&od, key, c.label)
                    }
                case .Insert_Text:
                    cd_set_str(&od, key, c.insert_text)
                case .Font_Color:
                    cd_set_color(&od, key, godot.Color{1, 1, 1, 1}) // opaque white placeholder
                case .Icon:
                    cd_set_nil(&od, key) // empty Ref<Texture2D>
                case .Default_Value:
                    cd_set_nil(&od, key) // no inline value
                case .Location:
                    cd_set_int(&od, key, LOCATION_OTHER)
                }
            }
            ov := godot.variant_from_dictionary(&od)
            godot.array_push_back(&options, ov)
            emitted += 1
        }
        result_code = OK // ols ran (0 options is a valid "nothing here", still OK)
    }

    cd_set_int(&result, "result", result_code)
    cd_set_bool(&result, "force", false)
    cd_set_str(&result, "call_hint", "")
    cd_set_arr(&result, "options", &options)
    (cast(^godot.Dictionary)ret)^ = result
}
