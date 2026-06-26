package core

import "godot:gdext"
import "godot:godot"

// ----------------------------------------------------------------------------
// OdinLanguage — the language singleton. Extends `ScriptLanguageExtension`.
//
// Registered as a GDExtension class, instantiated once, and handed to the engine
// via `Engine.register_script_language`. Phase 1 implements the identity / template
// / threading virtuals; everything else falls back to the engine's safe defaults
// (we return nil from get_virtual_call_data for unlisted virtuals).
// ----------------------------------------------------------------------------

@(private = "file")
odin_language_class_name: godot.String_Name

@(private = "file")
language_virtuals: [dynamic]Virtual_Entry

// The live language object pointer, shared so OdinScript._get_language can return it.
odin_language_object: gdext.ObjectPtr

OdinLanguage :: struct {
    object: gdext.ObjectPtr,
}

@(private = "file")
odin_language_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

@(private = "file")
language_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.script_language_extension_name_ref())
    self := new(OdinLanguage)
    self.object = object
    gdext.object_set_instance(object, &odin_language_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &odin_language_binding_callbacks)
    return object
}

@(private = "file")
language_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {
        return
    }
    free(cast(^OdinLanguage)instance)
}

@(private = "file")
language_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(language_virtuals[:], name)
}

// ---- virtuals ----

@(private = "file")
lv_get_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("Odin"))
}

@(private = "file")
lv_get_type :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("OdinScript"))
}

@(private = "file")
lv_get_extension :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("odin"))
}

@(private = "file")
lv_get_recognized_extensions :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("odin"))
}

@(private = "file")
lv_get_reserved_words :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(
        ret,
        make_psa(
            "package", "import", "proc", "struct", "enum", "union", "map", "bit_set",
            "if", "else", "for", "switch", "case", "in", "not_in", "return", "defer",
            "when", "where", "using", "cast", "transmute", "auto_cast", "distinct",
            "context", "or_else", "or_return", "break", "continue", "fallthrough",
            "nil", "true", "false", "dynamic", "matrix",
        ),
    )
}

@(private = "file")
lv_get_comment_delimiters :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("//", "/* */"))
}

@(private = "file")
lv_get_string_delimiters :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("\" \"", "` `"))
}

@(private = "file")
lv_noop :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
}

// `_reload_all_scripts` / `_reload_scripts` / `_reload_tool_script` — the editor's bulk/tool
// "reload" affordances. We treat them as a MANUAL trigger for the rebuild-on-save flow:
// kick a background scripts rebuild (editor-gated, coalesced — see reload.odin). This gives
// a reliable on-demand "recompile my Odin @exports" even if per-file save detection misses.
@(private = "file")
lv_reload_request :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    reload_request()
}

@(private = "file")
lv_create_script :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    object, _ := odin_script_construct()
    ret_object(ret, object)
}

@(private = "file")
lv_make_template :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    object, _ := odin_script_construct()
    ret_object(ret, object)
}

@(private = "file")
lv_false :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_bool(ret, false)
}

// ---- global class registration ------------------------------------------------------
//
// These two virtuals are how a `.odin` script's `//gd:class <Name>` becomes a first-class
// engine TYPE. The editor's filesystem scan, for each resource it finds, asks every
// ScriptLanguage `_handles_global_class_type(type)` where `type` is the resource's class
// ("OdinScript", what our loader's _get_resource_type returns); for the language that says
// yes it then calls `_get_global_class_name(path)` and reads back {name, base_type,
// icon_path}. A non-empty name registers `<Name>` in ScriptServer's global class list
// (persisted to project.godot `_global_script_classes`), making it usable as a type and a
// type-filter (e.g. a Resource/Node-typed @export picker).

// `_handles_global_class_type(type: String) -> bool`: we own the global-class metadata for
// our own script resource type ("OdinScript").
@(private = "file")
lv_handles_global_class_type :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    type := string_to_odin((cast(^godot.String)args[0])^)
    defer delete(type)
    ret_bool(ret, type == "OdinScript")
}

// `_get_global_class_name(path: String) -> Dictionary`: reparse the `.odin` file at `path`
// for its `//gd:class`/`//gd:extends` markers and return {name, base_type, icon_path}.
// When the file declares no class name we return an EMPTY Dictionary — the engine treats a
// missing "name" key as "no global class here" (ERR check on ret.has("name")).
@(private = "file")
lv_get_global_class_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    path := (cast(^godot.String)args[0])^
    text := godot.file_access_get_file_as_string(path)
    odin_text := string_to_odin(text)
    defer delete(odin_text)

    d := godot.new_dictionary_default()
    name := parse_class_name(odin_text)
    if name != "" {
        base := parse_base_type(odin_text)
        icon := parse_icon(odin_text)
        gc_dict_set_string(&d, "name", name)
        gc_dict_set_string(&d, "base_type", base)
        // `//gd:icon <res-path>` threads into the global class registry so the editor's
        // ProjectSettings.get_global_class_list() entry carries the icon (empty => default).
        gc_dict_set_string(&d, "icon_path", icon)
    }
    (cast(^godot.Dictionary)ret)^ = d
}

