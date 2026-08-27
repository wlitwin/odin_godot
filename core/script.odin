package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"
import "core:fmt"
import "core:strings"

// ----------------------------------------------------------------------------
// OdinScript — one resource per `.odin` file. Extends Godot's `ScriptExtension`.
//
// Phase 1 holds the source text plus a parsed base-type name and reports script
// identity to the engine. It does NOT execute anything: `_can_instantiate` is false,
// so the engine never asks for a running script instance (that is Phase 2).
// ----------------------------------------------------------------------------

@(private = "file")
odin_script_class_name: godot.String_Name

@(private = "file")
script_virtuals: [dynamic]Virtual_Entry

OdinScript :: struct {
    object:           gdext.ObjectPtr,
    source_utf8:      []u8, // owned copy of the `.odin` source
    base_type:        string, // owned copy of the parsed `extends` base ("" = no marker; edges read "" as "Node")
    class_name:       string, // owned copy of the parsed `//gd:class <Name>` (default "")
    icon:             string, // owned copy of the parsed `//gd:icon <res-path>` (default "")
    warned_ambiguous: bool, // one-shot: ambiguous base-type class resolution already warned
}

@(private = "file")
odin_script_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

// Parse the Phase-1 base-type convention: a marker comment `//gd:extends <Type>`.
// Returns "" when the marker is ABSENT — that is the stored convention (see the
// base_type field note); engine-facing reads default "" to "Node" at the edge.
// (Returning "Node" here made a marker-less HELPER file indistinguishable from a
// script that explicitly extends Node, which is what forced the one-Node-class
// rule on every package.) Package-visible: the global-class virtuals
// (language.odin `_get_global_class_name`) reparse a `.odin` file's markers
// straight from its path.
@(private)
parse_base_type :: proc(source: string) -> string {
    it := source
    for line in strings.split_lines_iterator(&it) {
        trimmed := strings.trim_space(line)
        if strings.has_prefix(trimmed, "//gd:extends") {
            rest := strings.trim_space(trimmed[len("//gd:extends"):])
            if len(rest) > 0 {
                return rest
            }
        }
    }
    return ""
}

// Parse the Phase-2 class-binding convention: a marker comment `//gd:class <Name>`.
// This is how a `.odin` file is matched to a Class_Desc registered by the scripts dll.
// Falls back to "" when absent (then base-type matching is attempted at instance time).
// Package-visible: the global-class virtuals (language.odin `_get_global_class_name`)
// reparse a `.odin` file's markers straight from its path.
@(private)
parse_class_name :: proc(source: string) -> string {
    it := source
    for line in strings.split_lines_iterator(&it) {
        trimmed := strings.trim_space(line)
        if strings.has_prefix(trimmed, "//gd:class") {
            rest := strings.trim_space(trimmed[len("//gd:class"):])
            if len(rest) > 0 {
                return rest
            }
        }
    }
    return ""
}

// Parse the custom-icon convention: a marker comment `//gd:icon <res-path>`. A non-empty
// path threads into BOTH the script's `_get_class_icon_path` virtual AND the global-class
// registry's `icon_path` (language.odin `_get_global_class_name`), so the editor shows the
// class with that icon. Falls back to "" when absent.
// Package-visible: the global-class virtuals reparse a `.odin` file's markers from its path.
@(private)
parse_icon :: proc(source: string) -> string {
    it := source
    for line in strings.split_lines_iterator(&it) {
        trimmed := strings.trim_space(line)
        if strings.has_prefix(trimmed, "//gd:icon") {
            rest := strings.trim_space(trimmed[len("//gd:icon"):])
            if len(rest) > 0 {
                return rest
            }
        }
    }
    return ""
}

// Store source + (re)parse the base type and class name. Caller must have an Odin context set.
//
// These three buffers are OWNED by the OdinScript for its lifetime and may be re-set
// (and are freed in script_free_instance). They must therefore be allocated AND freed
// through ONE stable allocator, independent of whichever ambient context allocator the
// engine callback happened to set. We use core_allocator: on native that is the Odin
// heap; on web it is the alignment-correct engine-backed allocator. Routing both the
// `make`/`clone` here and the `delete`s (here + in script_free_instance) through it is
// what keeps the web (single shared heap) free path valid.
odin_script_set_source :: proc(self: ^OdinScript, source: godot.String) {
    if self == nil {
        return
    }
    context.allocator = core_allocator()
    if self.source_utf8 != nil {
        delete(self.source_utf8)
    }
    if self.base_type != "" {
        delete(self.base_type)
    }
    if self.class_name != "" {
        delete(self.class_name)
    }
    if self.icon != "" {
        delete(self.icon)
    }
    text := string_to_odin(source)
    self.source_utf8 = transmute([]u8)text
    self.base_type = strings.clone(parse_base_type(text))
    self.class_name = strings.clone(parse_class_name(text))
    self.icon = strings.clone(parse_icon(text))
}

