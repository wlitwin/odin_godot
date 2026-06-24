package godot

import __bindgen_gde "godot:gdext"

Gpu_Particles_Attractor_Sphere3d_Constants :: enum {
}



gpu_particles_attractor_sphere3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gpu_particles_attractor_sphere3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gpu_particles_attractor_sphere3d :: proc "contextless" () -> Gpu_Particles_Attractor_Sphere3d {
    return __bindgen_gde.classdb_construct_object(gpu_particles_attractor_sphere3d_name_ref())
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

gpu_particles_attractor_sphere3d_set_radius :: proc "contextless" (
    self: Gpu_Particles_Attractor_Sphere3d,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles_attractor_sphere3d_get_radius :: proc "contextless" (
    self: Gpu_Particles_Attractor_Sphere3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
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
gpu_particles_attractor_sphere3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GPUParticlesAttractorSphere3D", true)
}

@(private = "file")
__class_name: String_Name