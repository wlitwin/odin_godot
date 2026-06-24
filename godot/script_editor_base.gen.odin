package godot

import __bindgen_gde "godot:gdext"

Script_Editor_Base_Constants :: enum {
}



script_editor_base_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

script_editor_base_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_script_editor_base :: proc "contextless" () -> Script_Editor_Base {
    return __bindgen_gde.classdb_construct_object(script_editor_base_name_ref())
}

// methods
//
// Method binds are resolved LAZILY on first call (the `@(static) __ptr` guard),
// NOT eagerly in `_init`. Many engine classes (Node, Control, the *Server
// singletons, ...) are only registered with ClassDB at later initialization
// levels (Servers/Scene), while `godot.init()` runs at the extension entry
// (Core level). Eagerly fetching every bind there returned null for ~91% of
// methods (a 16k-line `mb is null` flood). Resolving on first call defers the
// fetch to a point where the owning class is registered, mirroring how the
// builtin/variant methods already work. A genuinely unresolvable bind stays
// nil and the following ptrcall surfaces it at the call site.
//
// VARARG methods (`is_vararg` in extension_api.json) cannot use ptrcall — Godot
// aborts with "ptrcall can't be used with vararg methods". They instead go
// through `object_method_bind_call`: the fixed declared args are marshalled to
// Variants, the variadic `extra: ..Variant` are appended, and the returned
// Variant is converted to the declared return type (Variant passed through,
// `Error`/ints via variant_to_int, void ignored).

script_editor_base_get_base_editor :: proc "contextless" (
    self: Script_Editor_Base,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_base_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783021301)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_editor_base_add_syntax_highlighter :: proc "contextless" (
    self: Script_Editor_Base,
    highlighter_: Editor_Syntax_Highlighter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_syntax_highlighter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1092774468)
    }
    self := self
    highlighter_ := highlighter_
    args := []__bindgen_gde.TypePtr {
        &highlighter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
script_editor_base_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ScriptEditorBase", true)
}

@(private = "file")
__class_name: String_Name