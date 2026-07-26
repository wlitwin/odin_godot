package godot

import __bindgen_gde "godot:gdext"

Java_Class_Wrapper_Constants :: enum {
}



java_class_wrapper_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

java_class_wrapper_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_java_class_wrapper :: proc "contextless" () -> Java_Class_Wrapper {
    return __bindgen_gde.classdb_construct_object(java_class_wrapper_name_ref())
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

java_class_wrapper_wrap :: proc "contextless" (
    self: Java_Class_Wrapper,
    name_: String,
) -> (ret: Java_Class) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1124367868)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_class_wrapper_get_exception :: proc "contextless" (
    self: Java_Class_Wrapper,
) -> (ret: Java_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3277089691)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_class_wrapper_create_sam_callback :: proc "contextless" (
    self: Java_Class_Wrapper,
    sam_interface_: String,
    callable_: Callable,
) -> (ret: Java_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_sam_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2479014754)
    }
    self := self
    sam_interface_ := sam_interface_
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &sam_interface_,
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

java_class_wrapper_create_proxy :: proc "contextless" (
    self: Java_Class_Wrapper,
    object_: Object,
    interfaces_: Packed_String_Array,
) -> (ret: Java_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2694931752)
    }
    self := self
    object_ := object_
    interfaces_ := interfaces_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &interfaces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
java_class_wrapper_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("JavaClassWrapper", true)
}

@(private = "file")
__class_name: String_Name