// Free the OwnED source/base/class buffers through the same allocator set_source used.
@(private = "file")
odin_script_free_strings :: proc(self: ^OdinScript) {
    a := core_allocator()
    if self.source_utf8 != nil {
        delete(self.source_utf8, a)
    }
    if self.base_type != "" {
        delete(self.base_type, a)
    }
    if self.class_name != "" {
        delete(self.class_name, a)
    }
    if self.icon != "" {
        delete(self.icon, a)
    }
}

// Resolve the Class_Desc this script binds to: by `//gd:class` name first, else by base-type
// match — but only when EXACTLY ONE registered class extends that base. With several
// candidates the old "first match" bound to whichever class the map iteration happened to
// yield (nondeterministic across runs), so instead we warn once (naming the candidates) and
// resolve nothing — the caller falls back to a harmless placeholder.
odin_script_resolve_desc :: proc(self: ^OdinScript) -> (rt.Class_Desc, bool) {
	script_access_enter()
	defer script_access_leave()
    if self == nil {
        return {}, false
    }
    if self.class_name != "" {
        if desc, ok := scripts_find_class(self.class_name); ok {
            return desc, true
        }
    }
    // NO markers at all = a package HELPER, not a script — it has no class to bind
    // and never did; the placeholder is its correct identity, silently. (This used
    // to fall through to the "Node" default below, which bound every helper file to
    // THE class extending plain Node — and a second Node class then sprayed one
    // ambiguity warning per helper per editor scan. Attachable scripts declare
    // `//gd:extends`; the repo attaches no marker-less file, and the docs agree.)
    if self.base_type == "" {
        return {}, false
    }
    base := self.base_type
    found: rt.Class_Desc
    count := 0
    for _, desc in scripts_classes {
        if string(desc.base) == base {
            if count == 0 {found = desc}
            count += 1
        }
    }
    if count == 1 {
        return found, true
    }
    if count > 1 && !self.warned_ambiguous {
        self.warned_ambiguous = true
        names := strings.builder_make(context.temp_allocator)
        for _, desc in scripts_classes {
            if string(desc.base) == base {
                if strings.builder_len(names) > 0 {strings.write_string(&names, ", ")}
                strings.write_string(&names, string(desc.name))
            }
        }
        gpath := godot.resource_get_path(cast(godot.Resource)self.object)
        path := string_to_odin(gpath, context.temp_allocator)
        msg := godot.new_string_odin(
            fmt.tprintf(
                "odin_godot: script %s has no //gd:class marker and multiple registered classes " +
                "extend %s (%s) — add `//gd:class <Name>` to pick one (using a placeholder for now).",
                path,
                base,
                strings.to_string(names),
            ),
        )
        godot.gd_push_warning(godot.variant_from_string(&msg))
    }
    return {}, false
}

// Construct an OdinScript object and return both the object and its Odin struct.
odin_script_construct :: proc() -> (gdext.ObjectPtr, ^OdinScript) {
    object := gdext.classdb_construct_object(&odin_script_class_name)
    self := cast(^OdinScript)gdext.object_get_instance_binding(
        object,
        gdext.library,
        &odin_script_binding_callbacks,
    )
    return object, self
}

// ---- instance lifecycle ----

@(private = "file")
script_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()

    object := gdext.classdb_construct_object(godot.script_extension_name_ref())

    self := new(OdinScript)
    // gdext's godot allocator zeroes on `.Alloc` (see gdext/context.odin), so `new`
    // already returned zeroed memory. The explicit clear is belt-and-braces: if the
    // allocator ever stopped zeroing, set_source's first delete would free a garbage
    // pointer in the owned source/base/class fields.
    self^ = {}
    self.object = object
    // base_type stays "" until source is set; "" is reported as "Node" on read.

    gdext.object_set_instance(object, &odin_script_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &odin_script_binding_callbacks)
    return object
}

@(private = "file")
script_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {
        return
    }
    self := cast(^OdinScript)instance
    odin_script_free_strings(self)
    free(self)
}

@(private = "file")
script_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(script_virtuals[:], name)
}

// ---- virtuals (real implementations) ----

@(private = "file")
v_get_language :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_object(ret, odin_language_object)
}

@(private = "file")
v_get_instance_base_type :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    base := self != nil && self.base_type != "" ? self.base_type : "Node"
    // Prefer the registered class's declared base when we can resolve it.
    if desc, ok := odin_script_resolve_desc(self); ok {
        base = string(desc.base)
    }
    ret_string_name(ret, godot.new_string_name_odin(base))
}

@(private = "file")
v_has_source_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    self := cast(^OdinScript)instance
    ret_bool(ret, self != nil && len(self.source_utf8) > 0)
}

@(private = "file")
v_get_source_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    self := cast(^OdinScript)instance
    text := self != nil ? string(self.source_utf8) : ""
    ret_string(ret, godot.new_string_odin(text))
}

@(private = "file")
v_set_source_code :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    self := cast(^OdinScript)instance
    source := (cast(^godot.String)args[0])^
    odin_script_set_source(self, source)
}

