package godot

import __bindgen_gde "godot:gdext"

Editor_Inspector_Plugin_Constants :: enum {
}



editor_inspector_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_inspector_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_inspector_plugin :: proc "contextless" () -> Editor_Inspector_Plugin {
    return cast(Editor_Inspector_Plugin)__bindgen_gde.classdb_construct_object(editor_inspector_plugin_name_ref())
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

editor_inspector_plugin__can_handle :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 397768994)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_inspector_plugin__parse_begin :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_parse_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin__parse_category :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
    category_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_parse_category", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 357144787)
    }
    self := self
    object_ := object_
    category_ := category_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &category_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin__parse_group :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
    group_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_parse_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 357144787)
    }
    self := self
    object_ := object_
    group_ := group_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &group_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin__parse_property :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
    type_: __bindgen_gde.Variant_Type,
    name_: String,
    hint_type_: Property_Hint,
    hint_string_: String,
    usage_flags_: Property_Usage_Flags,
    wide_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_parse_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1087679910)
    }
    self := self
    object_ := object_
    type_ := type_
    name_ := name_
    hint_type_ := hint_type_
    hint_string_ := hint_string_
    usage_flags_ := usage_flags_
    wide_ := wide_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &type_,
        &name_,
        &hint_type_,
        &hint_string_,
        &usage_flags_,
        &wide_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_inspector_plugin__parse_end :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_parse_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin_add_custom_control :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_custom_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin_add_property_editor :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    property_: String,
    editor_: Control,
    add_to_end_: Bool,
    label_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_property_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2042698479)
    }
    self := self
    property_ := property_
    editor_ := editor_
    add_to_end_ := add_to_end_
    label_ := label_
    args := []__bindgen_gde.TypePtr {
        &property_,
        &editor_,
        &add_to_end_,
        &label_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_inspector_plugin_add_property_editor_for_multiple_properties :: proc "contextless" (
    self: Editor_Inspector_Plugin,
    label_: String,
    properties_: Packed_String_Array,
    editor_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_property_editor_for_multiple_properties", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 788598683)
    }
    self := self
    label_ := label_
    properties_ := properties_
    editor_ := editor_
    args := []__bindgen_gde.TypePtr {
        &label_,
        &properties_,
        &editor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_inspector_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorInspectorPlugin", true)
}

@(private = "file")
__class_name: String_Name