package godot

import __bindgen_gde "godot:gdext"

Editor_Scene_Post_Import_Constants :: enum {
}



editor_scene_post_import_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_scene_post_import_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_scene_post_import :: proc "contextless" () -> Editor_Scene_Post_Import {
    return cast(Editor_Scene_Post_Import)__bindgen_gde.classdb_construct_object(editor_scene_post_import_name_ref())
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

editor_scene_post_import__post_import :: proc "contextless" (
    self: Editor_Scene_Post_Import,
    scene_: Node,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_post_import", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 134930648)
    }
    self := self
    scene_ := scene_
    args := []__bindgen_gde.TypePtr {
        &scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_post_import_get_source_file :: proc "contextless" (
    self: Editor_Scene_Post_Import,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_scene_post_import_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorScenePostImport", true)
}

@(private = "file")
__class_name: String_Name