package godot

import __bindgen_gde "godot:gdext"

Editor_Resource_Preview_Constants :: enum {
}



editor_resource_preview_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_resource_preview_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_resource_preview :: proc "contextless" () -> Editor_Resource_Preview {
    return cast(Editor_Resource_Preview)__bindgen_gde.classdb_construct_object(editor_resource_preview_name_ref())
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

editor_resource_preview_queue_resource_preview :: proc "contextless" (
    self: Editor_Resource_Preview,
    path_: String,
    receiver_: Object,
    receiver_func_: String_Name,
    userdata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue_resource_preview", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 233177534)
    }
    self := self
    path_ := path_
    receiver_ := receiver_
    receiver_func_ := receiver_func_
    userdata_ := userdata_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &receiver_,
        &receiver_func_,
        &userdata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_resource_preview_queue_edited_resource_preview :: proc "contextless" (
    self: Editor_Resource_Preview,
    resource_: Resource,
    receiver_: Object,
    receiver_func_: String_Name,
    userdata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue_edited_resource_preview", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1608376650)
    }
    self := self
    resource_ := resource_
    receiver_ := receiver_
    receiver_func_ := receiver_func_
    userdata_ := userdata_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &receiver_,
        &receiver_func_,
        &userdata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_resource_preview_add_preview_generator :: proc "contextless" (
    self: Editor_Resource_Preview,
    generator_: Editor_Resource_Preview_Generator,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_preview_generator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 332288124)
    }
    self := self
    generator_ := generator_
    args := []__bindgen_gde.TypePtr {
        &generator_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_resource_preview_remove_preview_generator :: proc "contextless" (
    self: Editor_Resource_Preview,
    generator_: Editor_Resource_Preview_Generator,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_preview_generator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 332288124)
    }
    self := self
    generator_ := generator_
    args := []__bindgen_gde.TypePtr {
        &generator_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_resource_preview_check_for_invalidation :: proc "contextless" (
    self: Editor_Resource_Preview,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("check_for_invalidation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_resource_preview_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorResourcePreview", true)
}

@(private = "file")
__class_name: String_Name