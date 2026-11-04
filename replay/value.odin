package replay

import "core:reflect"

// The first implementation owns frames by value. Recursively reject references
// so a snapshot never silently aliases live state. This is a local storage
// contract, not a wire ABI or a proof of deterministic gameplay.
value_supported :: proc(t: typeid) -> bool {
    return value_info_supported(type_info_of(t))
}

@(private)
value_info_supported :: proc(info: ^reflect.Type_Info) -> bool {
    if info == nil {
        return false
    }

    base := reflect.type_info_base(info)

    #partial switch v in base.variant {
    case reflect.Type_Info_Integer, reflect.Type_Info_Rune, reflect.Type_Info_Float, reflect.Type_Info_Boolean:
        return true
    case reflect.Type_Info_Enum:
        return value_info_supported(v.base)
    case reflect.Type_Info_Bit_Set:
        return value_info_supported(v.underlying)
    case reflect.Type_Info_Array:
        return value_info_supported(v.elem)
    case reflect.Type_Info_Enumerated_Array:
        return value_info_supported(v.elem)
    case reflect.Type_Info_Union:
        if v.shared_nil || v.tag_type == nil || len(v.variants) == 0 {
            return false
        }

        for variant in v.variants {
            if !value_info_supported(variant) {
                return false
            }
        }

        return true
    case reflect.Type_Info_Struct:
        if v.soa_kind != .None || .raw_union in v.flags {
            return false
        }

        for field in v.types[:v.field_count] {
            if !value_info_supported(field) {
                return false
            }
        }

        return true
    }

    return false
}
