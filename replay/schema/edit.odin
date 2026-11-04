package replay_schema

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:math"

Edit_Error :: enum {
    None,
    Schema,
    Wrong_Type,
    Projection,
    Missing_Field,
    Inactive_Field,
    Read_Only,
    Invalid_Text,
    Out_Of_Range,
    Invalid_Value,
    Model,
}

Edit_Report :: struct {
    error:  Edit_Error,
    field:  int,
    schema: Report,
}

// Local authoring helper. Only a complete authority value may be edited; a
// public-projection roundtrip would otherwise discard omitted private fields.
// Input and destination are untouched unless schema and optional model checks pass.
edit_scalar :: proc(s: ^Schema, value: ^$T, index: int, text: string, valid: proc(_: T) -> bool) -> Edit_Report {
    if s == nil || !s.ready {
        return {error = .Schema, field = index}
    }

    if value == nil || s.type != T {
        return {error = .Wrong_Type, field = index}
    }

    if s.options.projection != .Authority {
        return {error = .Projection, field = index}
    }

    if index < 0 || index >= len(s.fields) {
        return {error = .Missing_Field, field = index}
    }

    bytes := make([]u8, s.wire_size)
    defer delete(bytes)

    if report := encode(s, value^, bytes); report.error != .None {
        return {error = .Invalid_Value, field = index, schema = report}
    }

    field := s.fields[index]

    if !field_active(s, field.guard, bytes, true) {
        return {error = .Inactive_Field, field = index}
    }

    if field.kind == .Union_Tag {
        return {error = .Read_Only, field = index}
    }

    bits, error := edit_parse(field, strings.trim_space(text))

    if error != .None {
        return {error = error, field = index}
    }

    write_bits(bytes[field.wire_offset:field.wire_offset + field.width], bits, false)
    candidate: T

    if report := decode(s, &candidate, bytes); report.error != .None {
        return {error = .Invalid_Value, field = index, schema = report}
    }

    if valid != nil && !valid(candidate) {
        return {error = .Model, field = index}
    }

    value^ = candidate
    return {field = index}
}

field_index :: proc(s: ^Schema, path: string) -> (int, bool) {
    if s == nil || !s.ready {
        return -1, false
    }

    for field, index in s.fields {
        if field.path == path {
            return index, true
        }
    }

    return -1, false
}

// Owned display text. Union discriminants are inspectable, but changing them
// requires constructing a complete variant rather than a scalar overwrite.
scalar_text :: proc(s: ^Schema, value: $T, index: int) -> (string, Edit_Error) {
    if s == nil || !s.ready {
        return "", .Schema
    }

    if s.type != T {
        return "", .Wrong_Type
    }

    if index < 0 || index >= len(s.fields) {
        return "", .Missing_Field
    }

    copy := value
    bytes := (cast([^]u8)&copy)[:size_of(T)]

    if validate_fields(s, bytes, false).error != .None {
        return "", .Invalid_Value
    }

    field := s.fields[index]

    if !field_active(s, field.guard, bytes, false) {
        return "", .Inactive_Field
    }

    bits := field_bits(s, field, bytes, false)

    if field.kind == .Float {
        v: f64

        switch field.width {
        case 2:
            v = f64(transmute(f16)u16(bits))
        case 4:
            v = f64(transmute(f32)u32(bits))
        case 8:
            v = transmute(f64)bits
        }

        return fmt.aprintf("%.17g", v), .None
    }

    return diff_value(
            s,
            Difference{field = index, kind = field.kind, width = field.width, left = bits, left_present = true},
            .Left,
        ),
        .None
}

@(private)
edit_parse :: proc(field: Field, text: string) -> (u64, Edit_Error) {
    if len(text) == 0 || len(text) > 128 {
        return 0, .Invalid_Text
    }

    bits: u64

    switch field.kind {
    case .Boolean:
        if text == "true" {
            return 1, .None
        }

        if text == "false" {
            return 0, .None
        }

        return 0, .Invalid_Text
    case .Signed:
        raw, error := edit_integer(text, true)

        if error != .None {
            return 0, error
        }

        value := i64(raw)

        if field.width < 8 {
            limit := i64(1) << uint(field.width * 8 - 1)

            if value < -limit || value >= limit {
                return 0, .Out_Of_Range
            }
        }

        bits = u64(value)
    case .Unsigned, .Bits:
        value, error := edit_integer(text, false)

        if error != .None {
            return 0, error
        }

        if field.width < 8 && value > mask_for(field.width) {
            return 0, .Out_Of_Range
        }

        bits = value
    case .Enumeration:
        named := false

        for name, i in field.enum_names {
            if text == name {
                bits = u64(i64(field.enum_values[i]))
                named = true
                break
            }
        }

        if !named {
            value, error := edit_integer(text, true)

            if error != .None {
                return 0, error
            }

            bits = value
        }

        found := false

        for value in field.enum_values {
            if u64(i64(value)) == bits {
                found = true
                break
            }
        }

        if !found {
            return 0, .Out_Of_Range
        }
    case .Float:
        value, ok := strconv.parse_f64(text)

        if !ok {
            return 0, .Invalid_Text
        }

        if math.is_nan(value) || math.is_inf(value) {
            return 0, .Out_Of_Range
        }

        switch field.width {
        case 2:
            v := f16(value)

            if math.is_inf(f64(v)) {
                return 0, .Out_Of_Range
            }

            bits = u64(transmute(u16)v)
        case 4:
            v := f32(value)

            if math.is_inf(f64(v)) {
                return 0, .Out_Of_Range
            }

            bits = u64(transmute(u32)v)
        case 8:
            bits = transmute(u64)value
        }
    case .Union_Tag:
        return 0, .Read_Only
    }

    return bits, .None
}

// Checked decimal or 0x hexadecimal input. Do not use wrapping integer parsers
// for authoring: a mistyped large value must never become a different valid one.
@(private)
edit_integer :: proc(text: string, signed: bool) -> (u64, Edit_Error) {
    if len(text) == 0 {
        return 0, .Invalid_Text
    }

    negative := false
    at := 0

    if text[0] == '-' || text[0] == '+' {
        negative = text[0] == '-'
        at += 1
    }

    if negative && !signed {
        return 0, .Out_Of_Range
    }

    limit := max(u64)

    if signed {
        limit = u64(max(i64))

        if negative {
            limit += 1
        }
    }

    base: u64 = 10

    if len(text) - at >= 2 && text[at] == '0' && (text[at + 1] == 'x' || text[at + 1] == 'X') {
        base = 16
        at += 2
    }

    if at == len(text) {
        return 0, .Invalid_Text
    }

    result: u64

    for c in text[at:] {
        digit: u64

        switch {
        case c >= '0' && c <= '9':
            digit = u64(c - '0')
        case c >= 'a' && c <= 'f':
            digit = u64(c - 'a' + 10)
        case c >= 'A' && c <= 'F':
            digit = u64(c - 'A' + 10)
        case:
            return 0, .Invalid_Text
        }

        if digit >= base {
            return 0, .Invalid_Text
        }

        if result > (limit - digit) / base {
            return 0, .Out_Of_Range
        }

        result = result * base + digit
    }

    if negative {
        result = 0 - result
    }

    return result, .None
}