@(private = "file")
v_can_instantiate :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    // A non-tool script must NOT really instantiate in the EDITOR: returning true
    // there makes the engine build a REAL instance (running game code / introspection
    // in edit mode) instead of a placeholder, which is what crashes the Scene dock as
    // it walks the tree. Instantiable when the game runs, OR when the script is a tool.
    self := cast(^OdinScript)instance
    is_tool := false
    if desc, ok := odin_script_resolve_desc(self); ok {
        is_tool = desc.tool
    }
    editor_hint := bool(godot.engine_is_editor_hint(godot.singleton_engine()))
    ret_bool(ret, !editor_hint || is_tool)
}

@(private = "file")
v_is_tool :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    is_tool := false
    if desc, ok := odin_script_resolve_desc(self); ok {
        is_tool = desc.tool
    }
    ret_bool(ret, is_tool)
}

@(private = "file")
v_is_valid :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_bool(ret, true)
}

@(private = "file")
v_is_abstract :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_bool(ret, false)
}

// Engine "must be overridden" requirements that surface once a REAL instance exists.
@(private = "file")
v_false :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_bool(ret, false)
}

// Void no-op for editor-only hooks (e.g. `_update_exports`, called when the inspector
// rescans a script). The base ScriptExtension versions print a non-fatal "must be
// overridden" during editor/export scans; a no-op silences that without side effects.
@(private = "file")
v_noop :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
}

// Return a fresh empty Array for the script-introspection list virtuals
// (`_get_script_method_list` / `_get_script_property_list` / `_get_script_signal_list` /
// `_get_documentation`). Our per-instance surfaces (exports, methods, signals) are served
// through the script-INSTANCE vtable + `_has_method`/`_has_script_signal`; the script-level
// lists are an editor convenience, so an empty list is a sane, side-effect-free answer that
// silences the base-class "must be overridden" errors during editor/export scans.
@(private = "file")
v_empty_array :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    (cast(^godot.Array)ret)^ = godot.new_array()
}

// ----------------------------------------------------------------------------
// Script-introspection list virtuals — REAL metadata from the resolved Class_Desc.
//
// `_get_script_signal_list` / `_get_script_method_list` / `_get_script_property_list`
// each return a TypedArray<Dictionary>. The engine deserializes every entry through
// `MethodInfo::from_dict` / `PropertyInfo::from_dict`, so the Dictionaries must match
// those shapes EXACTLY (String keys; values per the field types below).
//
// These back `Object.get_signal_list()` / `get_method_list()` / `get_property_list()`
// and the editor's introspection. Returning real, well-formed data (instead of the
// previous empty-array stub, which made the engine read past an empty list while
// `_has_script_signal`/`_has_method` claimed the member existed) is the correct,
// non-UB behavior. (NB: the coin-collect crash itself was a separate script-lifetime
// use-after-free — see odin_make_script_instance in instance.odin.)
//
// A fresh Array is built each call (the engine takes ownership). When no Class_Desc
// resolves (editor placeholder / scripts dll not loaded) we return an empty Array — the
// pre-existing, safe, non-crashing path.
// ----------------------------------------------------------------------------

// METHOD_FLAG_NORMAL — the flag every plain (non-virtual/-static/-const) method+signal carries.
@(private = "file")
METHOD_FLAG_NORMAL :: 1

// String-keyed Dictionary set. MethodInfo/PropertyInfo dicts use String keys
// ("name"/"args"/"type"/...), matching the C++ `from_dict` string-literal lookups.
@(private = "file")
dict_set :: proc "contextless" (d: ^godot.Dictionary, key: cstring, value: godot.Variant) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    value := value
    godot.dictionary_set(d, kv, value)
}

@(private = "file")
v_sn :: proc "contextless" (s: cstring) -> godot.Variant {
    sn := godot.new_string_name_cstring(s, true)
    return godot.variant_from_string_name(&sn)
}

@(private = "file")
v_str :: proc "contextless" (s: cstring) -> godot.Variant {
    str := godot.new_string_cstring(s)
    return godot.variant_from_string(&str)
}

@(private = "file")
v_i64 :: proc "contextless" (n: i64) -> godot.Variant {
    i := godot.Int(n)
    return godot.variant_from_int(&i)
}

@(private = "file")
v_empty_arr :: proc "contextless" () -> godot.Variant {
    a := godot.new_array_default()
    return godot.variant_from_array(&a)
}

@(private = "file")
v_bool :: proc "contextless" (x: bool) -> godot.Variant {
    b := x
    return godot.variant_from_bool(&b)
}

// Build a Godot PropertyInfo-shaped Dictionary (used standalone for properties, and as
// each entry of a method/signal "args" array and a method "return").
@(private = "file")
make_property_info :: proc "contextless" (name: cstring, type: gdext.Variant_Type, hint: i64 = 0, hint_string: cstring = "") -> godot.Dictionary {
    d := godot.new_dictionary_default()
    dict_set(&d, "name", v_sn(name))
    dict_set(&d, "class_name", v_sn(""))
    dict_set(&d, "type", v_i64(i64(type)))
    dict_set(&d, "hint", v_i64(hint))
    dict_set(&d, "hint_string", v_str(hint_string))
    dict_set(&d, "usage", v_i64(PROPERTY_USAGE_DEFAULT))
    return d
}

