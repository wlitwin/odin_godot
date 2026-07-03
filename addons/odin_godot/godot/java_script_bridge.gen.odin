package godot

import __bindgen_gde "godot:gdext"

Java_Script_Bridge_Constants :: enum {
}



java_script_bridge_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

java_script_bridge_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_java_script_bridge :: proc "contextless" () -> Java_Script_Bridge {
    return __bindgen_gde.classdb_construct_object(java_script_bridge_name_ref())
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

java_script_bridge_eval :: proc "contextless" (
    self: Java_Script_Bridge,
    code_: String,
    use_global_execution_context_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("eval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218087648)
    }
    self := self
    code_ := code_
    use_global_execution_context_ := use_global_execution_context_
    args := []__bindgen_gde.TypePtr {
        &code_,
        &use_global_execution_context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_get_interface :: proc "contextless" (
    self: Java_Script_Bridge,
    interface_: String,
) -> (ret: Java_Script_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1355533281)
    }
    self := self
    interface_ := interface_
    args := []__bindgen_gde.TypePtr {
        &interface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_create_callback :: proc "contextless" (
    self: Java_Script_Bridge,
    callable_: Callable,
) -> (ret: Java_Script_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 422818440)
    }
    self := self
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_is_js_buffer :: proc "contextless" (
    self: Java_Script_Bridge,
    javascript_object_: Java_Script_Object,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_js_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 821968997)
    }
    self := self
    javascript_object_ := javascript_object_
    args := []__bindgen_gde.TypePtr {
        &javascript_object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_js_buffer_to_packed_byte_array :: proc "contextless" (
    self: Java_Script_Bridge,
    javascript_buffer_: Java_Script_Object,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("js_buffer_to_packed_byte_array", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 64409880)
    }
    self := self
    javascript_buffer_ := javascript_buffer_
    args := []__bindgen_gde.TypePtr {
        &javascript_buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_create_object :: proc "contextless" (
    self: Java_Script_Bridge,
    object_: String,
    extra: ..Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_object", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3093893586)
    }
    self := self
    object_ := object_
    __fv_object := variant_from(&object_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_object
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_object)
    return
}

java_script_bridge_download_buffer :: proc "contextless" (
    self: Java_Script_Bridge,
    buffer_: Packed_Byte_Array,
    name_: String,
    mime_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("download_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3352272093)
    }
    self := self
    buffer_ := buffer_
    name_ := name_
    mime_ := mime_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &name_,
        &mime_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

java_script_bridge_pwa_needs_update :: proc "contextless" (
    self: Java_Script_Bridge,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pwa_needs_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_pwa_update :: proc "contextless" (
    self: Java_Script_Bridge,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pwa_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_script_bridge_force_fs_sync :: proc "contextless" (
    self: Java_Script_Bridge,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_fs_sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
java_script_bridge_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("JavaScriptBridge", true)
}

@(private = "file")
__class_name: String_Name