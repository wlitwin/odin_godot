package replay_evolution

import "core:bytes"
import "core:reflect"
import sc "godot:replay/schema"
import d "godot:replay/definitions"

// Additive conversion helper. The caller supplies the complete target defaults
// and explicitly acknowledges every added leaf path. Removed/changed fields
// require a separately authored converter; this helper never guesses semantics.
copy_preserved :: proc(old: $Old, defaults: $New, added: []string) -> (New, d.Report) {
    return copy_common(old, defaults, added, false)
}

// Explicit inverse projection, useful for fixture builders and legacy codecs.
// Every discarded target-era leaf must be acknowledged by its complete path.
remove_added :: proc(current: $New, defaults: $Old, removed: []string) -> (Old, d.Report) {
    return copy_common(current, defaults, removed, true)
}

@(private)
copy_common :: proc(old: $Old, defaults: $New, added: []string, removing: bool) -> (New, d.Report) {
    a, b: sc.Schema
    defer sc.destroy(&a)
    defer sc.destroy(&b)

    if report := sc.init(&a, Old); report.error != .None {
        return {}, d.problem(.Invalid, report.path, "unsupported source schema")
    }

    if report := sc.init(&b, New); report.error != .None {
        return {}, d.problem(.Invalid, report.path, "unsupported target schema")
    }

    report := removing ? check_additive(&b, &a, added) : check_additive(&a, &b, added)

    if report.error != .None {
        return {}, report
    }

    source := make([]u8, a.wire_size)
    defer delete(source)
    target := make([]u8, b.wire_size)
    defer delete(target)

    if sc.encode(&a, old, source).error != .None || sc.encode(&b, defaults, target).error != .None {
        return {}, d.problem(.Invalid, "$", "invalid source/default values")
    }

    for dest in b.fields {
        field, found := find(&a, dest.path)

        if !found {
            continue
        }

        copy(
            target[dest.wire_offset:dest.wire_offset + dest.width],
            source[field.wire_offset:field.wire_offset + field.width],
        )
    }

    value := defaults

    if report := sc.decode(&b, &value, target); report.error != .None {
        return {}, d.problem(.Invalid, report.path, "converted value is invalid")
    }

    return value, {}
}

verify_preserved :: proc(old: $Old, current: $New, added: []string) -> d.Report {
    expected, report := copy_preserved(old, current, added)

    if report.error != .None {
        return report
    }

    schema: sc.Schema
    defer sc.destroy(&schema)

    if sc.init(&schema, New).error != .None {
        return d.problem(.Invalid, "$", "unsupported target schema")
    }

    a, b := make([]u8, schema.wire_size), make([]u8, schema.wire_size)
    defer delete(a)
    defer delete(b)

    if sc.encode(&schema, expected, a).error != .None ||
       sc.encode(&schema, current, b).error != .None ||
       !bytes.equal(a, b) {
        return d.problem(.Invalid, "$", "a preserved field changed")
    }

    return {}
}

check_additive :: proc(a, b: ^sc.Schema, added: []string) -> d.Report {
    if !a.ready ||
       !b.ready ||
       len(a.unions) > 0 ||
       len(b.unions) > 0 ||
       !additive_shape(type_info_of(a.type), 0) ||
       !additive_shape(type_info_of(b.type), 0) {
        return d.problem(
            .Invalid,
            "$",
            "additive conversion requires supported frozen shapes (no unions or enumerated arrays)",
        )
    }

    for field in a.fields {
        dest, found := find(b, field.path)

        if !found || !compatible(field, dest) {
            return d.problem(.Invalid, field.path, "removed or changed field requires an authored conversion")
        }
    }

    count := 0

    for field in b.fields {
        if _, found := find(a, field.path); !found {
            matches := 0

            for path in added {
                if path == field.path {
                    matches += 1
                }
            }

            if matches != 1 {
                return d.problem(.Invalid, field.path, "new field needs exactly one explicit default acknowledgement")
            }

            count += 1
        }
    }

    if count != len(added) {
        return d.problem(.Invalid, "$", "unknown, duplicate or preexisting default path")
    }

    return {}
}

@(private)
find :: proc(schema: ^sc.Schema, path: string) -> (sc.Field, bool) {
    for field in schema.fields {
        if field.path == path {
            return field, true
        }
    }

    return {}, false
}

@(private)
compatible :: proc(a, b: sc.Field) -> bool {
    if a.enum_signed != b.enum_signed ||
       a.authority_only != b.authority_only ||
       a.kind != b.kind ||
       a.width != b.width ||
       a.bit_mask != b.bit_mask ||
       len(a.enum_names) != len(b.enum_names) ||
       len(a.enum_values) != len(b.enum_values) {
        return false
    }

    for name, i in a.enum_names {
        if name != b.enum_names[i] {
            return false
        }
    }

    for value, i in a.enum_values {
        if value != b.enum_values[i] {
            return false
        }
    }

    return true
}

@(private)
additive_shape :: proc(info: ^reflect.Type_Info, depth: int) -> bool {
    if depth > 64 {
        return false
    }

    #partial switch value in reflect.type_info_base(info).variant {
    case reflect.Type_Info_Integer,
         reflect.Type_Info_Rune,
         reflect.Type_Info_Float,
         reflect.Type_Info_Boolean,
         reflect.Type_Info_Enum,
         reflect.Type_Info_Bit_Set:
        return true
    case reflect.Type_Info_Array:
        return additive_shape(value.elem, depth + 1)
    case reflect.Type_Info_Struct:
        for child in value.types[:value.field_count] {
            if !additive_shape(child, depth + 1) {
                return false
            }
        }

        return true
    case:
        return false
    }
}
