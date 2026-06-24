package godot

import __bindgen_gde "godot:gdext"

Tile_Set_Scenes_Collection_Source_Constants :: enum {
}



tile_set_scenes_collection_source_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_set_scenes_collection_source_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_set_scenes_collection_source :: proc "contextless" () -> Tile_Set_Scenes_Collection_Source {
    return cast(Tile_Set_Scenes_Collection_Source)__bindgen_gde.classdb_construct_object(tile_set_scenes_collection_source_name_ref())
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

tile_set_scenes_collection_source_get_scene_tiles_count :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scene_tiles_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_get_scene_tile_id :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scene_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_has_scene_tile_id :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_scene_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_create_scene_tile :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    packed_scene_: Packed_Scene,
    id_override_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_scene_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1117465415)
    }
    self := self
    packed_scene_ := packed_scene_
    id_override_ := id_override_
    args := []__bindgen_gde.TypePtr {
        &packed_scene_,
        &id_override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_set_scene_tile_id :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
    new_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scene_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    id_ := id_
    new_id_ := new_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &new_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_scenes_collection_source_set_scene_tile_scene :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
    packed_scene_: Packed_Scene,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scene_tile_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3435852839)
    }
    self := self
    id_ := id_
    packed_scene_ := packed_scene_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &packed_scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_scenes_collection_source_get_scene_tile_scene :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
) -> (ret: Packed_Scene) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scene_tile_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 511017218)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_set_scene_tile_display_placeholder :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
    display_placeholder_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scene_tile_display_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    id_ := id_
    display_placeholder_ := display_placeholder_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &display_placeholder_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_scenes_collection_source_get_scene_tile_display_placeholder :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scene_tile_display_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_scenes_collection_source_remove_scene_tile :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_scene_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_scenes_collection_source_get_next_scene_tile_id :: proc "contextless" (
    self: Tile_Set_Scenes_Collection_Source,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_scene_tile_id", true)
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
tile_set_scenes_collection_source_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileSetScenesCollectionSource", true)
}

@(private = "file")
__class_name: String_Name