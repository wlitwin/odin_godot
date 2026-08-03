package godot

import __bindgen_gde "godot:gdext"

Grid_Map_Editor_Plugin_Constants :: enum {
}



grid_map_editor_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

grid_map_editor_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_grid_map_editor_plugin :: proc "contextless" () -> Grid_Map_Editor_Plugin {
    return cast(Grid_Map_Editor_Plugin)__bindgen_gde.classdb_construct_object(grid_map_editor_plugin_name_ref())
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

grid_map_editor_plugin_get_current_grid_map :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) -> (ret: Grid_Map) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_grid_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1184264483)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_editor_plugin_set_selection :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
    begin_: Vector3i,
    end_: Vector3i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3659408297)
    }
    self := self
    begin_ := begin_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_editor_plugin_clear_selection :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_editor_plugin_get_selection :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_editor_plugin_has_selection :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_editor_plugin_get_selected_cells :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_cells", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

grid_map_editor_plugin_set_selected_palette_item :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
    item_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selected_palette_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 998575451)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

grid_map_editor_plugin_get_selected_palette_item :: proc "contextless" (
    self: Grid_Map_Editor_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_palette_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
grid_map_editor_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GridMapEditorPlugin", true)
}

@(private = "file")
__class_name: String_Name