package godot

import __bindgen_gde "godot:gdext"

Tile_Set_Source_Constants :: enum {
}



tile_set_source_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_set_source_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_set_source :: proc "contextless" () -> Tile_Set_Source {
    return cast(Tile_Set_Source)__bindgen_gde.classdb_construct_object(tile_set_source_name_ref())
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

tile_set_source_get_tiles_count :: proc "contextless" (
    self: Tile_Set_Source,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tiles_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_source_get_tile_id :: proc "contextless" (
    self: Tile_Set_Source,
    index_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 880721226)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_source_has_tile :: proc "contextless" (
    self: Tile_Set_Source,
    atlas_coords_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3900751641)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_source_get_alternative_tiles_count :: proc "contextless" (
    self: Tile_Set_Source,
    atlas_coords_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alternative_tiles_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_source_get_alternative_tile_id :: proc "contextless" (
    self: Tile_Set_Source,
    atlas_coords_: Vector2i,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alternative_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 89881719)
    }
    self := self
    atlas_coords_ := atlas_coords_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_source_has_alternative_tile :: proc "contextless" (
    self: Tile_Set_Source,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_alternative_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1073731340)
    }
    self := self
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &alternative_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tile_set_source_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileSetSource", true)
}

@(private = "file")
__class_name: String_Name