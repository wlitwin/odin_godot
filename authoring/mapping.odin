package authoring

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import gd "godot:godot"

Field :: struct {
    kind:                   enum {
        Copy,
        Integer,
        Number,
    },
    source, target:         string,
    minimum, maximum:       i64,
    min_number, max_number: f64,
}

field :: proc(source: string, target := "") -> Field {
    return {kind = .Copy, source = source, target = target}
}

integer :: proc(source: string, minimum, maximum: i64, target := "") -> Field {
    return {kind = .Integer, source = source, target = target, minimum = minimum, maximum = maximum}
}

number :: proc(source: string, minimum, maximum: f64, target := "") -> Field {
    return {kind = .Number, source = source, target = target, min_number = minimum, max_number = maximum}
}

// Cold-path mapping of explicitly selected fields. Paths traverse value structs,
// never pointers. On any error destination is unchanged. Conversions of strings,
// Resource references and game enums remain the caller's semantic decisions.
map_fields :: proc(source: ^$Source, destination: ^$Destination, fields: []Field, path := "$") -> Report {
    if source == nil || destination == nil {
        return problem(.Invalid, path, "mapping requires source and destination values")
    }
    candidate := destination^
    for rule, i in fields {
        field_path := fmt.tprintf("%s.%s", path, rule.source)
        src, source_ok := resolve_field(source, type_info_of(Source), rule.source)
        target := rule.target == "" ? rule.source : rule.target
        dst, target_ok := resolve_field(&candidate, type_info_of(Destination), target)
        if !source_ok || !target_ok {
            return problem(
                .Invalid,
                field_path,
                fmt.tprintf("unknown source or destination value field (target %s)", target),
            )
        }
        for previous in fields[:i] {
            previous_name := previous.target == "" ? previous.source : previous.target
            other, _ := resolve_field(&candidate, type_info_of(Destination), previous_name)
            start, end := uintptr(dst.data), uintptr(dst.data) + uintptr(dst.info.size)
            if start < uintptr(other.data) + uintptr(other.info.size) && uintptr(other.data) < end {
                return problem(
                    .Invalid,
                    field_path,
                    fmt.tprintf("destination %s overlaps earlier field %s", target, previous_name),
                )
            }
        }
        switch rule.kind {
        case .Copy:
            if src.info.id != dst.info.id || !copyable(src.info) {
                return problem(
                    .Invalid,
                    field_path,
                    "copy requires identical pointer-free value types; map owned data explicitly",
                )
            }
            mem.copy(dst.data, src.data, src.info.size)
        case .Integer:
            value, ok := read_integer(src)
            if !ok || !integer_bounds_fit(dst.info, rule.minimum, rule.maximum) {
                return problem(
                    .Invalid,
                    field_path,
                    "expected native integer types and declared bounds that fit the target",
                )
            }
            if value < rule.minimum || value > rule.maximum {
                return problem(
                    .Invalid,
                    field_path,
                    fmt.tprintf("integer %d outside allowed range %d..%d", value, rule.minimum, rule.maximum),
                )
            }
            write_integer(dst, value)
        case .Number:
            value, ok := read_number(src)
            target_info := runtime.type_info_base(dst.info)
            target_float, is_float := target_info.variant.(runtime.Type_Info_Float)
            if !ok ||
               !is_float ||
               target_float.endianness != .Platform ||
               (target_info.size != 4 && target_info.size != 8) ||
               !finite(rule.min_number) ||
               !finite(rule.max_number) ||
               rule.min_number > rule.max_number {
                return problem(.Invalid, field_path, "expected native f32/f64 fields and finite ordered bounds")
            }
            if !finite(value) ||
               value < rule.min_number ||
               value > rule.max_number ||
               (target_info.size == 4 && math.abs(value) > f64(max(f32))) {
                return problem(
                    .Invalid,
                    field_path,
                    fmt.tprintf(
                        "number %v is nonfinite, outside %v..%v or overflows the target",
                        value,
                        rule.min_number,
                        rule.max_number,
                    ),
                )
            }
            if target_info.size == 4 {
                write_value(dst.data, f32(value))
            } else {
                write_value(dst.data, value)
            }
        }
    }
    destination^ = candidate
    return {}
}

@(private)
Field_View :: struct {
    data: rawptr,
    info: ^runtime.Type_Info,
}

@(private)
resolve_field :: proc(data: rawptr, info: ^runtime.Type_Info, path: string) -> (Field_View, bool) {
    if path == "" {return {}, false}
    current := Field_View{data, info}
    remaining := path
    for {
        dot := strings.index_byte(remaining, '.')
        name := dot < 0 ? remaining : remaining[:dot]
        if engine_handle(current.info) {return {}, false}
        structure, ok := runtime.type_info_base(current.info).variant.(runtime.Type_Info_Struct)
        if !ok || .raw_union in structure.flags || structure.soa_kind != .None {return {}, false}
        found := false
        for field_name, i in structure.names[:structure.field_count] {
            if field_name == name {
                current.data = rawptr(uintptr(current.data) + structure.offsets[i])
                current.info = structure.types[i]
                found = true
                break
            }
        }
        if !found {return {}, false}
        if dot < 0 {return current, true}
        remaining = remaining[dot + 1:]
        if remaining == "" {return {}, false}
    }
}

