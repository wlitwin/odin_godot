package godot

import __bindgen_gde "godot:gdext"

Pck_Packer_Constants :: enum {
}



pck_packer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

pck_packer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_pck_packer :: proc "contextless" () -> Pck_Packer {
    return cast(Pck_Packer)__bindgen_gde.classdb_construct_object(pck_packer_name_ref())
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

pck_packer_pck_start :: proc "contextless" (
    self: Pck_Packer,
    pck_path_: String,
    alignment_: Int,
    key_: String,
    encrypt_directory_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pck_start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 508410629)
    }
    self := self
    pck_path_ := pck_path_
    alignment_ := alignment_
    key_ := key_
    encrypt_directory_ := encrypt_directory_
    args := []__bindgen_gde.TypePtr {
        &pck_path_,
        &alignment_,
        &key_,
        &encrypt_directory_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

pck_packer_add_file :: proc "contextless" (
    self: Pck_Packer,
    target_path_: String,
    source_path_: String,
    encrypt_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2215643711)
    }
    self := self
    target_path_ := target_path_
    source_path_ := source_path_
    encrypt_ := encrypt_
    args := []__bindgen_gde.TypePtr {
        &target_path_,
        &source_path_,
        &encrypt_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

pck_packer_add_file_removal :: proc "contextless" (
    self: Pck_Packer,
    target_path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_file_removal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    target_path_ := target_path_
    args := []__bindgen_gde.TypePtr {
        &target_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

pck_packer_flush :: proc "contextless" (
    self: Pck_Packer,
    verbose_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("flush", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1633102583)
    }
    self := self
    verbose_ := verbose_
    args := []__bindgen_gde.TypePtr {
        &verbose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
pck_packer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PCKPacker", true)
}

@(private = "file")
__class_name: String_Name