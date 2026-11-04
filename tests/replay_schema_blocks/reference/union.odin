package schema_block_reference

import "core:fmt"
import "core:reflect"
import "core:strings"

Union_Guard :: struct {
    parent, layout: int,
    tag:            u64,
}

Union_Layout :: struct {
    field, guard, offset, size, tag_offset, tag_width, wire_offset, payload_bytes: int,
    no_nil:                                                                        bool,
    variant_sizes:                                                                 []int,
    variant_names:                                                                 []string,
}

@(private)
union_layout :: proc(
    s: ^Schema,
    base: ^reflect.Type_Info,
    info: reflect.Type_Info_Union,
    offset: int,
    path: string,
    hidden: bool,
    depth: int,
    store: bool,
    guard: int,
) {
    if info.shared_nil || info.tag_type == nil || len(info.variants) < 1 || len(info.variants) > 65535 {
        fail(s, .Unsupported_Type, path)
        return
    }

    width := info.tag_type.size

    if width != 1 && width != 2 && width != 4 && width != 8 {
        fail(s, .Unsupported_Type, path)
        return
    }

    if int(info.tag_offset) + width > base.size {
        fail(s, .Unsupported_Type, path)
        return
    }

    names := make([]string, len(info.variants), s.allocator)
    owned := false

    defer if !owned {
        for name in names {
            delete(name, s.allocator)
        }

        delete(names, s.allocator)
    }

    for variant, i in info.variants {
        if named, ok := variant.variant.(reflect.Type_Info_Named); ok {
            names[i] = fmt.aprintf("%s.%s", named.pkg, named.name)
        } else {
            names[i] = fmt.aprintf("%v", variant.id)
        }

        if len(names[i]) > 1024 {
            fail(s, .Limit, path)
            return
        }
    }

    text := fmt.aprintf("union:no_nil=%d:variants=%d{", int(info.no_nil), len(info.variants))
    append_text(s, text)
    delete(text, s.allocator)
    visible := store && !(hidden && s.options.projection == .Public)
    layout_index := -1
    payload_start := s.wire_size

    if visible {
        if len(s.fields) >= s.options.max_fields || s.wire_size > s.options.max_wire_bytes - 4 {
            fail(s, .Limit, path)
            return
        }

        layout_index = len(s.unions)
        layout := Union_Layout {
            field         = len(s.fields),
            guard         = guard,
            offset        = offset,
            size          = base.size,
            tag_offset    = offset + int(info.tag_offset),
            tag_width     = width,
            wire_offset   = s.wire_size,
            no_nil        = info.no_nil,
            variant_sizes = make([]int, len(info.variants), s.allocator),
            variant_names = names,
        }
        append(&s.unions, layout)
        owned = true
        field := Field {
            path        = strings.clone(fmt.tprintf("%s.$tag", path), s.allocator),
            offset      = layout.tag_offset,
            wire_offset = s.wire_size,
            width       = 4,
            kind        = .Union_Tag,
            guard       = guard,
            union_index = layout_index,
        }
        append(&s.fields, field)
        s.wire_size += 4
        payload_start = s.wire_size
    } else if store {
        s.excluded_fields += 1
    }

    maximum := 0

    for variant, i in info.variants {
        description := fmt.aprintf("%d:%s:", len(names[i]), names[i])
        append_text(s, description)
        delete(description, s.allocator)
        child_path := fmt.aprintf("%s<%d:%s>", path, i + 1, names[i])
        defer delete(child_path, s.allocator)
        child_guard := guard

        if visible {
            child_guard = len(s.guards)
            append(&s.guards, Union_Guard{guard, layout_index, u64(i + 1)})
            s.wire_size = payload_start
        }

        walk(s, variant, offset, child_path, hidden, depth + 1, store, child_guard)

        if s.problem.error != .None {
            return
        }

        if visible {
            size := s.wire_size - payload_start
            s.unions[layout_index].variant_sizes[i] = size
            maximum = max(maximum, size)
        }
    }

    if visible {
        s.wire_size = payload_start + maximum
        s.unions[layout_index].payload_bytes = maximum
    }

    append_text(s, "}")
}