// String-keyed, String-valued Dictionary set for the global-class Dictionary (the engine
// reads these keys as Strings via `ret.get("name")` / `ret.get("base_type")`).
@(private = "file")
gc_dict_set_string :: proc(d: ^godot.Dictionary, key: cstring, value: string) {
    k := godot.new_string_cstring(key)
    kv := godot.variant_from_string(&k)
    v := godot.new_string_odin(value)
    vv := godot.variant_from_string(&v)
    godot.dictionary_set(d, kv, vv)
}

// ---- safe typed return stubs for the REQUIRED virtuals we don't meaningfully
// implement yet. Each MUST still return a well-formed value of the EXACT return
// type the engine expects (per extension_api.json) or the editor reads uninitialized
// return memory and crashes (this is what `_is_control_flow_keyword` etc. did before).

@(private = "file")
lv_int0 :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_int(ret, 0)
}

@(private = "file")
lv_intneg1 :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_int(ret, -1)
}

@(private = "file")
lv_string_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring(""))
}

@(private = "file")
lv_psa_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, godot.new_packed_string_array_default())
}

@(private = "file")
lv_array_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Array)ret)^ = godot.new_array_default()
}

@(private = "file")
lv_dict_empty :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Dictionary)ret)^ = godot.new_dictionary_default()
}

// `_lookup_code` / `_complete_code` return a Dictionary the engine REQUIRES to carry a
// "result" key (an Error int) — it does `ERR_FAIL_COND(!ret.has("result"))`, which spams the
// console on every click/keystroke if the key is absent. We don't implement symbol lookup /
// completion yet, so return `{ "result": FAILED }` (a well-formed "nothing here"). Real
// go-to-definition + completion are later DX work; until then this keeps the editor quiet.
@(private = "file")
lv_dict_result_failed :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    d := godot.new_dictionary_default()
    set_int := proc(d: ^godot.Dictionary, key: cstring, value: i64) {
        k := godot.new_string_cstring(key)
        kv := godot.variant_from_string(&k)
        iv := godot.Int(value)
        vv := godot.variant_from_int(&iv)
        godot.dictionary_set(d, kv, vv)
    }
    // `_lookup_code`'s consumer (ScriptLanguageExtension::lookup_code,
    // script_language_extension.h) does ERR_FAIL_COND_V on BOTH `result` AND `type` —
    // UNCONDITIONALLY, even on a failed lookup — so a `{result}`-only Dictionary spams
    // `Condition "!ret.has("type")" is true` on every editor symbol-lookup. Emit both:
    //   result -> FAILED (1)             (we have no lookup result)
    //   type   -> LOOKUP_RESULT_SCRIPT_LOCATION (0, the "none of the above" default)
    set_int(&d, "result", 1) // FAILED
    set_int(&d, "type", 0) // LOOKUP_RESULT_SCRIPT_LOCATION
    (cast(^godot.Dictionary)ret)^ = d
}

@(private = "file")
lv_ptr_null :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    (cast(^rawptr)ret)^ = nil
}

// `_is_control_flow_keyword(keyword: String) -> bool`: the editor calls this for each
// reserved word to give control-flow keywords a distinct highlight color. REQUIRED in
// 4.6 — without it the engine asserts "must be overridden" then reads uninitialized
// return memory. Return true for Odin's control-flow keywords, false otherwise.
@(private = "file")
lv_is_control_flow_keyword :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    kw := string_to_odin((cast(^godot.String)args[0])^)
    defer delete(kw)
    switch kw {
    case "if", "else", "for", "switch", "case", "when", "where", "break", "continue",
         "fallthrough", "return", "defer", "or_else", "or_return", "in", "not_in":
        ret_bool(ret, true)
    case:
        ret_bool(ret, false)
    }
}

// `_debug_get_current_stack_info`: report the Odin script call chain. The engine calls
// this when it gathers a script's stack (during error reporting / an active remote-debug
// session). Because Odin scripts are AOT native code, we capture the REAL native stack
// (`backtrace` + `dladdr`, see core/debug.odin) and return the frames that belong to the
// scripts dll, shaped as Godot expects: Array[ {function, line, source} ].
//
// `skip = 2` drops this trampoline + debug_capture_odin_stack itself so the chain starts
// at script code. When ODIN_DEBUG_STACK_DUMP=1 the captured frames are also echoed to
// stderr (the honest integration probe in tests/debug uses this to observe WHETHER Godot
// actually calls this virtual mid-run).
@(private = "file")
lv_debug_stack_info :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Array)ret)^ = debug_capture_odin_stack(2)
}