// A typed default Variant for an export, so a freshly-placed node shows a sensible default
// in the Inspector before any scene value is applied. If the export declares an `@export
// default=...` (richer-authoring #3) we surface THAT; otherwise a typed zero. A zeroed
// Variant is NIL (valid for the `Other` cases — String/Object/Vector*); the scene's stored
// value overrides it via the placeholder's set-fallback regardless.
@(private = "file")
default_variant_for :: proc "contextless" (ex: rt.Export) -> godot.Variant {
    if ex.has_default {
        return export_default_variant(ex)
    }
    #partial switch ex.type {
    case .Int:
        i := godot.Int(0)
        return godot.variant_from_int(&i)
    case .Float:
        f := godot.Float(0)
        return godot.variant_from_float(&f)
    case .Bool:
        b := false
        return godot.variant_from_bool(&b)
    case:
        return godot.Variant{}
    }
}

// Build a GROUP/SUBGROUP marker Dictionary (richer-authoring #2) for the script-level /
// placeholder property lists. NIL type, the group label as `name`, empty `hint_string`
// prefix, and the GROUP or SUBGROUP usage flag.
@(private = "file")
make_group_info :: proc "contextless" (name: cstring, usage: i64) -> godot.Dictionary {
    d := godot.new_dictionary_default()
    dict_set(&d, "name", v_str(name))
    dict_set(&d, "class_name", v_sn(""))
    dict_set(&d, "type", v_i64(0)) // Variant type NIL
    dict_set(&d, "hint", v_i64(0))
    dict_set(&d, "hint_string", v_str(""))
    dict_set(&d, "usage", v_i64(usage))
    return d
}

// Push the GROUP/SUBGROUP markers an export declares into `arr` (a TypedArray<Dictionary>),
// before the export's own property entry. Shared by the placeholder + script property lists.
@(private = "file")
push_group_markers :: proc "contextless" (arr: ^godot.Array, ex: rt.Export) {
    if ex.group != nil {
        gi := make_group_info(ex.group, PROPERTY_USAGE_GROUP)
        gv := godot.variant_from_dictionary(&gi)
        godot.array_push_back(arr, gv)
    }
    if ex.subgroup != nil {
        si := make_group_info(ex.subgroup, PROPERTY_USAGE_SUBGROUP)
        sv := godot.variant_from_dictionary(&si)
        godot.array_push_back(arr, sv)
    }
}

// Push this script's `@export` vars into a PlaceHolderScriptInstance so they appear in the
// editor Inspector. In the editor a non-tool script is NOT really instantiated
// (`_can_instantiate` is false there) — the engine makes a placeholder, and its visible
// properties come ONLY from `placeholder_script_instance_update(props, values)`. Without
// this call the Inspector shows nothing even though `_get_script_property_list` is correct
// (that list backs `Script.get_script_property_list()`, a different path). Caller must have
// an Odin context set.
// ----------------------------------------------------------------------------
// Editor placeholder registry — for "show on save" (reload.odin).
//
// In the EDITOR a non-tool script is not really instantiated; the engine attaches a
// PlaceHolderScriptInstance whose visible Inspector properties come solely from the
// `placeholder_script_instance_update(props, values)` call (see update_placeholder_exports).
// Those props are a SNAPSHOT — after a scripts-dll swap they still describe the OLD exports.
// We track every live placeholder so that, after a rebuild+reload, we can re-push the NEW
// exports and notify the owner, making a freshly-added `@export` appear in the Inspector
// WITHOUT an editor restart.
@(private)
Placeholder_Entry :: struct {
    placeholder: gdext.ScriptInstancePtr,
    self:        ^OdinScript,
    owner:       gdext.ObjectPtr,
}

@(private)
live_placeholders: [dynamic]Placeholder_Entry

@(private)
track_placeholder :: proc(placeholder: gdext.ScriptInstancePtr, self: ^OdinScript, owner: gdext.ObjectPtr) {
    context.allocator = core_allocator()
    append(&live_placeholders, Placeholder_Entry{placeholder = placeholder, self = self, owner = owner})
}

@(private)
untrack_placeholder :: proc(placeholder: gdext.ScriptInstancePtr) {
    context.allocator = core_allocator()
    for e, i in live_placeholders {
        if e.placeholder == placeholder {
            unordered_remove(&live_placeholders, i)
            return
        }
    }
}

// Re-push each tracked placeholder's exports from its (now-reloaded) Class_Desc and notify
// the owner so the editor re-queries the property list. Main-thread only (gdext calls).
@(private)
refresh_placeholder_exports :: proc() {
    context.allocator = core_allocator()
    for e in live_placeholders {
        update_placeholder_exports(e.placeholder, e.self)
        if e.owner != nil {
            godot.object_notify_property_list_changed(cast(godot.Object)e.owner)
        }
    }
}

