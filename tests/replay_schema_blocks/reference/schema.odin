package schema_block_reference

import "core:fmt"
import "base:intrinsics"
import "core:mem"
import "core:reflect"
import "core:strings"

Projection :: enum u8 {Authority, Public}
Kind :: enum u8 {Unsigned, Signed, Float, Boolean, Enumeration, Bits, Union_Tag}
Error :: enum {
	None, Already_Initialized, Not_Ready, Invalid_Options, Unsupported_Type,
	Platform_Integer, Invalid_Tag, Limit, Wrong_Type, Wrong_Size, Invalid_Value,
	Invalid_Header, Schema_Mismatch, Context_Mismatch, Checksum_Mismatch,
}

Report :: struct {error: Error, path: string}

Options :: struct {
	projection: Projection,
	finite_floats: bool,
	max_wire_bytes: int,
	max_fields: int,
}

DEFAULT_OPTIONS :: Options{.Authority, true, 1024 * 1024, 65536}
FORMAT_VERSION :: 1

// Local compiled metadata. Offsets/endian flags do not enter the canonical
// fingerprint. Paths and enum definitions do. Never transmit this struct.
Field :: struct {
	path: string,
	offset: int,
	wire_offset: int,
	width: int,
	kind: Kind,
	big_endian: bool,
	enum_values: []reflect.Type_Info_Enum_Value, // compiler-owned metadata
	enum_names: []string, // compiler-owned; diagnostic names do not alter wire metadata
	bit_mask: u64,
	guard,union_index:int,
}

@(private)
Copy_Span :: struct {offset,wire_offset,size:int,reverse:bool}

// Single owner. init builds metadata from compiler type information; encode and
// decode allocate nothing. Destroy even a failed init to release diagnostics.
Schema :: struct {
	allocator: mem.Allocator,
	initialized, ready: bool,
	type: typeid,
	options: Options,
	fields: [dynamic]Field,
	checks: [dynamic]int,
	validation:[dynamic]Check,
	spans: [dynamic]Copy_Span,
	canonical: [dynamic]u8,
	wire_size: int,
	fingerprint: u64,
	unions:[dynamic]Union_Layout,
	guards:[dynamic]Union_Guard,
	excluded_fields: int,
	problem: Report,
}

init :: proc(s: ^Schema, t: typeid, options := DEFAULT_OPTIONS, allocator := context.allocator) -> Report {
	if s.initialized {return {error = .Already_Initialized}}
	if t == nil || options.projection > .Public || options.max_wire_bytes < 1 ||
	   options.max_wire_bytes > 1024 * 1024 || options.max_fields < 1 || options.max_fields > 65536 {
		return {error = .Invalid_Options}
	}
	s.allocator, s.initialized, s.type, s.options = allocator, true, t, options
	s.fields = make([dynamic]Field, 0, 16, allocator)
	s.canonical = make([dynamic]u8, 0, 256, allocator)
	s.unions=make([dynamic]Union_Layout,0,0,allocator)
	s.guards=make([dynamic]Union_Guard,0,0,allocator)
	context.allocator = allocator
	header := fmt.aprintf("replay-schema:%d;projection:%d;finite:%d;", FORMAT_VERSION, options.projection, int(options.finite_floats))
	defer delete(header, allocator)
	append_text(s, header)
	walk(s, type_info_of(t), 0, "$", false, 0, true,-1)
	if s.problem.error != .None {return s.problem}
	s.fingerprint = digest(s.canonical[:])
	compile_copy_program(s)
	compile_validation(s)
	s.ready = true
	return {}
}

destroy :: proc(s: ^Schema) {
	for field in s.fields {delete(field.path, s.allocator)}
	delete(s.fields)
	delete(s.checks)
	delete(s.validation)
	delete(s.spans)
	for layout in s.unions {delete(layout.variant_sizes,s.allocator);for name in layout.variant_names {delete(name,s.allocator)};delete(layout.variant_names,s.allocator)}
	delete(s.unions);delete(s.guards)
	delete(s.canonical)
	delete(s.problem.path, s.allocator)
	s^ = {}
}

