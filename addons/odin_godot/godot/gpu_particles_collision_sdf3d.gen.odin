package godot

import __bindgen_gde "godot:gdext"

Gpu_Particles_Collision_Sdf3d_Constants :: enum {
}
Gpu_Particles_Collision_Sdf3d_Resolution :: enum int {
    Resolution_16 = 0,
    Resolution_32 = 1,
    Resolution_64 = 2,
    Resolution_128 = 3,
    Resolution_256 = 4,
    Resolution_512 = 5,
    Resolution_Max = 6,
}



gpu_particles_collision_sdf3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gpu_particles_collision_sdf3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gpu_particles_collision_sdf3d :: proc "contextless" () -> Gpu_Particles_Collision_Sdf3d {
    return __bindgen_gde.classdb_construct_object(gpu_particles_collision_sdf3d_name_ref())
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

gpu_particles_collision_sdf3d_set_size :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    size_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_size :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles_collision_sdf3d_set_resolution :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    resolution_: Gpu_Particles_Collision_Sdf3d_Resolution,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_resolution", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1155629297)
    }
    self := self
    resolution_ := resolution_
    args := []__bindgen_gde.TypePtr {
        &resolution_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_resolution :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
) -> (ret: Gpu_Particles_Collision_Sdf3d_Resolution) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resolution", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2919555867)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles_collision_sdf3d_set_texture :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    texture_: Texture3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1188404210)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_texture :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
) -> (ret: Texture3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373985333)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles_collision_sdf3d_set_thickness :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    thickness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    thickness_ := thickness_
    args := []__bindgen_gde.TypePtr {
        &thickness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_thickness :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles_collision_sdf3d_set_bake_mask :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_bake_mask :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles_collision_sdf3d_set_bake_mask_value :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_number_ := layer_number_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_collision_sdf3d_get_bake_mask_value :: proc "contextless" (
    self: Gpu_Particles_Collision_Sdf3d,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_number_ := layer_number_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gpu_particles_collision_sdf3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GPUParticlesCollisionSDF3D", true)
}

@(private = "file")
__class_name: String_Name