@(private)
engine_handle :: proc(info: ^runtime.Type_Info) -> bool {
    // Managed Godot builtins use opaque words rather than Odin pointers. Named
    // and distinct wrappers may flatten their base metadata, so compare bases.
    base := runtime.type_info_base(info)
    return(
        base == runtime.type_info_base(type_info_of(gd.Variant)) ||
        base == runtime.type_info_base(type_info_of(gd.Opaque(1))) ||
        base == runtime.type_info_base(type_info_of(gd.Opaque(2))) ||
        base == runtime.type_info_base(type_info_of(gd.Opaque(4))) \
    )
}

@(private)
copyable :: proc(info: ^runtime.Type_Info) -> bool {
    if engine_handle(info) {return false}
    #partial switch value in runtime.type_info_base(info).variant {
    case runtime.Type_Info_Integer,
         runtime.Type_Info_Rune,
         runtime.Type_Info_Float,
         runtime.Type_Info_Boolean,
         runtime.Type_Info_Enum,
         runtime.Type_Info_Bit_Set:
        return true
    case runtime.Type_Info_Array:
        return copyable(value.elem)
    case runtime.Type_Info_Enumerated_Array:
        return copyable(value.elem)
    case runtime.Type_Info_Struct:
        if value.soa_kind != .None || .raw_union in value.flags {return false}
        for field_type in value.types[:value.field_count] {
            if !copyable(field_type) {return false}
        }
        return true
    case:
        return false
    }
}

// Byte copies also support unaligned fields in packed authoring/value structs.
@(private)
read_value :: proc(data: rawptr, $T: typeid) -> T {
    value: T
    mem.copy(&value, data, size_of(T))
    return value
}

@(private)
write_value :: proc(data: rawptr, value: $T) {
    value := value
    mem.copy(data, &value, size_of(T))
}

@(private)
integer_bounds_fit :: proc(info: ^runtime.Type_Info, minimum, maximum: i64) -> bool {
    info := runtime.type_info_base(info)
    integer, ok := info.variant.(runtime.Type_Info_Integer)
    if !ok || integer.endianness != .Platform || minimum > maximum {return false}
    if info.size != 1 && info.size != 2 && info.size != 4 && info.size != 8 {return false}
    if integer.signed {
        if info.size == 8 {return true}
        limit := i64(1) << uint(info.size * 8 - 1)
        return minimum >= -limit && maximum < limit
    }
    if minimum < 0 {return false}
    return info.size == 8 || u64(maximum) < u64(1) << uint(info.size * 8)
}

@(private)
read_integer :: proc(field: Field_View) -> (i64, bool) {
    info := runtime.type_info_base(field.info)
    integer, ok := info.variant.(runtime.Type_Info_Integer)
    if !ok || integer.endianness != .Platform {return 0, false}
    if integer.signed {
        switch info.size {
        case 1:
            return i64(read_value(field.data, i8)), true
        case 2:
            return i64(read_value(field.data, i16)), true
        case 4:
            return i64(read_value(field.data, i32)), true
        case 8:
            return read_value(field.data, i64), true
        }
    } else {
        value: u64
        switch info.size {
        case 1:
            value = u64(read_value(field.data, u8))
        case 2:
            value = u64(read_value(field.data, u16))
        case 4:
            value = u64(read_value(field.data, u32))
        case 8:
            value = read_value(field.data, u64)
        case:
            return 0, false
        }
        if value <= u64(max(i64)) {return i64(value), true}
    }
    return 0, false
}

@(private)
write_integer :: proc(field: Field_View, value: i64) {
    info := runtime.type_info_base(field.info)
    integer := info.variant.(runtime.Type_Info_Integer)
    if integer.signed {
        switch info.size {
        case 1:
            write_value(field.data, i8(value))
        case 2:
            write_value(field.data, i16(value))
        case 4:
            write_value(field.data, i32(value))
        case 8:
            write_value(field.data, value)
        }
    } else {
        switch info.size {
        case 1:
            write_value(field.data, u8(value))
        case 2:
            write_value(field.data, u16(value))
        case 4:
            write_value(field.data, u32(value))
        case 8:
            write_value(field.data, u64(value))
        }
    }
}

@(private)
finite :: proc(value: f64) -> bool {return !math.is_nan(value) && !math.is_inf(value)}

@(private)
read_number :: proc(field: Field_View) -> (f64, bool) {
    info := runtime.type_info_base(field.info)
    value, ok := info.variant.(runtime.Type_Info_Float)
    if !ok || value.endianness != .Platform {return 0, false}
    switch info.size {
    case 4:
        return f64(read_value(field.data, f32)), true
    case 8:
        return read_value(field.data, f64), true
    }
    return 0, false
}
