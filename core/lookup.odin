#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "complete"
import "lookup"

import "base:runtime"
import "core:os"
import "core:strings"
import "core:sync"

// ----------------------------------------------------------------------------
// `_lookup_code` — REAL goto-definition ("Lookup Symbol" / Ctrl+Cmd-click) for the `gd.*`
// bindings, opening Godot's BUILT-IN class documentation — exactly like GDScript does when
// you Ctrl-click a built-in function.
//
// WHY this works: the `gd.*` package is a 1:1 projection of Godot's API. The binding proc
// `gd.node2d_set_position` IS `Node2D.set_position`; Godot already ships docs for it. GDScript's
// `_lookup_code` returns a `LookupResult` of type CLASS_METHOD carrying {class_name, class_member};
// the editor's ScriptTextEditor then opens the class reference at that member. We do the same:
// map the clicked binding symbol back to its (PascalClass, member), classify the member via
// ClassDB, and hand the editor the matching LookupResult.
//
// CONTRACT (verified against Godot 4.6 `core/object/script_language_extension.h`
// ScriptLanguageExtension::lookup_code, AND this build's extension_api.json):
//   `_lookup_code(code: String, symbol: String, path: String, owner: Object) -> Dictionary`
//   args = { [0]=code, [1]=symbol, [2]=path, [3]=owner }   (symbol is args[1])
//   The consumer does `ERR_FAIL_COND_V(!ret.has("result"))` AND `ERR_FAIL_COND_V(!ret.has("type"))`
//   UNCONDITIONALLY (even on a failed lookup) — so BOTH keys must ALWAYS be present or the editor
//   spams the console on every click. It then reads (all optional, defaulted):
//     class_name (String, ""), class_member (String, ""), description, value, script,
//     script_path, location (-1), enumeration, ... — we only need class_name + class_member.
//   LookupResultType enum (authoritative, from godot/script_language_extension.gen.odin which is
//   generated from extension_api.json):
//     SCRIPT_LOCATION=0 CLASS=1 CLASS_CONSTANT=2 CLASS_PROPERTY=3 CLASS_METHOD=4 CLASS_SIGNAL=5
//     CLASS_ENUM=6 CLASS_TBD_GLOBALSCOPE=7 CLASS_ANNOTATION=8 (... LOCAL_*; MAX=11)  ; result OK=0.
//
// Like `_complete_code`, this virtual is engine-dispatched (NOT callable from GDScript), so the
// pure symbol->(class,member) mapping is factored into `resolve_symbol` and unit-tested headless
// (tests/lookup). The ClassDB classification + the editor actually opening the docs page can only
// be confirmed interactively (Cmd+click in the script editor).
//
// LIMITATION (graceful FAILED, never a crash): only ClassDB classes resolve. Global utility
// functions in `gd` (e.g. `gd.print`, `gd.deg_to_rad`) carry no `<class>_` prefix and the builtin
// Variant types (Vector2, Color, AABB, ...) are not ClassDB classes (their gen files carry no
// `__class_name` line), so symbols like `gd.vector2_angle` won't resolve — they return the safe
// `{result: FAILED, type: 0}` shape, leaving the editor quiet.
// ----------------------------------------------------------------------------

// LookupResultType values (see contract above).
LOOKUP_RESULT_SCRIPT_LOCATION :: i64(0)
LOOKUP_RESULT_CLASS :: i64(1)
LOOKUP_RESULT_CLASS_CONSTANT :: i64(2)
LOOKUP_RESULT_CLASS_PROPERTY :: i64(3)
LOOKUP_RESULT_CLASS_METHOD :: i64(4)
LOOKUP_RESULT_CLASS_SIGNAL :: i64(5)

// ---- caches (persistent, heap-allocated; built lazily on first lookup) ----
@(private = "file")
g_lookup_mutex: sync.Mutex
@(private = "file")
g_class_set: map[string]bool // snake binding-prefix (gen-file basename) -> present
@(private = "file")
g_class_set_built: bool
@(private = "file")
g_snake_to_pascal: map[string]string // snake -> PascalName (negative-cached as "")

// The PURE symbol -> (class, member) mapping lives (no Godot deps, unit-tested headless) in the
// `core/lookup` sub-package; `lv_lookup_code` calls `lookup.resolve_symbol`.

// ---- cache builders (assume context.allocator == heap; caller holds g_lookup_mutex) ----

