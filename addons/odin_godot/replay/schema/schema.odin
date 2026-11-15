package replay_schema

import "core:fmt"
import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:reflect"
import "core:strings"

Projection :: enum u8 {
    Authority,
    Public,
}

Kind :: enum u8 {
    Unsigned,
    Signed,
    Float,
    Boolean,
    Enumeration,
    Bits,
    Union_Tag,
}

Error :: enum {
    None,
    Already_Initialized,
    Not_Ready,
    Invalid_Options,
    Unsupported_Type,
    Platform_Integer,
    Invalid_Tag,
    Limit,
    Wrong_Type,
    Wrong_Size,
    Invalid_Value,
    Invalid_Header,
    Schema_Mismatch,
    Context_Mismatch,
    Checksum_Mismatch,
    Allocation_Failed,
}

Report :: struct {
    error: Error,
    path:  string,
}

Options :: struct {
    projection:     Projection,
    finite_floats:  bool,
    max_wire_bytes: int,
    max_fields:     int,
}

DEFAULT_OPTIONS :: Options{.Authority, true, 1024 * 1024, 65536}
FORMAT_VERSION :: 1

// Local compiled metadata. Offsets/endian flags do not enter the canonical
// fingerprint. Paths and enum definitions do. Never transmit this struct.
Field :: struct {
    path:                        string,
    offset:                      int,
    wire_offset:                 int,
    width:                       int,
    kind:                        Kind,
    big_endian:                  bool,
    enum_signed, authority_only: bool, // revision tooling; canonical contract already contains both
    enum_values:                 []reflect.Type_Info_Enum_Value, // compiler-owned metadata
    enum_names:                  []string, // compiler-owned; diagnostic names do not alter wire metadata
    bit_mask:                    u64,
    guard, union_index:          int,
}

// Disjoint outer array regions in canonical byte coordinates. Local compression
// metadata only; excluded from fingerprints and canonical serialization.
Array_Span :: struct {
    offset, stride, count: int,
}

@(private)
Copy_Span :: struct {
    offset, wire_offset, size: int,
    reverse:                   bool,
}

// Persistent scalar paths share owned blocks. The bytes still use the supplied
// allocator, including its admission accounting; thousands of tiny paths do
// not each consume a separate allocator bookkeeping slot.
@(private)
Schema_Path_Block :: struct {
    next:           ^Schema_Path_Block,
    used, capacity: int,
}

// Single owner. init builds metadata from compiler type information; encode and
// decode allocate nothing. Destroy even a failed init to release diagnostics.
Schema :: struct {
    allocator:           mem.Allocator,
    initialized, ready:  bool,
    type:                typeid,
    options:             Options,
    fields:              [dynamic]Field,
    checks:              [dynamic]int,
    validation:          [dynamic]Check,
    validation_blocks:   [dynamic]Validation_Block,
    spans:               [dynamic]Copy_Span,
    arrays:              [dynamic]Array_Span,
    shuffle_fingerprint: u64,
    canonical:           [dynamic]u8,
    wire_size:           int,
    fingerprint:         u64,
    unions:              [dynamic]Union_Layout,
    guards:              [dynamic]Union_Guard,
    excluded_fields:     int,
    problem:             Report,
    _paths:              ^Schema_Path_Block,
}

init :: proc(s: ^Schema, t: typeid, options := DEFAULT_OPTIONS, allocator := context.allocator) -> Report {
    if s.initialized {
        return {error = .Already_Initialized}
    }

    if t == nil ||
       options.projection > .Public ||
       options.max_wire_bytes < 1 ||
       options.max_wire_bytes > 1024 * 1024 ||
       options.max_fields < 1 ||
       options.max_fields > 65536 {
        return {error = .Invalid_Options}
    }

    s.allocator, s.initialized, s.type, s.options = allocator, true, t, options
    s.fields = metadata_array(s, Field, 16)
    s.arrays = metadata_array(s, Array_Span, 0)
    s.canonical = metadata_array(s, u8, 256)
    s.unions = metadata_array(s, Union_Layout, 0)
    s.guards = metadata_array(s, Union_Guard, 0)

    if s.problem.error != .None {
        return s.problem
    }

    context.allocator = allocator
    header := metadata_format(
        s,
        "replay-schema:%d;projection:%d;finite:%d;",
        FORMAT_VERSION,
        options.projection,
        int(options.finite_floats),
    )
    defer delete(header, allocator)
    append_text(s, header)
    walk(s, type_info_of(t), 0, "$", false, 0, true, -1)

    if s.problem.error != .None {
        return s.problem
    }

    compile_copy_program(s)

    if s.problem.error != .None {
        return s.problem
    }

    compile_validation(s)

    if s.problem.error != .None {
        return s.problem
    }

    s.fingerprint = digest(s.canonical[:])
    s.shuffle_fingerprint = shuffle_signature(s)
    s.ready = true
    return {}
}