// Merge only truly adjacent bytes in both layouts. Padding and omitted private
// fields split spans, and endian-qualified scalars keep individual reversal.
@(private)
compile_copy_program :: proc(s:^Schema) {
	s.checks=make([dynamic]int,0,min(len(s.fields),64),s.allocator)
	s.spans=make([dynamic]Copy_Span,0,min(len(s.fields),64),s.allocator)
	for field,i in s.fields {
		if field.kind!=.Unsigned && field.kind!=.Signed && !(field.kind==.Float && !s.options.finite_floats) {append(&s.checks,i)}
		if len(s.unions)>0 {continue}
		reverse:=field.big_endian && field.width>1
		if !reverse && len(s.spans)>0 {
			last:=&s.spans[len(s.spans)-1]
			if !last.reverse && last.offset+last.size==field.offset && last.wire_offset+last.size==field.wire_offset {
				last.size+=field.width;continue
			}
		}
		append(&s.spans,Copy_Span{field.offset,field.wire_offset,field.width,reverse})
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
			for b in bytes[i:i + 8] {h = (h ~ u64(b)) * 0x100000001b3}
		}
		i += 8
	}
	for b in bytes[i:] {h = (h ~ u64(b)) * 0x100000001b3}
	return h
}

@(private)
fail :: proc(s: ^Schema, error: Error, path: string) {
	if s.problem.error != .None {return}
	s.problem = {error, strings.clone(path, s.allocator)}
}

@(private)
append_text :: proc(s: ^Schema, value: string) {
	if s.problem.error != .None {return}
	if len(value) > 4 * 1024 * 1024 - len(s.canonical) {fail(s, .Limit, "$schema"); return}
	append(&s.canonical, ..transmute([]u8)value)
}

@(private)
mask_for :: proc(width: int) -> u64 {
	return width == 8 ? max(u64) : (u64(1) << uint(width * 8)) - 1
}

