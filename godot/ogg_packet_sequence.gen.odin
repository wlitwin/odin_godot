package godot

import __bindgen_gde "godot:gdext"

Ogg_Packet_Sequence_Constants :: enum {
}



ogg_packet_sequence_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

ogg_packet_sequence_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_ogg_packet_sequence :: proc "contextless" () -> Ogg_Packet_Sequence {
    return cast(Ogg_Packet_Sequence)__bindgen_gde.classdb_construct_object(ogg_packet_sequence_name_ref())
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

ogg_packet_sequence_set_packet_data :: proc "contextless" (
    self: Ogg_Packet_Sequence,
    packet_data_: Typed_Array(Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_packet_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    packet_data_ := packet_data_
    args := []__bindgen_gde.TypePtr {
        &packet_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

ogg_packet_sequence_get_packet_data :: proc "contextless" (
    self: Ogg_Packet_Sequence,
) -> (ret: Typed_Array(Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_packet_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ogg_packet_sequence_set_packet_granule_positions :: proc "contextless" (
    self: Ogg_Packet_Sequence,
    granule_positions_: Packed_Int64_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_packet_granule_positions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3709968205)
    }
    self := self
    granule_positions_ := granule_positions_
    args := []__bindgen_gde.TypePtr {
        &granule_positions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

ogg_packet_sequence_get_packet_granule_positions :: proc "contextless" (
    self: Ogg_Packet_Sequence,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_packet_granule_positions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 235988956)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ogg_packet_sequence_set_sampling_rate :: proc "contextless" (
    self: Ogg_Packet_Sequence,
    sampling_rate_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sampling_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    sampling_rate_ := sampling_rate_
    args := []__bindgen_gde.TypePtr {
        &sampling_rate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

ogg_packet_sequence_get_sampling_rate :: proc "contextless" (
    self: Ogg_Packet_Sequence,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sampling_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ogg_packet_sequence_get_length :: proc "contextless" (
    self: Ogg_Packet_Sequence,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
ogg_packet_sequence_get_granule_positions :: proc "contextless" (self: Ogg_Packet_Sequence) -> Packed_Int64_Array {
    return ogg_packet_sequence_get_packet_granule_positions(self)
}
ogg_packet_sequence_set_granule_positions :: proc "contextless" (self: Ogg_Packet_Sequence, value: Packed_Int64_Array) {
    ogg_packet_sequence_set_packet_granule_positions(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
ogg_packet_sequence_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OggPacketSequence", true)
}

@(private = "file")
__class_name: String_Name