package godot

import __bindgen_gde "godot:gdext"

Gltf_Object_Model_Property_Constants :: enum {
}
Gltf_Object_Model_Property_Gltf_Object_Model_Type :: enum int {
    Gltf_Object_Model_Type_Unknown = 0,
    Gltf_Object_Model_Type_Bool = 1,
    Gltf_Object_Model_Type_Float = 2,
    Gltf_Object_Model_Type_Float_Array = 3,
    Gltf_Object_Model_Type_Float2 = 4,
    Gltf_Object_Model_Type_Float3 = 5,
    Gltf_Object_Model_Type_Float4 = 6,
    Gltf_Object_Model_Type_Float2x2 = 7,
    Gltf_Object_Model_Type_Float3x3 = 8,
    Gltf_Object_Model_Type_Float4x4 = 9,
    Gltf_Object_Model_Type_Int = 10,
}



gltf_object_model_property_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gltf_object_model_property_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gltf_object_model_property :: proc "contextless" () -> Gltf_Object_Model_Property {
    return cast(Gltf_Object_Model_Property)__bindgen_gde.classdb_construct_object(gltf_object_model_property_name_ref())
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

gltf_object_model_property_append_node_path :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    node_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_node_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    node_path_ := node_path_
    args := []__bindgen_gde.TypePtr {
        &node_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_append_path_to_property :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    node_path_: Node_Path,
    prop_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_path_to_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1331931644)
    }
    self := self
    node_path_ := node_path_
    prop_name_ := prop_name_
    args := []__bindgen_gde.TypePtr {
        &node_path_,
        &prop_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_accessor_type :: proc "contextless" (
    self: Gltf_Object_Model_Property,
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

gltf_object_model_property_get_gltf_to_godot_expression :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Expression) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gltf_to_godot_expression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240072449)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_gltf_to_godot_expression :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    gltf_to_godot_expr_: Expression,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gltf_to_godot_expression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1815845073)
    }
    self := self
    gltf_to_godot_expr_ := gltf_to_godot_expr_
    args := []__bindgen_gde.TypePtr {
        &gltf_to_godot_expr_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_godot_to_gltf_expression :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Expression) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_godot_to_gltf_expression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240072449)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_godot_to_gltf_expression :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    godot_to_gltf_expr_: Expression,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_godot_to_gltf_expression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1815845073)
    }
    self := self
    godot_to_gltf_expr_ := godot_to_gltf_expr_
    args := []__bindgen_gde.TypePtr {
        &godot_to_gltf_expr_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_node_paths :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Typed_Array(Node_Path)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_has_node_paths :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_node_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_node_paths :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    node_paths_: Typed_Array(Node_Path),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_node_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    node_paths_ := node_paths_
    args := []__bindgen_gde.TypePtr {
        &node_paths_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_object_model_type :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Gltf_Object_Model_Property_Gltf_Object_Model_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object_model_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1094778507)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_object_model_type :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    type_: Gltf_Object_Model_Property_Gltf_Object_Model_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_object_model_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108684086)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_json_pointers :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Typed_Array(Packed_String_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_json_pointers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_has_json_pointers :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_json_pointers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_json_pointers :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    json_pointers_: Typed_Array(Packed_String_Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_json_pointers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    json_pointers_ := json_pointers_
    args := []__bindgen_gde.TypePtr {
        &json_pointers_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_get_variant_type :: proc "contextless" (
    self: Gltf_Object_Model_Property,
) -> (ret: __bindgen_gde.Variant_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_variant_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3416842102)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_object_model_property_set_variant_type :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    variant_type_: __bindgen_gde.Variant_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_variant_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2887708385)
    }
    self := self
    variant_type_ := variant_type_
    args := []__bindgen_gde.TypePtr {
        &variant_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_object_model_property_set_types :: proc "contextless" (
    self: Gltf_Object_Model_Property,
    variant_type_: __bindgen_gde.Variant_Type,
    obj_model_type_: Gltf_Object_Model_Property_Gltf_Object_Model_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4150728237)
    }
    self := self
    variant_type_ := variant_type_
    obj_model_type_ := obj_model_type_
    args := []__bindgen_gde.TypePtr {
        &variant_type_,
        &obj_model_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gltf_object_model_property_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GLTFObjectModelProperty", true)
}

@(private = "file")
__class_name: String_Name