package godot

import __bindgen_gde "godot:gdext"

Rd_Pipeline_Color_Blend_State_Attachment_Constants :: enum {
}



rd_pipeline_color_blend_state_attachment_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rd_pipeline_color_blend_state_attachment_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rd_pipeline_color_blend_state_attachment :: proc "contextless" () -> Rd_Pipeline_Color_Blend_State_Attachment {
    return cast(Rd_Pipeline_Color_Blend_State_Attachment)__bindgen_gde.classdb_construct_object(rd_pipeline_color_blend_state_attachment_name_ref())
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

rd_pipeline_color_blend_state_attachment_set_as_mix :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_mix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_set_enable_blend :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_enable_blend :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_enable_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_src_color_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Factor,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_src_color_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2251019273)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_src_color_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Factor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_src_color_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3691288359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_dst_color_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Factor,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dst_color_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2251019273)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_dst_color_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Factor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dst_color_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3691288359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_color_blend_op :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Operation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_blend_op", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3073022720)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_color_blend_op :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Operation) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_blend_op", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1385093561)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_src_alpha_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Factor,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_src_alpha_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2251019273)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_src_alpha_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Factor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_src_alpha_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3691288359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_dst_alpha_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Factor,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dst_alpha_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2251019273)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_dst_alpha_blend_factor :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Factor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dst_alpha_blend_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3691288359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_alpha_blend_op :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Rendering_Device_Blend_Operation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_blend_op", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3073022720)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_alpha_blend_op :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Rendering_Device_Blend_Operation) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_blend_op", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1385093561)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_write_r :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_write_r", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_write_r :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_write_r", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_write_g :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_write_g", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_write_g :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_write_g", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_write_b :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_write_b", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_write_b :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_write_b", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_color_blend_state_attachment_set_write_a :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
    p_member_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_write_a", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_color_blend_state_attachment_get_write_a :: proc "contextless" (
    self: Rd_Pipeline_Color_Blend_State_Attachment,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_write_a", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
rd_pipeline_color_blend_state_attachment_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RDPipelineColorBlendStateAttachment", true)
}

@(private = "file")
__class_name: String_Name