destroy :: proc(s: ^Schema) {
    // Union tag paths are individually formatted; scalar/diagnostic paths borrow
    // the Schema's blocks and expire together at destroy.
    for field in s.fields {
        if field.kind == .Union_Tag {
            delete(field.path, s.allocator)
        }
    }

    delete(s.fields)
    delete(s.checks)
    delete(s.validation)
    delete(s.validation_blocks)
    delete(s.spans)
    delete(s.arrays)

    for layout in s.unions {
        delete(layout.variant_sizes, s.allocator)

        for name in layout.variant_names {
            delete(name, s.allocator)
        }

        delete(layout.variant_names, s.allocator)
    }

    delete(s.unions)
    delete(s.guards)
    delete(s.canonical)
    block := s._paths

    for block != nil {
        next := block.next
        mem.free(block, s.allocator)
        block = next
    }

    s^ = {}
}

// Merge only truly adjacent bytes in both layouts. Padding and omitted private
// fields split spans, and endian-qualified scalars keep individual reversal.
@(private)
compile_copy_program :: proc(s: ^Schema) {
    s.checks = metadata_array(s, int, min(len(s.fields), 64))
    s.spans = metadata_array(s, Copy_Span, min(len(s.fields), 64))

    if s.problem.error != .None {
        return
    }

    for field, i in s.fields {
        if field.kind != .Unsigned && field.kind != .Signed && !(field.kind == .Float && !s.options.finite_floats) {
            if !metadata_append(s, &s.checks, i) {
                return
            }
        }

        if len(s.unions) > 0 {
            continue
        }

        reverse := field.big_endian && field.width > 1

        if !reverse && len(s.spans) > 0 {
            last := &s.spans[len(s.spans) - 1]

            if !last.reverse &&
               last.offset + last.size == field.offset &&
               last.wire_offset + last.size == field.wire_offset {
                last.size += field.width
                continue
            }
        }

        if !metadata_append(s, &s.spans, Copy_Span{field.offset, field.wire_offset, field.width, reverse}) {
            return
        }
    }
}

// FNV-1a is a deterministic compatibility/content checksum, not authentication.
digest :: proc(bytes: []u8, seed: u64 = 0xcbf29ce484222325) -> u64 {
    h := seed
    i := 0

    // Eight zero bytes advance FNV-1a by prime^8 modulo 2^64. Canonical
    // worlds contain long zero regions; dense blocks retain the exact byte fold.
    // The unaligned load tests only zero, so this is endian-independent.
    for len(bytes) - i >= 8 {
        word := intrinsics.unaligned_load(cast(^u64)&bytes[i])

        if word == 0 {
            h *= 0x1efac7090aef4a21
        } else {
            for b in bytes[i:i + 8] {
                h = (h ~ u64(b)) * 0x100000001b3
            }
        }

        i += 8
    }

    for b in bytes[i:] {
        h = (h ~ u64(b)) * 0x100000001b3
    }

    return h
}

@(private)
fail :: proc(s: ^Schema, error: Error, path: string) {
    if s.problem.error != .None {
        return
    }

    owned := metadata_clone(s, path)

    if s.problem.error == .None {
        s.problem = {error, owned}
    }
}

// Allocation errors cannot depend on allocating a diagnostic path. Partial
// metadata remains owned by Schema and destroy is valid after every failure.
@(private)
allocation_failed :: proc(s: ^Schema) {
    s.problem = {
        error = .Allocation_Failed,
    }
    s.ready = false
    s.fingerprint = 0
    s.shuffle_fingerprint = 0
}

