package godot

import __bindgen_gde "godot:gdext"

Bone_Map_Constants :: enum {
}



bone_map_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

bone_map_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_bone_map :: proc "contextless" () -> Bone_Map {
    return cast(Bone_Map)__bindgen_gde.classdb_construct_object(bone_map_name_ref())
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

bone_map_get_profile :: proc "contextless" (
    self: Bone_Map,
) -> (ret: Skeleton_Profile) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291782652)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_map_set_profile :: proc "contextless" (
    self: Bone_Map,
    profile_: Skeleton_Profile,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3870374136)
    }
    self := self
    profile_ := profile_
    args := []__bindgen_gde.TypePtr {
        &profile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_map_get_skeleton_bone_name :: proc "contextless" (
    self: Bone_Map,
    profile_bone_name_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965194235)
    }
    self := self
    profile_bone_name_ := profile_bone_name_
    args := []__bindgen_gde.TypePtr {
        &profile_bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_map_set_skeleton_bone_name :: proc "contextless" (
    self: Bone_Map,
    profile_bone_name_: String_Name,
    skeleton_bone_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skeleton_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    profile_bone_name_ := profile_bone_name_
    skeleton_bone_name_ := skeleton_bone_name_
    args := []__bindgen_gde.TypePtr {
        &profile_bone_name_,
        &skeleton_bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_map_find_profile_bone_name :: proc "contextless" (
    self: Bone_Map,
    skeleton_bone_name_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_profile_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965194235)
    }
    self := self
    skeleton_bone_name_ := skeleton_bone_name_
    args := []__bindgen_gde.TypePtr {
        &skeleton_bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
bone_map_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("BoneMap", true)
}

@(private = "file")
__class_name: String_Name