@(private = "file")
update_placeholder_exports :: proc(placeholder: gdext.ScriptInstancePtr, self: ^OdinScript) {
	script_access_enter()
	defer script_access_leave()
    desc, ok := odin_script_resolve_desc(self)
    if !ok {
        return
    }
    props := godot.new_array_default()
    values := godot.new_dictionary_default()
    for ex in rt.desc_exports(desc) {
        push_group_markers(&props, ex)
        pi := make_property_info(ex.name, ex.type, ex.hint, ex.hint_string == nil ? "" : ex.hint_string)
        pv := godot.variant_from_dictionary(&pi)
        godot.array_push_back(&props, pv)

        key := godot.new_string_name_cstring(ex.name, true)
        kv := godot.variant_from_string_name(&key)
        dv := default_variant_for(ex)
        godot.dictionary_set(&values, kv, dv)
    }
    gdext.placeholder_script_instance_update(placeholder, cast(gdext.TypePtr)&props, cast(gdext.TypePtr)&values)
}

@(private = "file")
v_get_script_signal_list :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    arr := godot.new_array_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        for sig in rt.desc_signals(desc) {
            d := godot.new_dictionary_default()
            dict_set(&d, "name", v_sn(sig.name))
            sig_args := godot.new_array_default()
            n := int(min(sig.arg_names_count, sig.arg_types_count))
            for i in 0 ..< n {
                pi := make_property_info(sig.arg_names[i], sig.arg_types[i])
                pv := godot.variant_from_dictionary(&pi)
                godot.array_push_back(&sig_args, pv)
            }
            av := godot.variant_from_array(&sig_args)
            dict_set(&d, "args", av)
            dict_set(&d, "flags", v_i64(METHOD_FLAG_NORMAL))
            dict_set(&d, "default_args", v_empty_arr())
            dv := godot.variant_from_dictionary(&d)
            godot.array_push_back(&arr, dv)
        }
    }
    (cast(^godot.Array)ret)^ = arr
}

// `_get_documentation` — REAL class + property docs from the script's `///` comments, so the
// class appears in the editor's Help (F1) and its `@export`s carry descriptions. Returns an
// Array with one ClassDoc Dictionary (Godot's DocData::ClassDoc::from_dict reads keys via
// has()-checks, so this confident subset is safe; unknown/absent keys just default).
@(private = "file")
v_get_documentation :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    arr := godot.new_array_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        cd := godot.new_dictionary_default()
        dict_set(&cd, "name", v_str(desc.name))
        if desc.base != nil {
            dict_set(&cd, "inherits", v_str(desc.base))
        }
        dict_set(&cd, "is_script_doc", v_bool(true))
        if desc.doc != nil {
            // brief = first line; description = the whole `///` block.
            doc_s := string(desc.doc)
            brief := doc_s
            if nl := strings.index_byte(doc_s, '\n'); nl >= 0 {
                brief = doc_s[:nl]
            }
            dict_set(&cd, "brief_description", v_str(strings.clone_to_cstring(brief, context.temp_allocator)))
            dict_set(&cd, "description", v_str(desc.doc))
        }
        props := godot.new_array_default()
        for ex in rt.desc_exports(desc) {
            pd := godot.new_dictionary_default()
            dict_set(&pd, "name", v_str(ex.name))
            if ex.doc != nil {
                dict_set(&pd, "description", v_str(ex.doc))
            }
            pdv := godot.variant_from_dictionary(&pd)
            godot.array_push_back(&props, pdv)
        }
        pav := godot.variant_from_array(&props)
        dict_set(&cd, "properties", pav)
        cdv := godot.variant_from_dictionary(&cd)
        godot.array_push_back(&arr, cdv)
    }
    (cast(^godot.Array)ret)^ = arr
}

// `_get_members` — the script's member variables (its exported fields) as StringNames, for the
// editor's member outline / member-name highlighting. Fresh Array each call (engine owns it).
@(private = "file")
v_get_members :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    arr := godot.new_array_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        for ex in rt.desc_exports(desc) {
            godot.array_push_back(&arr, v_sn(ex.name))
        }
    }
    (cast(^godot.Array)ret)^ = arr
}

// `_get_member_line` — 1-based source line of an exported member in the authored `.odin`, so the
// editor can jump to it. args[0] is the member's StringName; -1 when unknown.
@(private = "file")
v_get_member_line :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    name := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(name)
    line := i64(-1)
    if desc, ok := odin_script_resolve_desc(self); ok {
        for ex in rt.desc_exports(desc) {
            if string(ex.name) == name {
                if ex.line > 0 {
                    line = i64(ex.line)
                }
                break
            }
        }
    }
    ret_int(ret, line)
}

@(private = "file")
v_get_script_method_list :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    arr := godot.new_array_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        for m in rt.desc_methods(desc) {
            d := godot.new_dictionary_default()
            dict_set(&d, "name", v_sn(m.name))
            m_args := godot.new_array_default()
            for atype in rt.method_arg_types(m) {
                // Method descriptors carry no per-arg names; an empty name is valid.
                pi := make_property_info("", atype)
                pv := godot.variant_from_dictionary(&pi)
                godot.array_push_back(&m_args, pv)
            }
            av := godot.variant_from_array(&m_args)
            dict_set(&d, "args", av)
            rpi := make_property_info("", m.return_type)
            rv := godot.variant_from_dictionary(&rpi)
            dict_set(&d, "return", rv)
            dict_set(&d, "flags", v_i64(METHOD_FLAG_NORMAL))
            dict_set(&d, "default_args", v_empty_arr())
            dv := godot.variant_from_dictionary(&d)
            godot.array_push_back(&arr, dv)
        }
    }
    (cast(^godot.Array)ret)^ = arr
}

