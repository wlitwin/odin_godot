package script_runtime

import "base:runtime"
import gd "godot:godot"

// Native instance layout, including private state. No process address/typeid is
// hashed. A deterministic traversal index represents recursive backreferences.
// Unknown/oversized graphs return zero: Core must not assume compatibility.
@(private)
Layout_Walk :: struct {
    hash:         u64,
    seen:         [4096]^runtime.Type_Info,
    count, depth: int,
    valid:        bool,
}

@(private)
layout_word :: proc "contextless" (walk: ^Layout_Walk, value: u64) {
    for shift in 0 ..< 8 {
        walk.hash = (walk.hash ~ ((value >> u32(shift * 8)) & 255)) * 1099511628211
    }
}

@(private)
layout_string :: proc "contextless" (walk: ^Layout_Walk, value: string) {
    layout_word(walk, u64(len(value)))

    for byte in transmute([]u8)value {
        walk.hash = (walk.hash ~ u64(byte)) * 1099511628211
    }
}

@(private)
layout_type :: proc "contextless" (walk: ^Layout_Walk, ti: ^runtime.Type_Info) {
    if !walk.valid {
        return
    }

    if ti == nil {
        layout_word(walk, 0)
        return
    }

    cursor := ti

    for {
        named, ok := cursor.variant.(runtime.Type_Info_Named)

        if !ok {
            break
        }

        layout_word(walk, 3)
        layout_string(walk, named.pkg)
        layout_string(walk, named.name)
        cursor = named.base
    }

    base := cursor
    layout_word(walk, u64(base.size))
    layout_word(walk, u64(base.align))
    // Known engine handles/values have stable external representations. Do not
    // traverse their compiler storage implementation. Scalars remain distinct.
    vt, engine := variant_type_for(ti.id)

    if engine && (ti.id == typeid_of(gd.Object) || (u32(vt) > 3 && ti.id != typeid_of(string))) {
        layout_word(walk, 1)
        layout_word(walk, u64(vt))
        return
    }

    for old, index in walk.seen[:walk.count] {
        if old == base {
            layout_word(walk, 2)
            layout_word(walk, u64(index))
            return
        }
    }

    if walk.count == len(walk.seen) || walk.depth == 256 {
        walk.valid = false
        return
    }

    walk.seen[walk.count] = base
    walk.count += 1
    walk.depth += 1
    defer walk.depth -= 1

    #partial switch value in base.variant {
    case runtime.Type_Info_Integer:
        layout_word(walk, 10)
        layout_word(walk, u64(value.signed))
        layout_word(walk, u64(value.endianness))
    case runtime.Type_Info_Rune:
        layout_word(walk, 11)
    case runtime.Type_Info_Float:
        layout_word(walk, 12)
        layout_word(walk, u64(value.endianness))
    case runtime.Type_Info_Complex:
        layout_word(walk, 13)
    case runtime.Type_Info_Quaternion:
        layout_word(walk, 14)
    case runtime.Type_Info_String:
        layout_word(walk, 15)
        layout_word(walk, u64(value.is_cstring))
        layout_word(walk, u64(value.encoding))
    case runtime.Type_Info_Boolean:
        layout_word(walk, 16)
    case runtime.Type_Info_Any:
        layout_word(walk, 17)
    case runtime.Type_Info_Type_Id:
        layout_word(walk, 18)
    case runtime.Type_Info_Pointer:
        layout_word(walk, 19)
        layout_type(walk, value.elem)
    case runtime.Type_Info_Multi_Pointer:
        layout_word(walk, 20)
        layout_type(walk, value.elem)
    case runtime.Type_Info_Procedure:
        layout_word(walk, 21)
        layout_word(walk, u64(value.variadic))
        layout_word(walk, u64(value.convention))
        layout_type(walk, value.params)
        layout_type(walk, value.results)
    case runtime.Type_Info_Array:
        layout_word(walk, 22)
        layout_word(walk, u64(value.count))
        layout_word(walk, u64(value.elem_size))
        layout_type(walk, value.elem)
    case runtime.Type_Info_Enumerated_Array:
        layout_word(walk, 23)
        layout_word(walk, u64(value.count))
        layout_word(walk, u64(value.elem_size))
        layout_word(walk, transmute(u64)value.min_value)
        layout_word(walk, transmute(u64)value.max_value)
        layout_word(walk, u64(value.is_sparse))
        layout_type(walk, value.index)
        layout_type(walk, value.elem)
    case runtime.Type_Info_Dynamic_Array:
        layout_word(walk, 24)
        layout_word(walk, u64(value.elem_size))
        layout_type(walk, value.elem)
    case runtime.Type_Info_Slice:
        layout_word(walk, 25)
        layout_word(walk, u64(value.elem_size))
        layout_type(walk, value.elem)
    case runtime.Type_Info_Parameters:
        layout_word(walk, 26)
        layout_word(walk, u64(len(value.types)))

        for element in value.types {
            layout_type(walk, element)
        }
    case runtime.Type_Info_Struct:
        layout_word(walk, 27)
        layout_word(walk, u64(value.field_count))
        layout_word(walk, u64(transmute(u8)value.flags))
        layout_word(walk, u64(value.soa_kind))
        layout_word(walk, u64(value.soa_len))

        if value.soa_kind != .None {
            layout_type(walk, value.soa_base_type)
        }

        for index in 0 ..< int(value.field_count) {
            layout_string(walk, value.names[index])
            layout_word(walk, u64(value.offsets[index]))
            layout_type(walk, value.types[index])
        }
    case runtime.Type_Info_Union:
        layout_word(walk, 28)
        layout_word(walk, u64(value.tag_offset))
        layout_word(walk, u64(value.custom_align))
        layout_word(walk, u64(value.no_nil))
        layout_word(walk, u64(value.shared_nil))
        layout_type(walk, value.tag_type)
        layout_word(walk, u64(len(value.variants)))

        for element in value.variants {
            layout_type(walk, element)
        }
    case runtime.Type_Info_Enum:
        layout_word(walk, 29)
        layout_type(walk, value.base)
        layout_word(walk, u64(len(value.names)))

        for name, index in value.names {
            layout_string(walk, name)
            layout_word(walk, transmute(u64)value.values[index])
        }
    case runtime.Type_Info_Map:
        layout_word(walk, 30)
        layout_type(walk, value.key)
        layout_type(walk, value.value)
    case runtime.Type_Info_Bit_Set:
        layout_word(walk, 31)
        layout_word(walk, u64(value.explicit_underlying))
        layout_word(walk, transmute(u64)value.lower)
        layout_word(walk, transmute(u64)value.upper)
        layout_type(walk, value.elem)
        layout_type(walk, value.underlying)
    case runtime.Type_Info_Simd_Vector:
        layout_word(walk, 32)
        layout_word(walk, u64(value.elem_size))
        layout_word(walk, u64(value.count))
        layout_type(walk, value.elem)
    case runtime.Type_Info_Matrix:
        layout_word(walk, 33)
        layout_word(walk, u64(value.elem_size))
        layout_word(walk, u64(value.elem_stride))
        layout_word(walk, u64(value.row_count))
        layout_word(walk, u64(value.column_count))
        layout_word(walk, u64(value.layout))
        layout_type(walk, value.elem)
    case runtime.Type_Info_Soa_Pointer:
        layout_word(walk, 34)
        layout_type(walk, value.elem)
    case runtime.Type_Info_Bit_Field:
        layout_word(walk, 35)
        layout_type(walk, value.backing_type)
        layout_word(walk, u64(value.field_count))

        for index in 0 ..< value.field_count {
            layout_string(walk, value.names[index])
            layout_word(walk, u64(value.bit_sizes[index]))
            layout_word(walk, u64(value.bit_offsets[index]))
            layout_type(walk, value.types[index])
        }
    case runtime.Type_Info_Fixed_Capacity_Dynamic_Array:
        layout_word(walk, 36)
        layout_word(walk, u64(value.elem_size))
        layout_word(walk, u64(value.capacity))
        layout_word(walk, u64(value.len_offset))
        layout_type(walk, value.elem)
    case:
        walk.valid = false
    }
}

instance_layout_fingerprint :: proc "contextless" (id: typeid) -> u64 {
    walk := Layout_Walk {
        hash  = 14695981039346656037,
        valid = true,
    }
    layout_string(&walk, "odin-godot-instance-layout-v1")
    layout_type(&walk, type_info_of(id))
    return walk.valid ? walk.hash : 0
}