// Build the snake-class set from `<root>/godot/*.gen.odin` basenames (strip `.gen.odin`). This is
// the authoritative class list — no snake-case algorithm needed. Keys are heap-owned copies (the
// File_Info names live in the temp allocator).
@(private = "file")
ensure_class_set :: proc() {
    if g_class_set_built {
        return
    }
    g_class_set = make(map[string]bool)
    g_snake_to_pascal = make(map[string]string)
    root := godot_collection_root()
    defer delete(root)
    dir := strings.concatenate({root, "/godot"})
    defer delete(dir)
    fis, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
    if err == nil {
        for fi in fis {
            if !strings.has_suffix(fi.name, ".gen.odin") {
                continue
            }
            base := fi.name[:len(fi.name) - len(".gen.odin")]
            if base == "" {
                continue
            }
            g_class_set[strings.clone(base)] = true
        }
    }
    g_class_set_built = true // even on a read error: a one-shot empty set degrades to graceful-miss
}

// Resolve (and cache) the authoritative Pascal class name for a snake class by reading the single
// `__class_name = new_string_name_cstring("<Pascal>", ...)` line in `<root>/godot/<snake>.gen.odin`.
// Negative results cache as "" so a missing/non-ClassDB file isn't re-read each click.
@(private = "file")
pascal_for :: proc(snake: string) -> (string, bool) {
    if p, found := g_snake_to_pascal[snake]; found {
        return p, p != ""
    }
    root := godot_collection_root()
    defer delete(root)
    path := strings.concatenate({root, "/godot/", snake, ".gen.odin"})
    defer delete(path)

    pascal := ""
    if data, rerr := os.read_entire_file(path, context.temp_allocator); rerr == nil {
        text := string(data)
        marker := "__class_name = new_string_name_cstring(\""
        if idx := strings.index(text, marker); idx >= 0 {
            rest := text[idx + len(marker):]
            if end := strings.index_byte(rest, '"'); end >= 0 {
                pascal = strings.clone(rest[:end]) // heap-owned (persistent cache)
            }
        }
    }
    g_snake_to_pascal[strings.clone(snake)] = pascal // cache even "" (negative)
    return pascal, pascal != ""
}

// Classify a member of `pascal` via ClassDB and pick the LookupResultType. Methods are by far the
// common case (binding procs are `set_`/`get_` methods); signals/constants are single cheap calls;
// a property requires scanning the property list. If NONE recognize it we fall back to CLASS (open
// the class page — still useful) rather than failing.
@(private = "file")
classify_member :: proc(pascal: string, member: string) -> i64 {
    cdb := godot.singleton_class_db()
    class_sn := godot.new_string_name_cstring(strings.clone_to_cstring(pascal, context.temp_allocator), false)
    member_sn := godot.new_string_name_cstring(strings.clone_to_cstring(member, context.temp_allocator), false)

    // Binding files carry only the class's OWN members, so no_inheritance=false is harmless and
    // keeps classification lenient (an inherited hit still opens the right class page).
    if bool(godot.class_db_class_has_method(cdb, class_sn, member_sn, false)) {
        return LOOKUP_RESULT_CLASS_METHOD
    }
    if bool(godot.class_db_class_has_signal(cdb, class_sn, member_sn)) {
        return LOOKUP_RESULT_CLASS_SIGNAL
    }
    if bool(godot.class_db_class_has_integer_constant(cdb, class_sn, member_sn)) {
        return LOOKUP_RESULT_CLASS_CONSTANT
    }
    if class_has_property(cdb, class_sn, member) {
        return LOOKUP_RESULT_CLASS_PROPERTY
    }
    return LOOKUP_RESULT_CLASS
}

// Is `member` a property of the class? Scan the ClassDB property list, comparing each entry's
// "name". (There is no direct `class_has_property` bind.)
@(private = "file")
class_has_property :: proc(cdb: godot.Class_Db, class_sn: godot.String_Name, member: string) -> bool {
    list := godot.class_db_class_get_property_list(cdb, class_sn, false)
    parr := cast(^godot.Array)&list
    n := godot.array_size(parr)
    name_key := godot.new_string_cstring("name")
    name_kv := godot.variant_from_string(&name_key)
    for i in 0 ..< n {
        v := godot.array_get(parr, godot.Int(i))
        d := godot.variant_to_dictionary(&v)
        nv := godot.dictionary_get(&d, name_kv, godot.Variant{})
        ns := godot.variant_to_string(&nv)
        name := string_to_odin(ns, context.temp_allocator)
        if name == member {
            return true
        }
    }
    return false
}

// Dictionary-building helpers (complete.odin's `cd_set_*` are file-private, so we keep our own).
@(private = "file")
ld_set_int :: proc(d: ^godot.Dictionary, key: cstring, value: i64) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    iv := godot.Int(value)
    vv := godot.variant_from_int(&iv)
    godot.dictionary_set(d, kv, vv)
}

@(private = "file")
ld_set_str :: proc(d: ^godot.Dictionary, key: cstring, value: string) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    s := godot.new_string_odin(value)
    sv := godot.variant_from_string(&s)
    godot.dictionary_set(d, kv, sv)
}