@(private = "file")
v_get_script_property_list :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    arr := godot.new_array_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        for ex in rt.desc_exports(desc) {
            push_group_markers(&arr, ex)
            pi := make_property_info(ex.name, ex.type, ex.hint, ex.hint_string == nil ? "" : ex.hint_string)
            pv := godot.variant_from_dictionary(&pi)
            godot.array_push_back(&arr, pv)
        }
    }
    (cast(^godot.Array)ret)^ = arr
}

// ----------------------------------------------------------------------------
// `_get_rpc_config` — REAL per-method RPC config from the resolved Class_Desc.
//
// `Script.get_rpc_config()` routes here; the engine's SceneRPCInterface reads it (once,
// cached per node) to learn which methods are RPCs + how to transfer them, then routes
// `node.rpc("method", ...)` and incoming remote calls to the method through the SAME
// `inst_call` path a normal call uses. The shape the engine deserializes
// (SceneRPCInterface::_parse_rpc_config) is a Dictionary:
//
//   { <method StringName> : { "rpc_mode": int, "transfer_mode": int,
//                             "call_local": bool, "channel": int }, ... }
//
// The OUTER keys MUST be StringName (the engine ERR_CONTINUEs on any non-StringName key);
// the INNER config keys are plain Strings (matching the C++ `subconfig.get("rpc_mode", ...)`
// literals). `rpc_mode` is a MultiplayerAPI.RPCMode int, `transfer_mode` a
// MultiplayerPeer.TransferMode int — both stored verbatim in rt.Rpc by codegen.
//
// A fresh Dictionary is built each call (the engine takes ownership). With no resolvable
// Class_Desc (editor placeholder / scripts dll not loaded) the result is an empty Dictionary
// (no RPCs) — the safe, pre-existing behavior of the old stub.
// ----------------------------------------------------------------------------
@(private = "file")
v_get_rpc_config :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    d := godot.new_dictionary_default()
    if desc, ok := odin_script_resolve_desc(self); ok {
        for r in rt.desc_rpcs(desc) {
            cfg := godot.new_dictionary_default()
            dict_set(&cfg, "rpc_mode", v_i64(r.mode))
            dict_set(&cfg, "transfer_mode", v_i64(r.transfer))
            dict_set(&cfg, "call_local", v_bool(r.call_local))
            dict_set(&cfg, "channel", v_i64(r.channel))

            // Outer key MUST be a StringName (engine requirement).
            key := godot.new_string_name_cstring(r.method, true)
            kv := godot.variant_from_string_name(&key)
            cfgv := godot.variant_from_dictionary(&cfg)
            godot.dictionary_set(&d, kv, cfgv)
        }
    }
    // `_get_rpc_config` returns a Variant (per extension_api.json); wrap the Dictionary.
    (cast(^godot.Variant)ret)^ = godot.variant_from_dictionary(&d)
}

// ---- safe typed return stubs for the remaining REQUIRED ScriptExtension virtuals.
// Each returns a well-formed value of the EXACT return type per extension_api.json.

@(private = "file")
v_true :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_bool(ret, true)
}

@(private = "file")
v_int_neg1 :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_int(ret, -1)
}

@(private = "file")
v_string_name_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string_name(ret, godot.new_string_name_cstring("", true))
}

@(private = "file")
v_dict_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Dictionary)ret)^ = godot.new_dictionary_default()
}

// Variant return slot is uninitialized; a zeroed Variant is type NIL — write that.
@(private = "file")
v_variant_nil :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    (cast(^godot.Variant)ret)^ = godot.Variant{}
}

@(private = "file")
v_string_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring(""))
}

@(private = "file")
v_get_base_script :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    // Odin scripts extend engine classes, not other scripts: no base script.
    ret_object(ret, nil)
}

// `Script.get_global_name()` routes here. Returning the script's `//gd:class <Name>`
// makes the engine treat that name as a GLOBAL CLASS: the editor's filesystem scan reads
// this (alongside OdinLanguage._get_global_class_name) to register `<Name>` as a usable
// type. Prefer the parsed `class_name`; fall back to the resolved Class_Desc name.
@(private = "file")
v_get_global_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    name := ""
    if self != nil && self.class_name != "" {
        name = self.class_name
    } else if desc, ok := odin_script_resolve_desc(self); ok {
        name = string(desc.name)
    }
    ret_string_name(ret, godot.new_string_name_odin(name))
}

// `_has_property_default_value` (richer-authoring #3): true iff the named @export declares
// an `@export default=...`. The editor uses this to enable the per-property reset arrow.
@(private = "file")
v_has_property_default_value :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    name := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(name)
    has := false
    if desc, ok := odin_script_resolve_desc(self); ok {
        for ex in rt.desc_exports(desc) {
            if string(ex.name) == name && ex.has_default {
                has = true
                break
            }
        }
    }
    ret_bool(ret, has)
}

