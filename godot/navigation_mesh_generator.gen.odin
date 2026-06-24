package godot

import __bindgen_gde "godot:gdext"

Navigation_Mesh_Generator_Constants :: enum {
}



navigation_mesh_generator_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_mesh_generator_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_mesh_generator :: proc "contextless" () -> Navigation_Mesh_Generator {
    return __bindgen_gde.classdb_construct_object(navigation_mesh_generator_name_ref())
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

navigation_mesh_generator_bake :: proc "contextless" (
    self: Navigation_Mesh_Generator,
    navigation_mesh_: Navigation_Mesh,
    root_node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bake", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1401173477)
    }
    self := self
    navigation_mesh_ := navigation_mesh_
    root_node_ := root_node_
    args := []__bindgen_gde.TypePtr {
        &navigation_mesh_,
        &root_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_generator_clear :: proc "contextless" (
    self: Navigation_Mesh_Generator,
    navigation_mesh_: Navigation_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2923361153)
    }
    self := self
    navigation_mesh_ := navigation_mesh_
    args := []__bindgen_gde.TypePtr {
        &navigation_mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_generator_parse_source_geometry_data :: proc "contextless" (
    self: Navigation_Mesh_Generator,
    navigation_mesh_: Navigation_Mesh,
    source_geometry_data_: Navigation_Mesh_Source_Geometry_Data3d,
    root_node_: Node,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("parse_source_geometry_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3172802542)
    }
    self := self
    navigation_mesh_ := navigation_mesh_
    source_geometry_data_ := source_geometry_data_
    root_node_ := root_node_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &navigation_mesh_,
        &source_geometry_data_,
        &root_node_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_generator_bake_from_source_geometry_data :: proc "contextless" (
    self: Navigation_Mesh_Generator,
    navigation_mesh_: Navigation_Mesh,
    source_geometry_data_: Navigation_Mesh_Source_Geometry_Data3d,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bake_from_source_geometry_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286748856)
    }
    self := self
    navigation_mesh_ := navigation_mesh_
    source_geometry_data_ := source_geometry_data_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &navigation_mesh_,
        &source_geometry_data_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
navigation_mesh_generator_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationMeshGenerator", true)
}

@(private = "file")
__class_name: String_Name