@(private)
union_tag :: proc(layout: Union_Layout, bytes: []u8, encoded: bool) -> u64 {
    if encoded {
        return read_bits(bytes[layout.wire_offset:layout.wire_offset + 4], false)
    }

    raw := read_bits(bytes[layout.tag_offset:layout.tag_offset + layout.tag_width], ODIN_ENDIAN == .Big)

    if layout.no_nil {
        if raw >= u64(len(layout.variant_sizes)) {
            return max(u64)
        }

        return raw + 1
    }

    return raw
}

@(private)
field_active :: proc(s: ^Schema, guard: int, bytes: []u8, encoded: bool) -> bool {
    if guard < 0 {
        return true
    }

    condition := s.guards[guard]

    if !field_active(s, condition.parent, bytes, encoded) {
        return false
    }

    return union_tag(s.unions[condition.layout], bytes, encoded) == condition.tag
}

@(private)
field_bits :: proc(s: ^Schema, field: Field, bytes: []u8, encoded: bool) -> u64 {
    if field.kind == .Union_Tag {
        return union_tag(s.unions[field.union_index], bytes, encoded)
    }

    offset := encoded ? field.wire_offset : field.offset
    return read_bits(bytes[offset:offset + field.width], !encoded && field.big_endian)
}

@(private)
validate_fields :: proc(s: ^Schema, bytes: []u8, encoded: bool) -> Report {
    if len(s.unions) == 0 {
        return validate_program(s, bytes, encoded)
    }

    for index in s.checks {
        field := s.fields[index]

        if !field_active(s, field.guard, bytes, encoded) {
            continue
        }

        if !valid_bits(s, field, field_bits(s, field, bytes, encoded)) {
            return {.Invalid_Value, field.path}
        }
    }

    if encoded {
        for layout in s.unions {
            if !field_active(s, layout.guard, bytes, true) {
                continue
            }

            tag := union_tag(layout, bytes, true)
            used := tag == 0 ? 0 : layout.variant_sizes[tag - 1]

            for byte in bytes[layout.wire_offset + 4 + used:layout.wire_offset + 4 + layout.payload_bytes] {
                if byte != 0 {
                    return {.Invalid_Value, s.fields[layout.field].path}
                }
            }
        }
    }

    return {}
}

@(private)
encode_union_fields :: proc(s: ^Schema, local, out: []u8) {
    for &byte in out[:s.wire_size] {
        byte = 0
    }

    for field in s.fields {
        if !field_active(s, field.guard, local, false) {
            continue
        }

        write_bits(out[field.wire_offset:field.wire_offset + field.width], field_bits(s, field, local, false), false)
    }
}

@(private)
decode_union_fields :: proc(s: ^Schema, local, wire: []u8) {
    // Preorder clears parents before children. Preserve private local fields
    // only when the selected variant is unchanged; never reinterpret old bytes.
    for layout in s.unions {
        if !field_active(s, layout.guard, wire, true) {
            continue
        }

        tag := union_tag(layout, wire, true)

        if union_tag(layout, local, false) != tag {
            for &byte in local[layout.offset:layout.offset + layout.size] {
                byte = 0
            }
        }

        write_bits(
            local[layout.tag_offset:layout.tag_offset + layout.tag_width],
            layout.no_nil ? tag - 1 : tag,
            ODIN_ENDIAN == .Big,
        )
    }

    for field in s.fields {
        if field.kind == .Union_Tag || !field_active(s, field.guard, wire, true) {
            continue
        }

        write_bits(local[field.offset:field.offset + field.width], field_bits(s, field, wire, true), field.big_endian)
    }
}