// `_get_property_default_value` (richer-authoring #3): the declared default Variant for the
// named @export (NIL when none). Backs the Inspector's shown default + reset-to-default.
@(private = "file")
v_get_property_default_value :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    name := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(name)
    out := godot.Variant{}
    if desc, ok := odin_script_resolve_desc(self); ok {
        for ex in rt.desc_exports(desc) {
            if string(ex.name) == name && ex.has_default {
                out = export_default_variant(ex)
                break
            }
        }
    }
    (cast(^godot.Variant)ret)^ = out
}

@(private = "file")
g_default_icon: string
@(private = "file")
g_default_icon_done: bool

// resolved_default_icon — the icon for an Odin script that sets no `//gd:icon` of its own, so
// `.odin` scripts show an Odin mark in the editor (Scene/FileSystem docks, Create-Node dialog)
// instead of the generic script glyph. Project setting `odin_godot/default_icon` overrides the
// default (the bundled `res://addons/odin_godot/icon.svg`). EXISTENCE-CHECKED so the in-repo/dev
// layout (no installed addon -> the path is absent) cleanly returns "" (engine generic icon)
// rather than a broken reference. Resolved once per session (cached) — the editor calls the
// icon virtuals often.
@(private)
resolved_default_icon :: proc() -> string {
    if g_default_icon_done {
        return g_default_icon
    }
    g_default_icon_done = true
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/default_icon")
    path := "res://addons/odin_godot/icon.svg"
    if bool(godot.project_settings_has_setting(ps, key)) {
        v := godot.project_settings_get_setting(ps, key, godot.Variant{})
        s := godot.variant_to_string(&v)
        path = string_to_odin(s, context.temp_allocator)
    }
    if path != "" {
        gp := godot.new_string_odin(path)
        if bool(godot.file_access_file_exists(gp)) {
            g_default_icon = strings.clone(path, core_allocator())
            return g_default_icon
        }
    }
    g_default_icon = ""
    return g_default_icon
}

// `Script.get_class_icon_path()` routes here. Return the `//gd:icon <res-path>` marker so
// the editor (Scene dock, Create Node/Resource dialogs) shows the class with that icon.
// Prefer the script's own parsed `icon`; fall back to the resolved Class_Desc's `icon`
// (set by codegen from the same marker), then the bundled default Odin icon. Empty => engine
// generic icon.
@(private = "file")
v_get_class_icon_path :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    icon := ""
    if self != nil && self.icon != "" {
        icon = self.icon
    } else if desc, ok := odin_script_resolve_desc(self); ok && desc.icon != nil {
        icon = string(desc.icon)
    }
    if icon == "" {
        icon = resolved_default_icon()
    }
    ret_string(ret, godot.new_string_odin(icon))
}

@(private = "file")
v_has_method :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    method := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(method)
    has := false
    if desc, ok := odin_script_resolve_desc(self); ok {
        switch method {
        case "_process":
            has = desc.lifecycle.process != nil
        case "_physics_process":
            has = desc.lifecycle.physics_process != nil
        case "_ready":
            has = desc.lifecycle.ready != nil
        case:
            for m in rt.desc_methods(desc) {
                if string(m.name) == method {
                    has = true
                    break
                }
            }
        }
    }
    ret_bool(ret, has)
}

// `_has_script_signal` is what makes `obj.connect("sig", ...)` legal for a
// script-declared signal: Object::connect consults the attached Script via this
// virtual before creating the connection (and emit's debug check uses it too).
@(private = "file")
v_has_script_signal :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    signal := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(signal)
    has := false
    if desc, ok := odin_script_resolve_desc(self); ok {
        for s in rt.desc_signals(desc) {
            if string(s.name) == signal {
                has = true
                break
            }
        }
    }
    ret_bool(ret, has)
}

@(private = "file")
v_reload :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    // `Script.reload(keep_state)` routes here. The editor also calls it when a `.odin` is
    // SAVED. Two modes:
    //   * EDITOR: an `@export` change lives in the COMPILED scripts dll, so saving is not
    //     enough — the dll must be REBUILT first. Kick a non-blocking background build
    //     (reload.odin); when it finishes, the next `_frame` swaps the dll + refreshes the
    //     Inspector. We return OK immediately (the swap is deferred, not synchronous here).
    //   * RUNNING GAME: the on-disk dll was already rebuilt out-of-band (e.g. the Phase-4
    //     hot-reload test); swap it synchronously and re-bind live instances in place.
    context = gdext.godot_context()
    if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
        reload_request()
        ret_int(ret, 0) // 0 == OK; the rebuild+swap happens asynchronously
        return
    }
    // Multi-module: swap ONLY the module this script belongs to (res://modules/<name>/...
    // -> "<name>", anything else -> "" == the MAIN module). A single-module project always
    // resolves to "" — the pre-spike behavior.
    self := cast(^OdinScript)instance
    module := ""
    if self != nil && self.object != nil {
        gpath := godot.resource_get_path(cast(godot.Resource)self.object)
        path := string_to_odin(gpath, context.temp_allocator)
        module = scripts_module_for_res_path(path)
    }
    ok := odin_scripts_reload(module)
    ret_int(ret, ok ? 0 : 1) // 0 == OK, 1 == FAILED
}

