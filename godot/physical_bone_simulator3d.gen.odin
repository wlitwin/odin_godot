package godot

import __bindgen_gde "godot:gdext"

Physical_Bone_Simulator3d_Constants :: enum {
}



physical_bone_simulator3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physical_bone_simulator3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physical_bone_simulator3d :: proc "contextless" () -> Physical_Bone_Simulator3d {
    return cast(Physical_Bone_Simulator3d)__bindgen_gde.classdb_construct_object(physical_bone_simulator3d_name_ref())
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

physical_bone_simulator3d_is_simulating_physics :: proc "contextless" (
    self: Physical_Bone_Simulator3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_simulating_physics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone_simulator3d_physical_bones_stop_simulation :: proc "contextless" (
    self: Physical_Bone_Simulator3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("physical_bones_stop_simulation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone_simulator3d_physical_bones_start_simulation :: proc "contextless" (
    self: Physical_Bone_Simulator3d,
    bones_: Typed_Array(String_Name),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("physical_bones_start_simulation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2787316981)
    }
    self := self
    bones_ := bones_
    args := []__bindgen_gde.TypePtr {
        &bones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone_simulator3d_physical_bones_add_collision_exception :: proc "contextless" (
    self: Physical_Bone_Simulator3d,
    exception_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("physical_bones_add_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    exception_ := exception_
    args := []__bindgen_gde.TypePtr {
        &exception_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone_simulator3d_physical_bones_remove_collision_exception :: proc "contextless" (
    self: Physical_Bone_Simulator3d,
    exception_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("physical_bones_remove_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    exception_ := exception_
    args := []__bindgen_gde.TypePtr {
        &exception_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physical_bone_simulator3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicalBoneSimulator3D", true)
}

@(private = "file")
__class_name: String_Name