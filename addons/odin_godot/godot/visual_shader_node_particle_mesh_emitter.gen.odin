package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Particle_Mesh_Emitter_Constants :: enum {
}



visual_shader_node_particle_mesh_emitter_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_particle_mesh_emitter_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_particle_mesh_emitter :: proc "contextless" () -> Visual_Shader_Node_Particle_Mesh_Emitter {
    return cast(Visual_Shader_Node_Particle_Mesh_Emitter)__bindgen_gde.classdb_construct_object(visual_shader_node_particle_mesh_emitter_name_ref())
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

visual_shader_node_particle_mesh_emitter_set_mesh :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
    mesh_: Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 194775623)
    }
    self := self
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_particle_mesh_emitter_get_mesh :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
) -> (ret: Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1808005922)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_particle_mesh_emitter_set_use_all_surfaces :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_all_surfaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_particle_mesh_emitter_is_use_all_surfaces :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_use_all_surfaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_particle_mesh_emitter_set_surface_index :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
    surface_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_surface_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    surface_index_ := surface_index_
    args := []__bindgen_gde.TypePtr {
        &surface_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_particle_mesh_emitter_get_surface_index :: proc "contextless" (
    self: Visual_Shader_Node_Particle_Mesh_Emitter,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
visual_shader_node_particle_mesh_emitter_get_use_all_surfaces :: proc "contextless" (self: Visual_Shader_Node_Particle_Mesh_Emitter) -> Bool {
    return visual_shader_node_particle_mesh_emitter_is_use_all_surfaces(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
visual_shader_node_particle_mesh_emitter_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeParticleMeshEmitter", true)
}

@(private = "file")
__class_name: String_Name