// `_placeholder_erased(placeholder)` — the engine drops a placeholder script instance
// (node freed / script detached). Stop tracking it so the reload-on-save refresh never
// touches a freed placeholder.
@(private = "file")
v_placeholder_erased :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    // args[0] is a pointer to the placeholder pointer (ptrcall convention), like the `owner`
    // arg in v_instance_create — dereference to get the placeholder instance pointer itself.
    placeholder := (cast(^gdext.ScriptInstancePtr)args[0])^
    untrack_placeholder(placeholder)
}

@(private = "file")
v_instance_create :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    owner := (cast(^gdext.ObjectPtr)args[0])^
    // Phase 2: build a REAL script instance bound to the registered Class_Desc, so the
    // engine dispatches _ready (notification) and _process/_physics_process (call) into
    // the compiled Odin procs. If no class is registered for this script, fall back to a
    // harmless placeholder so the engine still keeps the script attached.
    if desc, ok := odin_script_resolve_desc(self); ok {
        inst := odin_make_script_instance(self.object, owner, desc)
        (cast(^gdext.ScriptInstancePtr)ret)^ = inst
        return
    }
    inst := gdext.placeholder_script_instance_create(odin_language_object, self.object, owner)
    update_placeholder_exports(inst, self)
    track_placeholder(inst, self, owner) // for reload-on-save Inspector refresh (reload.odin)
    (cast(^gdext.ScriptInstancePtr)ret)^ = inst
}

@(private = "file")
v_placeholder_instance_create :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
	script_access_enter()
	defer script_access_leave()
    self := cast(^OdinScript)instance
    owner := (cast(^gdext.ObjectPtr)args[0])^
    inst := gdext.placeholder_script_instance_create(odin_language_object, self.object, owner)
    update_placeholder_exports(inst, self)
    track_placeholder(inst, self, owner) // for reload-on-save Inspector refresh (reload.odin)
    (cast(^gdext.ScriptInstancePtr)ret)^ = inst
}

odin_script_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_script_class_name, "OdinScript", true)

    script_virtuals = make([dynamic]Virtual_Entry, 0, 64) // reserve: gdext allocator .Resize is broken (drops data)
    add := proc(name: string, fn: gdext.ExtensionClassCallVirtual) {
        append(&script_virtuals, Virtual_Entry{name = name, fn = fn})
    }
    add("_get_language", v_get_language)
    add("_get_instance_base_type", v_get_instance_base_type)
    add("_has_source_code", v_has_source_code)
    add("_get_source_code", v_get_source_code)
    add("_set_source_code", v_set_source_code)
    add("_can_instantiate", v_can_instantiate)
    add("_is_tool", v_is_tool)
    add("_is_valid", v_is_valid)
    add("_is_abstract", v_is_abstract)
    add("_has_method", v_has_method)
    add("_has_script_signal", v_has_script_signal)
    add("_reload", v_reload)
    add("_instance_create", v_instance_create)
    add("_placeholder_instance_create", v_placeholder_instance_create)
    add("_is_placeholder_fallback_enabled", v_false)
    add("_get_base_script", v_get_base_script)
    add("_inherits_script", v_false)
    add("_has_property_default_value", v_has_property_default_value)
    add("_get_global_name", v_get_global_name)
    add("_instance_has", v_false)
    // Editor/export scan noise reducers: return sane empties instead of the base-class
    // "must be overridden" non-fatal errors (Phase 6 polish).
    add("_update_exports", v_noop)
    // Real script-introspection lists (built from the resolved Class_Desc) instead of the
    // empty-array stub — see the block comment on v_get_script_signal_list above.
    add("_get_script_method_list", v_get_script_method_list)
    add("_get_script_property_list", v_get_script_property_list)
    add("_get_script_signal_list", v_get_script_signal_list)
    add("_get_documentation", v_get_documentation) // Array[ClassDoc] from `///` comments
    // Remaining REQUIRED ScriptExtension virtuals (4.6.2) the editor exercises.
    add("_editor_can_reload_from_file", v_true) // bool
    add("_has_static_method", v_false) // bool
    add("_get_doc_class_name", v_string_name_empty) // StringName
    add("_get_method_info", v_dict_empty) // Dictionary
    add("_get_property_default_value", v_get_property_default_value) // Variant
    add("_get_member_line", v_get_member_line) // int line of an exported member (-1 == unknown)
    add("_get_constants", v_dict_empty) // Dictionary
    add("_get_members", v_get_members) // typedarray::StringName — exported member vars
    add("_get_rpc_config", v_get_rpc_config) // Variant — real per-method @(gd_rpc) config
    add("_get_script_method_argument_count", v_variant_nil) // Variant
    add("_get_class_icon_path", v_get_class_icon_path) // String — `//gd:icon` marker path
    add("_placeholder_erased", v_placeholder_erased) // void — untrack for reload-on-save refresh

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = script_create_instance,
        free_instance_func          = script_free_instance,
        get_virtual_call_data_func  = script_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }

    register_extension_class(&odin_script_class_name, godot.script_extension_name_ref(), &class_info)
}