@(private)
metadata_array :: proc(s: ^Schema, $T: typeid, capacity: int) -> [dynamic]T {
    if s.problem.error != .None {
        return {}
    }

    value, error := make([dynamic]T, 0, capacity, s.allocator)

    if error != .None {
        allocation_failed(s)
    }

    return value
}

@(private)
metadata_slice :: proc(s: ^Schema, $T: typeid, count: int) -> []T {
    if s.problem.error != .None {
        return nil
    }

    value, error := make([]T, count, s.allocator)

    if error != .None {
        allocation_failed(s)
    }

    return value
}

@(private)
metadata_append :: proc(s: ^Schema, array: ^[dynamic]$T, value: T) -> bool {
    if s.problem.error != .None {
        return false
    }

    _, error := append(array, value)

    if error != .None {
        allocation_failed(s)
        return false
    }

    return true
}

@(private)
metadata_clone :: proc(s: ^Schema, value: string) -> string {
    if s.problem.error != .None {
        return ""
    }

    if len(value) == 0 {
        return ""
    }

    block := s._paths

    if block == nil || len(value) > block.capacity - block.used {
        capacity := max(4096, len(value))

        if capacity > max(int) - size_of(Schema_Path_Block) {
            allocation_failed(s)
            return ""
        }

        pointer, error := mem.alloc(size_of(Schema_Path_Block) + capacity, align_of(Schema_Path_Block), s.allocator)

        if error != .None || pointer == nil {
            allocation_failed(s)
            return ""
        }

        block = cast(^Schema_Path_Block)pointer
        block^ = {
            next     = s._paths,
            capacity = capacity,
        }
        s._paths = block
    }

    bytes := (cast([^]u8)block)[size_of(Schema_Path_Block):size_of(Schema_Path_Block) + block.capacity]
    result := bytes[block.used:block.used + len(value)]
    copy(result, transmute([]u8)value)
    block.used += len(value)
    return string(result)
}

@(private)
// fmt has no allocation-error result. This forwarding adapter records errors
// until fmt returns; only its plain owned string escapes, never the adapter.
metadata_format :: proc(s: ^Schema, format: string, args: ..any) -> string {
    if s.problem.error != .None {
        return ""
    }

    Format_Allocator :: struct {
        source: mem.Allocator,
        failed: bool,
    }

    state := Format_Allocator {
        source = s.allocator,
    }
    allocator := mem.Allocator {
        data = &state,
        procedure = proc(
            data: rawptr,
            mode: runtime.Allocator_Mode,
            size, alignment: int,
            old: rawptr,
            old_size: int,
            location: runtime.Source_Code_Location,
        ) -> (
            []u8,
            runtime.Allocator_Error,
        ) {
            state := cast(^Format_Allocator)data
            value, error := state.source.procedure(state.source.data, mode, size, alignment, old, old_size, location)

            if size > 0 &&
               (mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed) &&
               error != .None {
                state.failed = true
            }

            return value, error
        },
    }
    result := fmt.aprintf(format, ..args, allocator = allocator)

    if state.failed {
        delete(result, s.allocator)
        allocation_failed(s)
        return ""
    }

    return result
}

@(private)
append_text :: proc(s: ^Schema, value: string) {
    if s.problem.error != .None {
        return
    }

    if len(value) > 4 * 1024 * 1024 - len(s.canonical) {
        fail(s, .Limit, "$schema")
        return
    }

    _, error := append(&s.canonical, ..transmute([]u8)value)

    if error != .None {
        allocation_failed(s)
    }
}

@(private)
mask_for :: proc(width: int) -> u64 {
    return width == 8 ? max(u64) : (u64(1) << uint(width * 8)) - 1
}