@(private)
walk :: proc(s: ^Schema, info: ^reflect.Type_Info, offset: int, path: string,
             hidden: bool, depth: int, store: bool,guard:int) {
	if s.problem.error != .None {return}
	if info == nil || depth > 64 || len(path) > 4096 {fail(s, .Limit, path); return}
	// Inspect every distinct/alias layer: stripping directly to core type would
	// let a distinct int/uintptr silently become a portable-looking integer.
	base := info
	for {
		if base.id == int || base.id == uint || base.id == uintptr {
			fail(s, .Platform_Integer, path); return
		}
		if named, ok := base.variant.(reflect.Type_Info_Named); ok {base = named.base} else {break}
	}
	field := Field{offset = offset, width = base.size, big_endian = ODIN_ENDIAN == .Big,guard=guard,union_index=-1}
	scalar := true
	#partial switch value in base.variant {
	case reflect.Type_Info_Integer:
		field.kind = value.signed ? .Signed : .Unsigned
		if value.endianness != .Platform {field.big_endian = value.endianness == .Big}
	case reflect.Type_Info_Rune:
		field.kind = .Signed
	case reflect.Type_Info_Float:
		field.kind = .Float
		if value.endianness != .Platform {field.big_endian = value.endianness == .Big}
		if base.size != 2 && base.size != 4 && base.size != 8 {fail(s, .Unsupported_Type, path); return}
	case reflect.Type_Info_Boolean:
		field.kind = .Boolean
		if base.size != 1 {fail(s, .Unsupported_Type, path); return}
	case reflect.Type_Info_Enum:
		field.kind = .Enumeration
		field.enum_values = value.values
		field.enum_names = value.names
		integer := reflect.type_info_base(value.base)
		if integer.id == int || integer.id == uint || integer.id == uintptr {
			fail(s, .Platform_Integer, path); return
		}
		if kind, ok := integer.variant.(reflect.Type_Info_Integer); ok {
			if kind.endianness != .Platform {field.big_endian = kind.endianness == .Big}
			definition := fmt.aprintf("enum:%d:%d{", int(kind.signed), integer.size)
			append_text(s, definition)
			delete(definition, s.allocator)
			for val, i in value.values {
				entry := fmt.aprintf("%d:%s=%d;", len(value.names[i]), value.names[i], i64(val))
				append_text(s, entry)
				delete(entry, s.allocator)
			}
			append_text(s, "}")
		} else {fail(s, .Unsupported_Type, path); return}
	case reflect.Type_Info_Bit_Set:
		field.kind = .Bits
		if value.upper < value.lower || u64(value.upper) - u64(value.lower) >= 64 || base.size > 8 {
			fail(s, .Unsupported_Type, path); return
		}
		if value.underlying != nil {
			if integer, ok := reflect.type_info_base(value.underlying).variant.(reflect.Type_Info_Integer); ok {
				if integer.endianness != .Platform {field.big_endian = integer.endianness == .Big}
			}
		}
		enum_info: reflect.Type_Info_Enum
		has_enum := false
		if value.elem != nil {enum_info, has_enum = reflect.type_info_base(value.elem).variant.(reflect.Type_Info_Enum)}
		if has_enum {
			enum_names(s, enum_info)
			for bit in enum_info.values {
				if i64(bit) >= value.lower && i64(bit) <= value.upper {
					field.bit_mask |= u64(1) << uint(i64(bit) - value.lower)
				}
			}
		} else {
			for bit in u64(0) ..= u64(value.upper) - u64(value.lower) {field.bit_mask |= u64(1) << uint(bit)}
		}
		definition := fmt.aprintf("bits:%d:%d:%d;", value.lower, value.upper, field.bit_mask)
		append_text(s, definition)
		delete(definition, s.allocator)
	case reflect.Type_Info_Union:
		union_layout(s,base,value,offset,path,hidden,depth,store,guard);return
	case reflect.Type_Info_Struct:
		scalar = false
		if value.soa_kind != .None || .raw_union in value.flags {fail(s, .Unsupported_Type, path); return}
		append_text(s, "struct{")
		for child, i in value.types[:value.field_count] {
			child_path := fmt.aprintf("%s.%s", path, value.names[i])
			private := hidden
			if tag, tagged := reflect.struct_tag_lookup(reflect.Struct_Tag(value.tags[i]), "replay"); tagged {
				if tag != "authority" {fail(s, .Invalid_Tag, child_path)} else {private = true}
			}
			name := fmt.aprintf("%d:%s=%d:", len(value.names[i]), value.names[i], int(private))
			append_text(s, name)
			delete(name, s.allocator)
			walk(s, child, offset + int(value.offsets[i]), child_path, private, depth + 1, store,guard)
			delete(child_path, s.allocator)
			if s.problem.error != .None {return}
		}
		append_text(s, "}")
	case reflect.Type_Info_Array:
		scalar = false
		array(s, value.elem, value.count, value.elem_size, offset, path, hidden, depth, store,guard)
	case reflect.Type_Info_Enumerated_Array:
		scalar = false
		// Record the index's meaning as well as its storage count.
		append_text(s, "index{")
		if enum_info, ok := reflect.type_info_base(value.index).variant.(reflect.Type_Info_Enum); ok {
			enum_names(s, enum_info)
		} else {fail(s, .Unsupported_Type, path); return}
		index := fmt.aprintf("range:%d:%d:sparse:%d;", i64(value.min_value), i64(value.max_value), int(value.is_sparse))
		append_text(s, index)
		delete(index, s.allocator)
		append_text(s, "}")
		array(s, value.elem, value.count, value.elem_size, offset, path, hidden, depth, store,guard)
	case:
		fail(s, .Unsupported_Type, path); return
	}
	if !scalar || s.problem.error != .None {return}
	if field.width != 1 && field.width != 2 && field.width != 4 && field.width != 8 {
		fail(s, .Unsupported_Type, path); return
	}
	description := fmt.aprintf("%d/%d;", field.kind, field.width)
	append_text(s, description)
	delete(description, s.allocator)
	if !store {return}
	if hidden && s.options.projection == .Public {s.excluded_fields += 1; return}
	if len(s.fields) >= s.options.max_fields || field.width > s.options.max_wire_bytes - s.wire_size {
		fail(s, .Limit, path); return
	}
	field.path = strings.clone(path, s.allocator)
	field.wire_offset = s.wire_size
	s.wire_size += field.width
	append(&s.fields, field)
}

@(private)
enum_names :: proc(s: ^Schema, info: reflect.Type_Info_Enum) {
	append_text(s, "values{")
	for value, i in info.values {
		entry := fmt.aprintf("%d:%s=%d;", len(info.names[i]), info.names[i], i64(value))
		append_text(s, entry)
		delete(entry, s.allocator)
	}
	append_text(s, "}")
}

@(private)
array :: proc(s: ^Schema, elem: ^reflect.Type_Info, count, stride, offset: int,
              path: string, hidden: bool, depth: int, store: bool,guard:int) {
	if count > s.options.max_fields {fail(s, .Limit, path); return}
	text := fmt.aprintf("array:%d{", count)
	append_text(s, text)
	delete(text, s.allocator)
	if count == 0 {walk(s, elem, offset, path, hidden, depth + 1, false,guard)}
	for i in 0 ..< count {
		child_path := fmt.aprintf("%s[%d]", path, i)
		walk(s, elem, offset + i * stride, child_path, hidden, depth + 1, store,guard)
		delete(child_path, s.allocator)
		if s.problem.error != .None {return}
	}
	append_text(s, "}")
}
