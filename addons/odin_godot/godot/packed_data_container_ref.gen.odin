package godot

import __bindgen_gde "godot:gdext"

Packed_Data_Container_Ref_Constants :: enum {
}



packed_data_container_ref_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

packed_data_container_ref_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_packed_data_container_ref :: proc "contextless" () -> Packed_Data_Container_Ref {
    return cast(Packed_Data_Container_Ref)__bindgen_gde.classdb_construct_object(packed_data_container_ref_name_ref())
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

packed_data_container_ref_size :: proc "contextless" (
    self: Packed_Data_Container_Ref,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
packed_data_container_ref_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PackedDataContainerRef", true)
}

@(private = "file")
__class_name: String_Name