@(private)
walk :: proc(
    s: ^Schema,
    info: ^reflect.Type_Info,
    offset: int,
    path: string,
    hidden: bool,
    depth: int,
    store: bool,
    guard: int,
) {
    if s.problem.error != .None {
        return
    }

    if info == nil || depth > 64 || len(path) > 4096 {
        fail(s, .Limit, path)
        return
    }

    // Inspect every distinct/alias layer: stripping directly to core type would
    // let a distinct int/uintptr silently become a portable-looking integer.
    base := info

    for {
        if base.id == int || base.id == uint || base.id == uintptr {
            fail(s, .Platform_Integer, path)
            return
        }

        if named, ok := base.variant.(reflect.Type_Info_Named); ok {
            base = named.base
        } else {
            break
        }
    }

    field := Field {
        authority_only = hidden,
        offset         = offset,
        width          = base.size,
        big_endian     = ODIN_ENDIAN == .Big,
        guard          = guard,
        union_index    = -1,
    }
    scalar := true

    #partial switch value in base.variant {
    case reflect.Type_Info_Integer:
        field.kind = value.signed ? .Signed : .Unsigned

        if value.endianness != .Platform {
            field.big_endian = value.endianness == .Big
        }
    case reflect.Type_Info_Rune:
        field.kind = .Signed
    case reflect.Type_Info_Float:
        field.kind = .Float

        if value.endianness != .Platform {
            field.big_endian = value.endianness == .Big
        }

        if base.size != 2 && base.size != 4 && base.size != 8 {
            fail(s, .Unsupported_Type, path)
            return
        }
    case reflect.Type_Info_Boolean:
        field.kind = .Boolean

        if base.size != 1 {
            fail(s, .Unsupported_Type, path)
            return
        }
    case reflect.Type_Info_Enum:
        field.kind = .Enumeration
        field.enum_values = value.values
        field.enum_names = value.names
        integer := reflect.type_info_base(value.base)

        if integer.id == int || integer.id == uint || integer.id == uintptr {
            fail(s, .Platform_Integer, path)
            return
        }

        if kind, ok := integer.variant.(reflect.Type_Info_Integer); ok {
            if kind.endianness != .Platform {
                field.big_endian = kind.endianness == .Big
            }

            field.enum_signed = kind.signed
            definition := metadata_format(s, "enum:%d:%d{", int(kind.signed), integer.size)
            append_text(s, definition)
            delete(definition, s.allocator)

            for val, i in value.values {
                entry := metadata_format(s, "%d:%s=%d;", len(value.names[i]), value.names[i], i64(val))
                append_text(s, entry)
                delete(entry, s.allocator)
            }

            append_text(s, "}")
        } else {
            fail(s, .Unsupported_Type, path)
            return
        }
    case reflect.Type_Info_Bit_Set:
        field.kind = .Bits

        if value.upper < value.lower || u64(value.upper) - u64(value.lower) >= 64 || base.size > 8 {
            fail(s, .Unsupported_Type, path)
            return
        }

        if value.underlying != nil {
            if integer, ok := reflect.type_info_base(value.underlying).variant.(reflect.Type_Info_Integer); ok {
                if integer.endianness != .Platform {
                    field.big_endian = integer.endianness == .Big
                }
            }
        }

        enum_info: reflect.Type_Info_Enum
        has_enum := false

        if value.elem != nil {
            enum_info, has_enum = reflect.type_info_base(value.elem).variant.(reflect.Type_Info_Enum)
        }

        if has_enum {
            field.enum_names, field.enum_values = enum_info.names, enum_info.values
            enum_names(s, enum_info)

            for bit in enum_info.values {
                if i64(bit) >= value.lower && i64(bit) <= value.upper {
                    field.bit_mask |= u64(1) << uint(i64(bit) - value.lower)
                }
            }
        } else {
            for bit in u64(0) ..= u64(value.upper) - u64(value.lower) {
                field.bit_mask |= u64(1) << uint(bit)
            }
        }

        definition := metadata_format(s, "bits:%d:%d:%d;", value.lower, value.upper, field.bit_mask)
        append_text(s, definition)
        delete(definition, s.allocator)
    case reflect.Type_Info_Union:
        union_layout(s, base, value, offset, path, hidden, depth, store, guard)
        return
    case reflect.Type_Info_Struct:
        scalar = false

        if value.soa_kind != .None || .raw_union in value.flags {
            fail(s, .Unsupported_Type, path)
            return
        }

        append_text(s, "struct{")

        for child, i in value.types[:value.field_count] {
            child_path := metadata_format(s, "%s.%s", path, value.names[i])
            private := hidden

            if tag, tagged := reflect.struct_tag_lookup(reflect.Struct_Tag(value.tags[i]), "replay"); tagged {
                if tag != "authority" {
                    fail(s, .Invalid_Tag, child_path)
                } else {
                    private = true
                }
            }

            name := metadata_format(s, "%d:%s=%d:", len(value.names[i]), value.names[i], int(private))
            append_text(s, name)
            delete(name, s.allocator)
            walk(s, child, offset + int(value.offsets[i]), child_path, private, depth + 1, store, guard)
            delete(child_path, s.allocator)

            if s.problem.error != .None {
                return
            }
        }

        append_text(s, "}")
    case reflect.Type_Info_Array:
        scalar = false
        array(s, value.elem, value.count, value.elem_size, offset, path, hidden, depth, store, guard)
    case reflect.Type_Info_Enumerated_Array:
        scalar = false
        // Record the index's meaning as well as its storage count.
        append_text(s, "index{")

        if enum_info, ok := reflect.type_info_base(value.index).variant.(reflect.Type_Info_Enum); ok {
            enum_names(s, enum_info)
        } else {
            fail(s, .Unsupported_Type, path)
            return
        }

        index := metadata_format(
            s,
            "range:%d:%d:sparse:%d;",
            i64(value.min_value),
            i64(value.max_value),
            int(value.is_sparse),
        )
        append_text(s, index)
        delete(index, s.allocator)
        append_text(s, "}")
        array(s, value.elem, value.count, value.elem_size, offset, path, hidden, depth, store, guard)
    case:
        fail(s, .Unsupported_Type, path)
        return
    }

    if !scalar || s.problem.error != .None {
        return
    }

    if field.width != 1 && field.width != 2 && field.width != 4 && field.width != 8 {
        fail(s, .Unsupported_Type, path)
        return
    }

    description := metadata_format(s, "%d/%d;", field.kind, field.width)
    append_text(s, description)
    delete(description, s.allocator)

    if !store {
        return
    }

    if hidden && s.options.projection == .Public {
        s.excluded_fields += 1
        return
    }

    if len(s.fields) >= s.options.max_fields || field.width > s.options.max_wire_bytes - s.wire_size {
        fail(s, .Limit, path)
        return
    }

    field.path = metadata_clone(s, path)

    if s.problem.error != .None {
        return
    }

    field.wire_offset = s.wire_size
    s.wire_size += field.width

    if !metadata_append(s, &s.fields, field) {
        return
    }
}