odin_language_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_language_class_name, "OdinLanguage", true)

    // Build the virtual table BEFORE registering the class, since the engine may
    // resolve the parent's virtuals during/right after registration.
    language_virtuals = make([dynamic]Virtual_Entry, 0, 64) // reserve: gdext allocator .Resize is broken (drops data)
    add := proc(name: string, fn: gdext.ExtensionClassCallVirtual) {
        append(&language_virtuals, Virtual_Entry{name = name, fn = fn})
    }
    add("_get_name", lv_get_name)
    add("_get_type", lv_get_type)
    add("_get_extension", lv_get_extension)
    add("_get_recognized_extensions", lv_get_recognized_extensions)
    add("_get_reserved_words", lv_get_reserved_words)
    add("_get_comment_delimiters", lv_get_comment_delimiters)
    add("_get_string_delimiters", lv_get_string_delimiters)
    add("_init", lv_noop)
    add("_finish", lv_finish_session) // kill the persistent ols session (see core/complete.odin)
    add("_thread_enter", lv_noop)
    add("_thread_exit", lv_noop)
    add("_frame", lv_frame) // deferred syntax-highlighter registration (see highlighter.odin)
    add("_create_script", lv_create_script)
    add("_make_template", lv_make_template)
    add("_supports_builtin_mode", lv_false)
    add("_can_inherit_from_file", lv_false)
    add("_is_using_templates", lv_false)
    add("_has_named_classes", lv_false)
    add("_overrides_external_editor", lv_false)
    add("_handles_global_class_type", lv_handles_global_class_type)
    add("_can_make_function", lv_false)
    add("_debug_get_current_stack_info", lv_debug_stack_info)

    // ---- remaining REQUIRED ScriptLanguageExtension virtuals (4.6.2). The editor
    // exercises far more of these than headless runtime; each returns a correctly-typed
    // safe default so the engine never asserts "must be overridden" then reads garbage.
    add("_is_control_flow_keyword", lv_is_control_flow_keyword) // bool
    add("_get_doc_comment_delimiters", lv_psa_empty) // PackedStringArray
    add("_get_built_in_templates", lv_array_empty) // typedarray::Dictionary
    add("_supports_documentation", lv_false) // bool
    add("_preferred_file_name_casing", lv_int0) // enum (int)
    add("_validate", lv_validate) // Dictionary {valid, errors} — real odin-check diagnostics (validate.odin)
    add("_validate_path", lv_string_empty) // String (empty == valid)
    add("_find_function", lv_intneg1) // int (-1 == not found)
    add("_make_function", lv_string_empty) // String
    add("_open_in_external_editor", lv_int0) // enum::Error (0 == OK)
    add("_complete_code", lv_complete_code) // Dictionary {result, force, call_hint, options} — real ols autocomplete (complete.odin)
    add("_lookup_code", lv_lookup_code) // Dictionary {result, type, class_name, class_member} — goto-def to built-in docs (lookup.odin)
    add("_auto_indent_code", lv_string_empty) // String
    add("_add_global_constant", lv_noop) // void
    add("_add_named_global_constant", lv_noop) // void
    add("_remove_named_global_constant", lv_noop) // void
    add("_debug_get_error", lv_string_empty) // String
    add("_debug_get_stack_level_count", lv_int0) // int
    add("_debug_get_stack_level_line", lv_int0) // int
    add("_debug_get_stack_level_function", lv_string_empty) // String
    add("_debug_get_stack_level_source", lv_string_empty) // String
    add("_debug_get_stack_level_locals", lv_dict_empty) // Dictionary
    add("_debug_get_stack_level_members", lv_dict_empty) // Dictionary
    add("_debug_get_stack_level_instance", lv_ptr_null) // void*
    add("_debug_get_globals", lv_dict_empty) // Dictionary
    add("_debug_parse_stack_level_expression", lv_string_empty) // String
    add("_reload_all_scripts", lv_reload_request) // void — manual rebuild-on-demand trigger
    add("_reload_scripts", lv_reload_request) // void — manual rebuild-on-demand trigger
    add("_reload_tool_script", lv_reload_request) // void — manual rebuild-on-demand trigger
    add("_get_public_functions", lv_array_empty) // typedarray::Dictionary
    add("_get_public_constants", lv_dict_empty) // Dictionary
    add("_get_public_annotations", lv_array_empty) // typedarray::Dictionary
    add("_profiling_start", lv_noop) // void
    add("_profiling_stop", lv_noop) // void
    add("_profiling_set_save_native_calls", lv_noop) // void
    add("_profiling_get_accumulated_data", lv_int0) // int
    add("_profiling_get_frame_data", lv_int0) // int
    add("_get_global_class_name", lv_get_global_class_name) // Dictionary {name, base_type, icon_path}

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = language_create_instance,
        free_instance_func          = language_free_instance,
        get_virtual_call_data_func  = language_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }

    gdext.classdb_register_extension_class2(
        gdext.library,
        &odin_language_class_name,
        godot.script_language_extension_name_ref(),
        &class_info,
    )

    // Instantiate the singleton and register it with the engine's ScriptServer.
    odin_language_object = gdext.classdb_construct_object(&odin_language_class_name)
    godot.engine_register_script_language(godot.singleton_engine(), odin_language_object)
}

odin_language_unregister :: proc() {
    if odin_language_object != nil {
        godot.engine_unregister_script_language(godot.singleton_engine(), odin_language_object)
    }
}
