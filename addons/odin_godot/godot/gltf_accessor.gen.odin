package godot

import __bindgen_gde "godot:gdext"

Gltf_Accessor_Constants :: enum {
}
Gltf_Accessor_Gltf_Accessor_Type :: enum int {
    Type_Scalar = 0,
    Type_Vec2 = 1,
    Type_Vec3 = 2,
    Type_Vec4 = 3,
    Type_Mat2 = 4,
    Type_Mat3 = 5,
    Type_Mat4 = 6,
}
Gltf_Accessor_Gltf_Component_Type :: enum int {
    Component_Type_None = 0,
    Component_Type_Signed_Byte = 5120,
    Component_Type_Unsigned_Byte = 5121,
    Component_Type_Signed_Short = 5122,
    Component_Type_Unsigned_Short = 5123,
    Component_Type_Signed_Int = 5124,
    Component_Type_Unsigned_Int = 5125,
    Component_Type_Single_Float = 5126,
    Component_Type_Double_Float = 5130,
    Component_Type_Half_Float = 5131,
    Component_Type_Signed_Long = 5134,
    Component_Type_Unsigned_Long = 5135,
}



gltf_accessor_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gltf_accessor_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gltf_accessor :: proc "contextless" () -> Gltf_Accessor {
    return cast(Gltf_Accessor)__bindgen_gde.classdb_construct_object(gltf_accessor_name_ref())
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
gltf_accessor_from_dictionary :: proc "contextless" (
    dictionary_: Dictionary,
) -> (ret: Gltf_Accessor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_dictionary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3495091019)
    }
    dictionary_ := dictionary_
    args := []__bindgen_gde.TypePtr {
        &dictionary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


gltf_accessor_to_dictionary :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_dictionary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_get_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
    buffer_view_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    buffer_view_ := buffer_view_
    args := []__bindgen_gde.TypePtr {
        &buffer_view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
    byte_offset_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    byte_offset_ := byte_offset_
    args := []__bindgen_gde.TypePtr {
        &byte_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_component_type :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Gltf_Accessor_Gltf_Component_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_component_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852227802)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_component_type :: proc "contextless" (
    self: Gltf_Accessor,
    component_type_: Gltf_Accessor_Gltf_Component_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_component_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1780020221)
    }
    self := self
    component_type_ := component_type_
    args := []__bindgen_gde.TypePtr {
        &component_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_normalized :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_normalized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_normalized :: proc "contextless" (
    self: Gltf_Accessor,
    normalized_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_normalized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    normalized_ := normalized_
    args := []__bindgen_gde.TypePtr {
        &normalized_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_count :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_count :: proc "contextless" (
    self: Gltf_Accessor,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_accessor_type :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Gltf_Accessor_Gltf_Accessor_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_accessor_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1998183368)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_accessor_type :: proc "contextless" (
    self: Gltf_Accessor,
    accessor_type_: Gltf_Accessor_Gltf_Accessor_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_accessor_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2347728198)
    }
    self := self
    accessor_type_ := accessor_type_
    args := []__bindgen_gde.TypePtr {
        &accessor_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_type :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_type :: proc "contextless" (
    self: Gltf_Accessor,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_min :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Packed_Float64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 547233126)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_min :: proc "contextless" (
    self: Gltf_Accessor,
    min_: Packed_Float64_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2576592201)
    }
    self := self
    min_ := min_
    args := []__bindgen_gde.TypePtr {
        &min_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_max :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Packed_Float64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 547233126)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_max :: proc "contextless" (
    self: Gltf_Accessor,
    max_: Packed_Float64_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2576592201)
    }
    self := self
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_count :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_count :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    sparse_count_ := sparse_count_
    args := []__bindgen_gde.TypePtr {
        &sparse_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_indices_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_indices_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_indices_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_indices_buffer_view_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_indices_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    sparse_indices_buffer_view_ := sparse_indices_buffer_view_
    args := []__bindgen_gde.TypePtr {
        &sparse_indices_buffer_view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_indices_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_indices_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_indices_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_indices_byte_offset_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_indices_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    sparse_indices_byte_offset_ := sparse_indices_byte_offset_
    args := []__bindgen_gde.TypePtr {
        &sparse_indices_byte_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_indices_component_type :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: Gltf_Accessor_Gltf_Component_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_indices_component_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852227802)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_indices_component_type :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_indices_component_type_: Gltf_Accessor_Gltf_Component_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_indices_component_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1780020221)
    }
    self := self
    sparse_indices_component_type_ := sparse_indices_component_type_
    args := []__bindgen_gde.TypePtr {
        &sparse_indices_component_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_values_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_values_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_values_buffer_view :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_values_buffer_view_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_values_buffer_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    sparse_values_buffer_view_ := sparse_values_buffer_view_
    args := []__bindgen_gde.TypePtr {
        &sparse_values_buffer_view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_accessor_get_sparse_values_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sparse_values_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_accessor_set_sparse_values_byte_offset :: proc "contextless" (
    self: Gltf_Accessor,
    sparse_values_byte_offset_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sparse_values_byte_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    sparse_values_byte_offset_ := sparse_values_byte_offset_
    args := []__bindgen_gde.TypePtr {
        &sparse_values_byte_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gltf_accessor_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GLTFAccessor", true)
}

@(private = "file")
__class_name: String_Name