@(private)
enum_names :: proc(s: ^Schema, info: reflect.Type_Info_Enum) {
    append_text(s, "values{")

    for value, i in info.values {
        entry := metadata_format(s, "%d:%s=%d;", len(info.names[i]), info.names[i], i64(value))
        append_text(s, entry)
        delete(entry, s.allocator)
    }

    append_text(s, "}")
}

@(private)
array :: proc(
    s: ^Schema,
    elem: ^reflect.Type_Info,
    count, stride, offset: int,
    path: string,
    hidden: bool,
    depth: int,
    store: bool,
    guard: int,
) {
    if count > s.options.max_fields {
        fail(s, .Limit, path)
        return
    }

    wire_start, array_start := s.wire_size, len(s.arrays)
    text := metadata_format(s, "array:%d{", count)
    append_text(s, text)
    delete(text, s.allocator)

    if count == 0 {
        walk(s, elem, offset, path, hidden, depth + 1, false, guard)
    }

    for i in 0 ..< count {
        child_path := metadata_format(s, "%s[%d]", path, i)
        walk(s, elem, offset + i * stride, child_path, hidden, depth + 1, store, guard)
        delete(child_path, s.allocator)

        if s.problem.error != .None {
            return
        }
    }

    append_text(s, "}")
    bytes := s.wire_size - wire_start

    // Variant-specific arrays can overlap in a union's canonical storage.
    // Skip those; an enclosing fixed-width array of unions is still eligible.
    if guard < 0 && count >= 4 && bytes >= 256 && bytes % count == 0 && bytes / count > 1 {
        if error := resize(&s.arrays, array_start); error != .None {
            allocation_failed(s)
            return
        } // an eligible outer array replaces its children

        if !metadata_append(s, &s.arrays, Array_Span{wire_start, bytes / count, count}) {
            return
        }
    }
}