// `_lookup_code(code, symbol, path, owner) -> Dictionary`. args[1] == symbol (the clicked token).
// ALWAYS returns a well-formed Dictionary carrying `result` + `type`; ANY miss/error returns the
// safe `{result: FAILED, type: 0}` shape (== `lv_dict_result_failed`). Never crashes.
lv_lookup_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()

    // Default to the graceful-miss shape; overwritten on a successful resolve.
    d := godot.new_dictionary_default()
    ld_set_int(&d, "result", FAILED)
    ld_set_int(&d, "type", LOOKUP_RESULT_SCRIPT_LOCATION)

    symbol := string_to_odin((cast(^godot.String)args[1])^)
    defer delete(symbol)

    sync.lock(&g_lookup_mutex)
    ensure_class_set()
    class_snake, member, is_class, ok := lookup.resolve_symbol(symbol, g_class_set)

    pascal := ""
    if ok {
        pascal, ok = pascal_for(class_snake)
    }
    sync.unlock(&g_lookup_mutex)

    if ok {
        if is_class {
            ld_set_int(&d, "result", OK)
            ld_set_int(&d, "type", LOOKUP_RESULT_CLASS)
            ld_set_str(&d, "class_name", pascal)
        } else {
            lr := classify_member(pascal, member)
            ld_set_int(&d, "result", OK)
            ld_set_int(&d, "type", lr)
            ld_set_str(&d, "class_name", pascal)
            // For a pure class fallback there is no member to anchor on.
            if lr != LOOKUP_RESULT_CLASS {
                ld_set_str(&d, "class_member", member)
            }
        }
    } else {
        // Not a gd.* class symbol — treat it as a user-code symbol and ask ols where it's
        // DEFINED, jumping there if it's a project (res://) script. Leaves `d` at the FAILED
        // default on any miss.
        try_definition(&d, args)
    }

    (cast(^godot.Dictionary)ret)^ = d
}

@(private = "file")
ld_set_variant :: proc(d: ^godot.Dictionary, key: cstring, value: godot.Variant) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    godot.dictionary_set(d, kv, value)
}

// Ask ols for the definition of the symbol at the caret (the U+FFFF marker in `code`=args[0])
// and, when it resolves to a res:// project script, populate `d` with a SCRIPT_LOCATION result
// the editor uses to jump there. Returns true on success; on any miss `d` keeps its FAILED
// default. Never crashes. Definitions outside the project (Odin stdlib, gd.* binding source) do
// not localize to res:// and are skipped — the editor can't open them as project scripts.
@(private = "file")
try_definition :: proc(d: ^godot.Dictionary, args: [^]gdext.TypePtr) -> bool {
    code := string_to_odin((cast(^godot.String)args[0])^)
    defer delete(code)

    global := godot.project_settings_globalize_path(
        godot.singleton_project_settings(),
        (cast(^godot.String)args[2])^,
    )
    abs_path := string_to_odin(global)
    defer delete(abs_path)
    if abs_path == "" {return false}

    ols_bin, found := resolve_bin("odin_godot/ols_bin", "OLS", "ols")
    if !found {return false}
    defer delete(ols_bin)
    root := godot_collection_root()
    defer delete(root)
    share := resolve_odin_share()
    defer delete(share)

    def, sok := complete.session_definition(&complete.g_session, code, abs_path, root, share, ols_bin)
    if !sok || !def.ok || def.path == "" {
        if def.ok {delete(def.path)}
        return false
    }
    defer delete(def.path)

    // Localize the absolute target back to res:// — the editor opens project resources.
    abs_g := godot.new_string_odin(def.path)
    res := godot.project_settings_localize_path(godot.singleton_project_settings(), abs_g)
    res_path := string_to_odin(res)
    defer delete(res_path)
    if !strings.has_prefix(res_path, "res://") {return false} // external (stdlib / binding) — not openable

    ld_set_int(d, "result", OK)
    ld_set_int(d, "type", LOOKUP_RESULT_SCRIPT_LOCATION)
    ld_set_str(d, "script_path", res_path)
    // LSP line is 0-based; Godot's script editor goto expects a 1-based line.
    ld_set_int(d, "location", i64(def.line + 1))

    // Pass the loaded Script so the editor opens the right FILE (not just a line in the current
    // one). Best-effort: if the load fails, script_path + location still let it try.
    res_g := godot.new_string_odin(res_path)
    empty := godot.new_string_cstring("")
    obj := godot.resource_loader_load(godot.singleton_resource_loader(), res_g, empty, .Cache_Mode_Reuse)
    if obj != nil {
        o := godot.Object(obj)
        sv := godot.variant_from_object(&o)
        ld_set_variant(d, "script", sv)
    }
    return true
}
