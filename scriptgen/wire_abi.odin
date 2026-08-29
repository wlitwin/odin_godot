package scriptgen

// Recursive canonical wire ABI.
//
// The runtime's raw lanes intentionally stay memcpy-simple. That makes the
// generator the right place to prove that every byte has one target-independent
// meaning: fixed-width leaves only, bounded fixed arrays only, explicit enum
// bases, no address-bearing types, and no implicit struct padding. The result is
// both validation and data: one canonical, sorted schema string which is emitted
// into the guard file and mixed into NET_FINGERPRINT.

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

WIRE_ABI_VERSION :: 1
WIRE_FIELD_MAX_BYTES :: 65535
WIRE_INPUT_MAX_BYTES :: 256
WIRE_PROFILE_MAX_BYTES :: 256
WIRE_APP_MESSAGE_MAX_BYTES :: 256 * 1024
WIRE_ACTION_DEFAULT_MAX_BYTES :: 4096

Wire_Layout :: struct {
	size:    int,
	align:   int,
	kind:    string,
	integer: bool,
	ok:      bool,
}

Wire_Span :: struct {
	first: int,
	count: int,
}

Wire_Type_Meta :: struct {
	path:   string,
	kind:   string,
	width:  int,
	align:  int,
	detail: string,
}

Wire_Field_Meta :: struct {
	path, entity, name, lane, encoding: string,
	struct_width, wire_width, bound:    int,
	types:                              Wire_Span,
}

Wire_Entity_Meta :: struct {
	name:      string,
	wire_id:   int,
	stream_hz: int,
	avatar:    bool,
}

Wire_Constraint_Meta :: struct {
	field, range, mask:       string,
	finite, unit, enum_check: bool,
}

Wire_Input_Meta :: struct {
	path, type_name, encoding: string,
	class_id, width, bound:    int,
	types, constraints:        Wire_Span,
}

Wire_Argument_Meta :: struct {
	owner, name, kind, target: string,
	width, bound:              int,
	variable:                  bool,
}

Wire_Action_Outcome_Meta :: struct {
	owner, name, type_name: string,
}

Wire_Action_Meta :: struct {
	path, entity, name, access, prediction, schedule: string,
	id, max_args:                                     int,
	args, outcomes:                                   Wire_Span,
	consequence:                                      string,
	takes_game:                                       bool,
}

Wire_Fact_Meta :: struct {
	path, entity, name, anchor, source: string,
	id:                                 int,
	args:                               Wire_Span,
}

Wire_Profile_Meta :: struct {
	path, type_name, encoding: string,
	width, bound:              int,
	types:                     Wire_Span,
}

Wire_Message_Meta :: struct {
	path, entity, name, payload_type: string,
	tag:                              int,
	tag_name, encoding:               string,
	width, bound:                     int,
	types:                            Wire_Span,
}

Wire_ABI_Metadata :: struct {
	canonical:   string,
	entities:    [dynamic]Wire_Entity_Meta,
	types:       [dynamic]Wire_Type_Meta,
	fields:      [dynamic]Wire_Field_Meta,
	inputs:      [dynamic]Wire_Input_Meta,
	constraints: [dynamic]Wire_Constraint_Meta,
	actions:     [dynamic]Wire_Action_Meta,
	outcomes:    [dynamic]Wire_Action_Outcome_Meta,
	facts:       [dynamic]Wire_Fact_Meta,
	arguments:   [dynamic]Wire_Argument_Meta,
	profiles:    [dynamic]Wire_Profile_Meta,
	messages:    [dynamic]Wire_Message_Meta,
}

Wire_Walk :: struct {
	b:      strings.Builder,
	active: map[string]bool,
	types:  ^[dynamic]Wire_Type_Meta,
}

Wire_Input_Root :: struct {
	type_name:   string,
	class_id:    int,
	ctx:         Struct_Def,
	loc:         Loc,
	constraints: []Input_Field_Constraint,
}

// Strip insignificant whitespace from small declaration expressions (enum
// values and Action_Policy literals). Quoted strings are preserved byte-for-byte.
wire_compact_expr :: proc(src: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	quote: u8
	escaped := false
	for c in transmute([]u8)src {
		if quote != 0 {
			strings.write_byte(&b, c)
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == quote {
				quote = 0
			}
			continue
		}
		if c == '"' || c == '`' || c == '\'' {
			quote = c
			strings.write_byte(&b, c)
			continue
		}
		if c == ' ' || c == '\t' || c == '\r' || c == '\n' {continue}
		strings.write_byte(&b, c)
	}
	return strings.to_string(b)
}

wire_integer_literal_expr :: proc(src: string) -> bool {
	t := wire_compact_expr(src)
	if t == "" {return false}
	i := 0
	if t[0] == '+' || t[0] == '-' {i = 1}
	if i >= len(t) || t[i] < '0' || t[i] > '9' {return false}
	for c in t[i + 1:] {
		if (c >= '0' && c <= '9') ||
		   (c >= 'a' && c <= 'f') ||
		   (c >= 'A' && c <= 'F') ||
		   c == 'x' ||
		   c == 'X' ||
		   c == 'b' ||
		   c == 'B' ||
		   c == 'o' ||
		   c == 'O' ||
		   c == 'd' ||
		   c == 'D' ||
		   c == 'z' ||
		   c == 'Z' ||
		   c == '_' {
			continue
		}
		return false
	}
	return true
}

// Resolve the typed action policy into schema data. Arbitrary computed policy
// expressions are refused: peers must fingerprint the actual access/prediction/
// byte-ceiling values, not merely the identifier used to obtain them.
wire_policy_field :: proc(compact, name: string) -> (string, bool) {
	needle := strings.concatenate({name, "="}, context.temp_allocator)
	at := strings.index(compact, needle)
	if at < 0 {return "", false}
	start := at + len(needle)
	end := start
	for end < len(compact) && compact[end] != ',' && compact[end] != '}' {end += 1}
	if end == start {return "", false}
	return compact[start:end], true
}

wire_policy_shape :: proc(
	expr: string,
) -> (
	access: string,
	predict: bool,
	max_args: int,
	ok: bool,
) {
	t := wire_compact_expr(expr)
	access = "owner"
	max_args = WIRE_ACTION_DEFAULT_MAX_BYTES
	switch {
	case strings.has_suffix(t, "ACTION_OWNER"):
		return access, false, max_args, true
	case strings.has_suffix(t, "ACTION_OWNER_PREDICTED"):
		return access, true, max_args, true
	case strings.has_suffix(t, "ACTION_ANY_SEAT"):
		return "any-seat", false, max_args, true
	case strings.has_suffix(t, "ACTION_ANY_SEAT_PREDICTED"):
		return "any-seat", true, max_args, true
	case strings.has_suffix(t, "ACTION_AUTHORITY"):
		return "authority", false, max_args, true
	}
	if !strings.contains(t, "Action_Policy{") || !strings.has_suffix(t, "}") {
		return "", false, 0, false
	}
	if value, has := wire_policy_field(t, "access"); has {
		switch {
		case strings.has_suffix(value, ".Any_Seat"):
			access = "any-seat"
		case strings.has_suffix(value, ".Authority"):
			access = "authority"
		case strings.has_suffix(value, ".Owner"):
			access = "owner"
		case:
			return "", false, 0, false
		}
	}
	if value, has := wire_policy_field(t, "prediction"); has {
		switch {
		case strings.has_suffix(value, ".Optimistic"):
			predict = true
		case strings.has_suffix(value, ".None"):
			predict = false
		case:
			return "", false, 0, false
		}
	}
	if value, has := wire_policy_field(t, "max_args_bytes"); has {
		n, nok := strconv.parse_int(value)
		if !nok || n < 0 || n > WIRE_FIELD_MAX_BYTES {return "", false, 0, false}
		if n != 0 {max_args = n}
	}
	if access == "authority" && predict {return "", false, 0, false}
	return access, predict, max_args, true
}

wire_root_context :: proc(s: ^Script) -> Struct_Def {
	return Struct_Def{dir = dir_of(s.path), imports = s.imports}
}

wire_named_lookup :: proc(from: Struct_Def, type_text: string) -> (Wire_Named_Def, bool) {
	t := strings.trim_space(type_text)
	if dot := strings.index_byte(t, '.'); dot >= 0 {
		alias, name := t[:dot], t[dot + 1:]
		if alias == "gd" || alias == "godot" {return {}, false}
		imp, has := from.imports[alias]
		if !has {return {}, false}
		dir, dok := resolve_index_import_dir(from.dir, imp)
		if !dok {return {}, false}
		index_pkg_dir(dir)
		if defs, has_defs := g_wire_named[dir]; has_defs {
			if def, has_def := defs[name]; has_def {return def, true}
		}
		return {}, false
	}
	index_pkg_dir(from.dir)
	if defs, has_defs := g_wire_named[from.dir]; has_defs {
		if def, has_def := defs[t]; has_def {return def, true}
	}
	return {}, false
}

wire_struct_lookup :: proc(from: Struct_Def, type_text: string) -> (Struct_Def, bool) {
	t := strings.trim_space(type_text)
	if dot := strings.index_byte(t, '.'); dot >= 0 {
		alias, name := t[:dot], t[dot + 1:]
		if alias == "gd" || alias == "godot" {return {}, false}
		imp, has := from.imports[alias]
		if !has {return {}, false}
		dir, dok := resolve_index_import_dir(from.dir, imp)
		if !dok {return {}, false}
		index_pkg_dir(dir)
		if defs, has_defs := g_pkgs[dir]; has_defs {
			if def, has_def := defs[name]; has_def {return def, true}
		}
		return {}, false
	}
	index_pkg_dir(from.dir)
	if defs, has_defs := g_pkgs[from.dir]; has_defs {
		if def, has_def := defs[t]; has_def {return def, true}
	}
	return {}, false
}

wire_resolve_type :: proc(
	from: Struct_Def,
	type_text: string,
) -> (
	Struct_Def,
	map[string]string,
	bool,
) {
	t := strings.trim_space(type_text)
	if t == "" || t[0] == '^' || strings.has_prefix(t, "[") {return {}, nil, false}
	if paren := strings.index_byte(t, '('); paren >= 0 {
		if !strings.has_suffix(t, ")") {return {}, nil, false}
		def, ok := wire_struct_lookup(from, strings.trim_space(t[:paren]))
		if !ok {return {}, nil, false}
		args := split_type_params(t[paren + 1:len(t) - 1])
		defer delete(args)
		subst := make(map[string]string)
		for p, i in def.poly_params {
			if i < len(args) {subst[p] = strings.trim_space(args[i])}
		}
		return def, subst, true
	}
	def, ok := wire_struct_lookup(from, t)
	return def, nil, ok
}

wire_align_up :: proc(n, a: int) -> int {
	if a <= 1 {return n}
	return (n + a - 1) / a * a
}

wire_fixed_array :: proc(t: string) -> (count: int, elem: string, ok: bool) {
	if !strings.has_prefix(t, "[") {return}
	rb := strings.index_byte(t, ']')
	if rb <= 1 || rb == len(t) - 1 {return}
	n, nok := strconv.parse_int(strings.trim_space(t[1:rb]))
	if !nok || n <= 0 {return}
	return n, strings.trim_space(t[rb + 1:]), true
}

wire_primitive :: proc(t: string) -> Wire_Layout {
	switch t {
	case "i8":
		return Wire_Layout{1, 1, "i8", true, true}
	case "u8", "byte":
		return Wire_Layout{1, 1, "u8", true, true}
	case "i16":
		return Wire_Layout{2, 2, "i16", true, true}
	case "u16":
		return Wire_Layout{2, 2, "u16", true, true}
	case "i32", "rune":
		return Wire_Layout{4, 4, "i32", true, true}
	case "u32":
		return Wire_Layout{4, 4, "u32", true, true}
	case "i64":
		return Wire_Layout{8, 8, "i64", true, true}
	case "u64":
		return Wire_Layout{8, 8, "u64", true, true}
	case "f16":
		return Wire_Layout{2, 2, "f16", false, true}
	case "f32":
		return Wire_Layout{4, 4, "f32", false, true}
	case "f64":
		return Wire_Layout{8, 8, "f64", false, true}
	case "bool":
		return Wire_Layout{1, 1, "bool", false, true}
	}
	return {}
}

// Godot's value types are legal raw fields only under the stock single-precision
// ABI. Generated size/alignment assertions make a REAL_PRECISION=double build
// fail at compile time instead of retaining this fingerprint with different bytes.
wire_godot_value :: proc(t: string) -> Wire_Layout {
	base := t
	if strings.has_prefix(base, "gd.") {base = base[3:]}
	if strings.has_prefix(base, "godot.") {base = base[6:]}
	switch base {
	case "Bool":
		return Wire_Layout{1, 1, "bool", false, true}
	case "Int":
		return Wire_Layout{8, 8, "i64", true, true}
	case "Float":
		return Wire_Layout{8, 8, "f64", false, true}
	case "Vector2":
		return Wire_Layout{8, 4, "vector2<f32>", false, true}
	case "Vector3":
		return Wire_Layout{12, 4, "vector3<f32>", false, true}
	case "Vector4":
		return Wire_Layout{16, 4, "vector4<f32>", false, true}
	case "Vector2i":
		return Wire_Layout{8, 4, "vector2<i32>", false, true}
	case "Vector3i":
		return Wire_Layout{12, 4, "vector3<i32>", false, true}
	case "Vector4i":
		return Wire_Layout{16, 4, "vector4<i32>", false, true}
	case "Rect2":
		return Wire_Layout{16, 4, "rect2<f32>", false, true}
	case "Rect2i":
		return Wire_Layout{16, 4, "rect2<i32>", false, true}
	case "Transform2d":
		return Wire_Layout{24, 4, "transform2<f32>", false, true}
	case "Plane":
		return Wire_Layout{16, 4, "plane<f32>", false, true}
	case "Quaternion":
		return Wire_Layout{16, 4, "quaternion<f32>", false, true}
	case "Aabb":
		return Wire_Layout{24, 4, "aabb<f32>", false, true}
	case "Basis":
		return Wire_Layout{36, 4, "basis<f32>", false, true}
	case "Transform3d":
		return Wire_Layout{48, 4, "transform3<f32>", false, true}
	case "Projection":
		return Wire_Layout{64, 4, "projection<f32>", false, true}
	case "Color":
		return Wire_Layout{16, 4, "color<f32>", false, true}
	}
	return {}
}

wire_emit_type :: proc(w: ^Wire_Walk, path: string, layout: Wire_Layout, extra := "") {
	append(
		w.types,
		Wire_Type_Meta {
			path = path,
			kind = layout.kind,
			width = layout.size,
			align = layout.align,
			detail = strings.trim_space(extra),
		},
	)
	fmt.sbprintf(
		&w.b,
		"type %s kind=%s width=%d align=%d%s\n",
		path,
		layout.kind,
		layout.size,
		layout.align,
		extra,
	)
}

wire_type_layout :: proc(
	w: ^Wire_Walk,
	from: Struct_Def,
	type_text, path: string,
	loc: Loc,
) -> Wire_Layout {
	t := strings.trim_space(type_text)
	if t == "" {
		error_at(loc, "%s: empty type in a network declaration", path)
		return {}
	}
	if p := wire_primitive(t); p.ok {
		wire_emit_type(w, path, p)
		return p
	}
	if g := wire_godot_value(t); g.ok {
		wire_emit_type(w, path, g)
		return g
	}
	if t == "int" ||
	   t == "uint" ||
	   t == "uintptr" ||
	   t == "rawptr" ||
	   t == "cstring" ||
	   t == "gd.Real" ||
	   t == "godot.Real" ||
	   t == "Real" {
		error_at(
			loc,
			"%s: %q has a platform/build-dependent wire width — use a fixed-width integer/float; Godot Real values must be stored as f32 or f64 explicitly",
			path,
			t,
		)
		return {}
	}
	if strings.has_prefix(t, "^") ||
	   strings.has_prefix(t, "[^]") ||
	   strings.has_prefix(t, "[]") ||
	   strings.has_prefix(t, "[dynamic]") ||
	   strings.has_prefix(t, "[dynamic:") ||
	   strings.has_prefix(t, "map[") ||
	   strings.has_prefix(t, "matrix[") ||
	   t == "string" ||
	   strings.has_prefix(t, "proc(") ||
	   strings.has_prefix(t, "union {") {
		error_at(
			loc,
			"%s: unsupported wire type %q — pointers, strings, slices, dynamic/fixed-capacity arrays, maps, matrices, unions, and procedures do not have a bounded canonical raw representation",
			path,
			t,
		)
		return {}
	}
	if count, elem, is_array := wire_fixed_array(t); is_array {
		child_path := strings.concatenate({path, "[]"}, context.temp_allocator)
		child := wire_type_layout(w, from, elem, child_path, loc)
		if !child.ok {return {}}
		if child.size > 0 && count > WIRE_APP_MESSAGE_MAX_BYTES / child.size {
			error_at(
				loc,
				"%s: fixed array [%d]%s exceeds the protocol-wide byte ceiling",
				path,
				count,
				elem,
			)
			return {}
		}
		layout := Wire_Layout {
			size  = count * child.size,
			align = child.align,
			kind  = "array",
			ok    = true,
		}
		wire_emit_type(w, path, layout, fmt.tprintf(" count=%d elem=%s", count, child.kind))
		return layout
	}
	if strings.has_prefix(t, "[") {
		error_at(
			loc,
			"%s: fixed-array bound in %q is not a positive integer literal — wire container bounds must be explicit and canonical",
			path,
			t,
		)
		return {}
	}

	if def, subst, is_struct := wire_resolve_type(from, t); is_struct {
		key := strings.concatenate({def.id, "|", t}, context.temp_allocator)
		if w.active[key] {
			error_at(loc, "%s: recursive value type %q has no finite wire representation", path, t)
			return {}
		}
		if def.custom_align {
			error_at(
				def.loc,
				"%s: %s uses an explicit struct alignment directive — raw network structs must derive a target-independent layout from fixed-width fields",
				path,
				def.name,
			)
			return {}
		}
		w.active[key] = true
		defer delete_key(&w.active, key)
		offset, max_align := 0, 1
		for f in def.fields {
			ft := apply_subst(f.type_text, subst)
			fp := strings.concatenate({path, ".", f.name}, context.temp_allocator)
			child := wire_type_layout(w, def, ft, fp, f.loc)
			if !child.ok {return {}}
			if !def.packed {
				aligned := wire_align_up(offset, child.align)
				if aligned != offset {
					error_at(
						f.loc,
						"%s: raw wire struct %s inserts %d implicit padding byte(s) before %s — reorder fields, add explicit reserved bytes, or declare `struct #packed`; hidden padding is not protocol data",
						path,
						def.name,
						aligned - offset,
						f.name,
					)
					return {}
				}
				offset = aligned
			}
			offset += child.size
			max_align = max(max_align, child.align)
		}
		if len(def.fields) == 0 {
			error_at(def.loc, "%s: empty struct %s has no wire bytes", path, def.name)
			return {}
		}
		align := def.packed ? 1 : max_align
		final_size := def.packed ? offset : wire_align_up(offset, align)
		if final_size != offset {
			error_at(
				def.loc,
				"%s: raw wire struct %s has %d implicit tail-padding byte(s) — add explicit reserved bytes or declare `struct #packed`; hidden padding is not protocol data",
				path,
				def.name,
				final_size - offset,
			)
			return {}
		}
		layout := Wire_Layout {
			size  = final_size,
			align = align,
			kind  = "struct",
			ok    = true,
		}
		wire_emit_type(
			w,
			path,
			layout,
			fmt.tprintf(" packed=%v fields=%d", def.packed, len(def.fields)),
		)
		return layout
	}

	if def, is_named := wire_named_lookup(from, t); is_named {
		key := def.id
		if w.active[key] {
			error_at(
				loc,
				"%s: named type cycle through %s has no finite wire representation",
				path,
				def.name,
			)
			return {}
		}
		w.active[key] = true
		defer delete_key(&w.active, key)
		if def.kind == .Enum && def.underlying == "" {
			error_at(
				def.loc,
				"%s: enum %s has implicit platform-width storage — declare `enum u8`, `enum i16`, or another fixed-width integer base",
				path,
				def.name,
			)
			return {}
		}
		ctx := Struct_Def {
			dir     = def.dir,
			imports = def.imports,
		}
		under := wire_type_layout(
			w,
			ctx,
			def.underlying,
			strings.concatenate({path, "::<base>"}, context.temp_allocator),
			def.loc,
		)
		if !under.ok {return {}}
		if def.kind == .Enum && !under.integer {
			error_at(
				def.loc,
				"%s: enum %s base %q is not a fixed-width integer",
				path,
				def.name,
				def.underlying,
			)
			return {}
		}
		kind := def.kind == .Enum ? "enum" : (def.kind == .Distinct ? "distinct" : under.kind)
		layout := under
		layout.kind = kind
		if def.kind == .Enum {
			mb := strings.builder_make(context.temp_allocator)
			for m, i in def.members {
				if m.value != "" && !wire_integer_literal_expr(m.value) {
					error_at(
						def.loc,
						"%s: enum %s member %s uses computed value %q — network enum assignments must be integer literals so their actual representation is canonical",
						path,
						def.name,
						m.name,
						m.value,
					)
					return {}
				}
				if i > 0 {strings.write_byte(&mb, ',')}
				fmt.sbprintf(&mb, "%s=%s", m.name, m.value == "" ? fmt.tprintf("#%d", i) : m.value)
			}
			wire_emit_type(
				w,
				path,
				layout,
				fmt.tprintf(" base=%s values=%s", under.kind, strings.to_string(mb)),
			)
		} else if def.kind == .Distinct {
			wire_emit_type(w, path, layout, fmt.tprintf(" base=%s", under.kind))
		}
		return layout
	}

	error_at(
		loc,
		"%s: unresolved or unsupported wire type %q — every named type in a network declaration must resolve recursively to fixed-width fields",
		path,
		t,
	)
	return {}
}

wire_type_schema :: proc(
	from: Struct_Def,
	type_text, path: string,
	loc: Loc,
) -> (
	Wire_Layout,
	string,
	[]Wire_Type_Meta,
) {
	types := make([dynamic]Wire_Type_Meta, context.temp_allocator)
	w := Wire_Walk {
		active = make(map[string]bool),
		types  = &types,
	}
	strings.builder_init(&w.b, context.temp_allocator)
	layout := wire_type_layout(&w, from, type_text, path, loc)
	return layout, strings.to_string(w.b), types[:]
}

wire_command_arg_shape :: proc(
	wire: string,
) -> (
	kind: string,
	width: int,
	variable: bool,
	ok: bool,
) {
	switch wire {
	case "i8", "u8", "bool":
		return wire, 1, false, true
	case "i16", "u16":
		return wire, 2, false, true
	case "i32", "u32", "f32", "net_id":
		return wire, 4, false, true
	case "i64", "u64", "f64", "player_id":
		return wire, 8, false, true
	case "string":
		return "utf8", 0, true, true
	}
	return "", 0, false, false
}

wire_codec_size :: proc(dir, name: string) -> (int, bool) {
	index_pkg_dir(dir)
	if codecs, has := g_wire_codec_sizes[dir]; has {
		if n, ok := codecs[name]; ok {return n, true}
	}
	return 0, false
}

// Resolve the byte value behind a typed-message tag. Hashing only the constant
// NAME would miss `TAG_CHAT :: u8(4)` changing to u8(5), which changes routing
// while leaving every payload shape intact. Keep the accepted constant surface
// deliberately small and canonical: byte literals, u8(literal), or aliases of
// either form.
wire_u8_constant :: proc(from: Struct_Def, expr: string, active: ^map[string]bool) -> (int, bool) {
	t := wire_compact_expr(expr)
	if n, ok := strconv.parse_int(t); ok && n >= 0 && n <= 255 {
		return n, true
	}
	if strings.has_prefix(t, "u8(") && strings.has_suffix(t, ")") {
		if n, ok := strconv.parse_int(t[3:len(t) - 1]); ok && n >= 0 && n <= 255 {
			return n, true
		}
		return 0, false
	}
	def, ok := wire_named_lookup(from, t)
	if !ok || def.kind != .Alias || active^[def.id] {return 0, false}
	active^[def.id] = true
	defer delete_key(active, def.id)
	return wire_u8_constant(
		Struct_Def{dir = def.dir, imports = def.imports},
		def.underlying,
		active,
	)
}

// Validate all kit wire roots, attach their expected ABI sizes for generated
// compile-time assertions, and return the one structured model used to emit
// both NET_SCHEMA_CANONICAL and the public package-level NET_SCHEMA.
canonical_wire_abi :: proc(scripts: []^Script, scripts_dir: string) -> Wire_ABI_Metadata {
	meta: Wire_ABI_Metadata
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "wire-abi v=%d endian=little\n", WIRE_ABI_VERSION)

	sorted := make([dynamic]^Script, 0, len(scripts), context.temp_allocator)
	append(&sorted, ..scripts)
	slice.sort_by(sorted[:], proc(a, b: ^Script) -> bool {return a.struct_name < b.struct_name})

	// The entity census includes every class that owns wire behavior, plus every
	// stable factory kind declared by `entity=Name:id`. A hand-wired descriptor
	// legitimately has wire_id 0; generated factory ids are always nonzero.
	for s in sorted {
		if len(s.replicates) == 0 &&
		   len(s.commands) == 0 &&
		   s.tick.proc_name == "" &&
		   len(s.facts) == 0 {
			continue
		}
		append(&meta.entities, Wire_Entity_Meta{name = s.struct_name})
	}
	for s in sorted {
		for e in s.entities {
			found := false
			for &entity in meta.entities {
				if entity.name != e.target {continue}
				entity.wire_id = e.type_id
				entity.stream_hz = e.stream_hz
				entity.avatar = e.avatar
				found = true
				break
			}
			if !found {
				append(
					&meta.entities,
					Wire_Entity_Meta {
						name = e.target,
						wire_id = e.type_id,
						stream_hz = e.stream_hz,
						avatar = e.avatar,
					},
				)
			}
		}
	}
	slice.sort_by(meta.entities[:], proc(a, b: Wire_Entity_Meta) -> bool {return a.name < b.name})

	// A tick input is a wire root even when the game wires its lane manually and
	// has no generated lane-owner input table. Collect from tick declarations so
	// an absent @(gd_sample)/@(gd_step) cannot bypass recursive validation.
	input_roots := make([dynamic]Wire_Input_Root, context.temp_allocator)
	for s in sorted {
		if s.tick.input_type == "" {continue}
		seen := false
		for root in input_roots {
			if root.type_name == s.tick.input_type {seen = true; break}
		}
		if seen {continue}
		append(
			&input_roots,
			Wire_Input_Root {
				type_name = s.tick.input_type,
				class_id = s.tick.input_class,
				ctx = wire_root_context(s),
				loc = Loc{path = s.path, line = s.tick.line},
			},
		)
	}
	slice.sort_by(input_roots[:], proc(a, b: Wire_Input_Root) -> bool {
		return a.type_name < b.type_name
	})
	for &root in input_roots {
		constraints_found := false
		for s in sorted {
			for &ic in s.input_classes {
				if ic.type_name != root.type_name {continue}
				root.constraints = ic.constraints
				constraints_found = true
				break
			}
			if constraints_found {break}
		}
		if !constraints_found {
			index_pkg_dir(root.ctx.dir)
			if pkg, has_pkg := g_pkgs[root.ctx.dir]; has_pkg {
				if def, has_def := pkg[root.type_name]; has_def && def.input_decl {
					root.constraints = parse_input_constraints(def)
				}
			}
		}

		path := strings.concatenate({"input.", root.type_name}, context.temp_allocator)
		layout, detail, types := wire_type_schema(root.ctx, root.type_name, path, root.loc)
		if !layout.ok {continue}
		if layout.size > WIRE_INPUT_MAX_BYTES {
			error_at(
				root.loc,
				"%s: input is %d bytes; inputs cap at %d bytes",
				path,
				layout.size,
				WIRE_INPUT_MAX_BYTES,
			)
			continue
		}
		for s in sorted {
			if s.tick.input_type == root.type_name {
				s.tick.input_abi_size = layout.size
				s.tick.input_abi_align = layout.align
			}
			for &ic in s.input_classes {
				if ic.type_name == root.type_name {
					ic.abi_size, ic.abi_align = layout.size, layout.align
				}
			}
		}
		fmt.sbprintf(
			&b,
			"input %s class=%d encoding=raw width=%d bound=%d\n",
			path,
			root.class_id,
			layout.size,
			WIRE_INPUT_MAX_BYTES,
		)
		strings.write_string(&b, detail)
		type_span := Wire_Span {
			first = len(meta.types),
			count = len(types),
		}
		append(&meta.types, ..types)
		constraint_span := Wire_Span {
			first = len(meta.constraints),
		}
		for rule in root.constraints {
			range :=
				rule.range_min == "" ? "" : fmt.tprintf("%s:%s", wire_compact_expr(rule.range_min), wire_compact_expr(rule.range_max))
			fmt.sbprintf(
				&b,
				"constraint %s.%s range=%s mask=%s finite=%v unit=%v enum=%v\n",
				path,
				rule.field,
				range == "" ? "none" : range,
				rule.mask == "" ? "none" : wire_compact_expr(rule.mask),
				rule.finite,
				rule.unit,
				rule.enum_check,
			)
			append(
				&meta.constraints,
				Wire_Constraint_Meta {
					field = rule.field,
					range = range,
					mask = rule.mask == "" ? "" : wire_compact_expr(rule.mask),
					finite = rule.finite,
					unit = rule.unit,
					enum_check = rule.enum_check,
				},
			)
		}
		constraint_span.count = len(meta.constraints) - constraint_span.first
		append(
			&meta.inputs,
			Wire_Input_Meta {
				path = path,
				type_name = root.type_name,
				encoding = "raw",
				class_id = root.class_id,
				width = layout.size,
				bound = WIRE_INPUT_MAX_BYTES,
				types = type_span,
				constraints = constraint_span,
			},
		)
	}

	for s in sorted {
		ctx := wire_root_context(s)
		struct_total, wire_total := 0, 0
		for &r in s.replicates {
			lane := r.owner ? "owner" : (r.predict ? "predict" : "delta")
			path := fmt.tprintf("entity.%s.%s", s.struct_name, join_path(r.path))
			rctx := Struct_Def {
				dir     = r.type_dir,
				imports = r.type_imports,
			}
			layout, detail, types := wire_type_schema(rctx, r.type_text, path, r.loc)
			if !layout.ok {continue}
			r.abi_size, r.abi_align = layout.size, layout.align
			encoding := "raw"
			r.wire_size = layout.size
			if r.wire == ".F16" {
				encoding = "f16"
				r.wire_size = layout.size / 2
			} else if r.wire == ".Custom" {
				encoding = strings.concatenate({"custom:", r.codec}, context.temp_allocator)
				if n, ok := wire_codec_size(dir_of(s.path), r.codec); ok {
					r.wire_size = n
				} else {
					error_at(
						r.loc,
						"%s: custom wire codec %q must be a package-level knet.Wire_Codec literal with a positive integer `size` so its width can enter the canonical schema",
						path,
						r.codec,
					)
					continue
				}
			}
			if layout.size > WIRE_FIELD_MAX_BYTES || r.wire_size > WIRE_FIELD_MAX_BYTES {
				error_at(
					r.loc,
					"%s: field is %d struct bytes / %d wire bytes; each side must fit the %d-byte field ceiling",
					path,
					layout.size,
					r.wire_size,
					WIRE_FIELD_MAX_BYTES,
				)
				continue
			}
			fmt.sbprintf(
				&b,
				"field %s lane=%s encoding=%s struct-width=%d wire-width=%d bound=%d\n",
				path,
				lane,
				encoding,
				layout.size,
				r.wire_size,
				WIRE_FIELD_MAX_BYTES,
			)
			strings.write_string(&b, detail)
			type_span := Wire_Span {
				first = len(meta.types),
				count = len(types),
			}
			append(&meta.types, ..types)
			append(
				&meta.fields,
				Wire_Field_Meta {
					path = path,
					entity = s.struct_name,
					name = join_path(r.path),
					lane = lane,
					encoding = encoding,
					struct_width = layout.size,
					wire_width = r.wire_size,
					bound = WIRE_FIELD_MAX_BYTES,
					types = type_span,
				},
			)
			struct_total += layout.size
			wire_total += r.wire_size
		}
		if struct_total > WIRE_FIELD_MAX_BYTES || wire_total > WIRE_FIELD_MAX_BYTES {
			error_at(
				Loc{path = s.path},
				"entity.%s: replicated fields total %d struct bytes / %d wire bytes; both must fit %d",
				s.struct_name,
				struct_total,
				wire_total,
				WIRE_FIELD_MAX_BYTES,
			)
		}

		if s.tick.fx_mine {
			fact_path := fmt.tprintf("entity.%s.%s", s.struct_name, s.tick.proc_name)
			arg_span := Wire_Span {
				first = len(meta.arguments),
			}
			fmt.sbprintf(
				&b,
				"cue entity.%s.%s id=0 schedule=watch anchor=self source=tick\n",
				s.struct_name,
				s.tick.proc_name,
			)
			for wire, i in s.tick.payload_wires {
				kind, width, variable, ok := wire_command_arg_shape(wire)
				if !ok {continue}
				arg_name := fmt.tprintf("fact%d", i)
				if variable {
					fmt.sbprintf(
						&b,
						"cue-arg entity.%s.%s.fact%d kind=%s width=variable bound=%d\n",
						s.struct_name,
						s.tick.proc_name,
						i,
						kind,
						WIRE_FIELD_MAX_BYTES,
					)
				} else {
					fmt.sbprintf(
						&b,
						"cue-arg entity.%s.%s.fact%d kind=%s width=%d bound=1\n",
						s.struct_name,
						s.tick.proc_name,
						i,
						kind,
						width,
					)
				}
				append(
					&meta.arguments,
					Wire_Argument_Meta {
						owner = fact_path,
						name = arg_name,
						kind = kind,
						width = width,
						bound = variable ? WIRE_FIELD_MAX_BYTES : 1,
						variable = variable,
					},
				)
			}
			arg_span.count = len(meta.arguments) - arg_span.first
			append(
				&meta.facts,
				Wire_Fact_Meta {
					path = fact_path,
					entity = s.struct_name,
					name = s.tick.proc_name,
					id = 0,
					anchor = s.struct_name,
					source = "tick",
					args = arg_span,
				},
			)
		}

		cmds := make([dynamic]^Command_Info, context.temp_allocator)
		for &c in s.commands {append(&cmds, &c)}
		slice.sort_by(cmds[:], proc(a, b: ^Command_Info) -> bool {return a.name < b.name})
		for c in cmds {
			schedule := (s.tick.proc_name != "" || len(s.block_ticks) > 0) ? "tick" : "immediate"
			action_path := fmt.tprintf("entity.%s.%s", s.struct_name, c.name)
			arg_span := Wire_Span {
				first = len(meta.arguments),
			}
			fmt.sbprintf(
				&b,
				"action entity.%s.%s id=%d access=%s prediction=%s schedule=%s args-bound=%d\n",
				s.struct_name,
				c.name,
				cmd_wire_id(c.name),
				c.policy_access,
				c.policy_predict ? "optimistic" : "none",
				schedule,
				c.policy_max_args,
			)
			min_bytes := 0
			for a, i in c.args {
				kind, width, variable, ok := wire_command_arg_shape(a.wire)
				if !ok {continue} 	// build_command_info already reported this
				if variable {
					fmt.sbprintf(
						&b,
						"arg entity.%s.%s.%s index=%d kind=%s width=variable bound=%d\n",
						s.struct_name,
						c.name,
						a.name,
						i,
						kind,
						min(WIRE_FIELD_MAX_BYTES, c.policy_max_args),
					)
					min_bytes += 2 // u16 string length prefix
				} else {
					fmt.sbprintf(
						&b,
						"arg entity.%s.%s.%s index=%d kind=%s width=%d bound=1\n",
						s.struct_name,
						c.name,
						a.name,
						i,
						kind,
						width,
					)
					min_bytes += width
				}
				append(
					&meta.arguments,
					Wire_Argument_Meta {
						owner = action_path,
						name = a.name,
						kind = kind,
						width = width,
						bound = variable ? min(WIRE_FIELD_MAX_BYTES, c.policy_max_args) : 1,
						variable = variable,
					},
				)
			}
			if min_bytes > c.policy_max_args {
				error_at(
					c.loc,
					"action entity.%s.%s needs at least %d encoded argument bytes but its policy caps args at %d",
					s.struct_name,
					c.name,
					min_bytes,
					c.policy_max_args,
				)
			}
			arg_span.count = len(meta.arguments) - arg_span.first
			outcome_span := Wire_Span{first = len(meta.outcomes)}
			for outcome in c.outcomes {
				append(
					&meta.outcomes,
					Wire_Action_Outcome_Meta {
						owner = action_path,
						name = outcome.name,
						type_name = outcome.type_text,
					},
				)
			}
			outcome_span.count = len(meta.outcomes) - outcome_span.first
			append(
				&meta.actions,
				Wire_Action_Meta {
					path = action_path,
					entity = s.struct_name,
					name = c.name,
					access = c.policy_access,
					prediction = c.policy_predict ? "optimistic" : "none",
					schedule = schedule,
					id = int(cmd_wire_id(c.name)),
					max_args = c.policy_max_args,
					args = arg_span,
					outcomes = outcome_span,
					consequence = c.then_proc,
					takes_game = c.then_game != "",
				},
			)
		}

		if s.profile_type != "" {
			path := strings.concatenate({"profile.", s.profile_type}, context.temp_allocator)
			layout, detail, types := wire_type_schema(
				ctx,
				s.profile_type,
				path,
				Loc{path = s.path},
			)
			if layout.ok {
				s.profile_abi_size, s.profile_abi_align = layout.size, layout.align
				if layout.size > WIRE_PROFILE_MAX_BYTES {
					error_at(
						Loc{path = s.path},
						"%s: profile is %d bytes; profile rows cap at %d bytes",
						path,
						layout.size,
						WIRE_PROFILE_MAX_BYTES,
					)
				} else {
					fmt.sbprintf(
						&b,
						"profile %s encoding=raw width=%d bound=%d\n",
						path,
						layout.size,
						WIRE_PROFILE_MAX_BYTES,
					)
					strings.write_string(&b, detail)
					type_span := Wire_Span {
						first = len(meta.types),
						count = len(types),
					}
					append(&meta.types, ..types)
					append(
						&meta.profiles,
						Wire_Profile_Meta {
							path = path,
							type_name = s.profile_type,
							encoding = "raw",
							width = layout.size,
							bound = WIRE_PROFILE_MAX_BYTES,
							types = type_span,
						},
					)
				}
			}
		}

		for &m in s.messages {
			path := fmt.tprintf("message.%s.%s", s.struct_name, m.name)
			layout, detail, types := wire_type_schema(
				ctx,
				m.payload_type,
				path,
				Loc{m.path, m.line},
			)
			if !layout.ok {continue}
			m.abi_size, m.abi_align = layout.size, layout.align
			tag_active := make(map[string]bool)
			tag, tag_ok := wire_u8_constant(ctx, m.tag_ident, &tag_active)
			if !tag_ok {
				error_at(
					Loc{m.path, m.line},
					"%s: message tag %q must resolve to a package-level byte literal such as `TAG_MESSAGE :: u8(4)` so its actual route enters NET_SCHEMA_CANONICAL",
					path,
					m.tag_ident,
				)
				continue
			}
			if layout.size > WIRE_APP_MESSAGE_MAX_BYTES {
				error_at(
					Loc{m.path, m.line},
					"%s: typed payload is %d bytes; app messages cap at %d bytes",
					path,
					layout.size,
					WIRE_APP_MESSAGE_MAX_BYTES,
				)
				continue
			}
			fmt.sbprintf(
				&b,
				"message %s tag=%d tag-name=%s encoding=raw width=%d bound=%d\n",
				path,
				tag,
				wire_compact_expr(m.tag_ident),
				layout.size,
				WIRE_APP_MESSAGE_MAX_BYTES,
			)
			strings.write_string(&b, detail)
			type_span := Wire_Span {
				first = len(meta.types),
				count = len(types),
			}
			append(&meta.types, ..types)
			append(
				&meta.messages,
				Wire_Message_Meta {
					path = path,
					entity = s.struct_name,
					name = m.name,
					payload_type = m.payload_type,
					tag = tag,
					tag_name = wire_compact_expr(m.tag_ident),
					encoding = "raw",
					width = layout.size,
					bound = WIRE_APP_MESSAGE_MAX_BYTES,
					types = type_span,
				},
			)
		}

		for f in s.facts {
			fact_path := fmt.tprintf("entity.%s.%s", s.struct_name, f.name)
			arg_span := Wire_Span {
				first = len(meta.arguments),
			}
			fmt.sbprintf(
				&b,
				"cue entity.%s.%s id=%d schedule=watch anchor=%s\n",
				s.struct_name,
				f.name,
				cmd_wire_id(f.name),
				f.anchor == "" ? "none" : f.anchor,
			)
			for entity_type, i in f.entity_types {
				if i == f.anchor_index {continue}
				fmt.sbprintf(
					&b,
					"cue-arg entity.%s.%s.ref%d kind=net_id width=4 bound=1 target=%s\n",
					s.struct_name,
					f.name,
					i,
					entity_type,
				)
				append(
					&meta.arguments,
					Wire_Argument_Meta {
						owner = fact_path,
						name = f.entity_names[i],
						kind = "net_id",
						target = entity_type,
						width = 4,
						bound = 1,
					},
				)
			}
			for wire, i in f.arg_wires {
				kind, width, variable, ok := wire_command_arg_shape(wire)
				if !ok {continue}
				if variable {
					fmt.sbprintf(
						&b,
						"cue-arg entity.%s.%s.%s kind=%s width=variable bound=%d\n",
						s.struct_name,
						f.name,
						f.arg_names[i],
						kind,
						WIRE_FIELD_MAX_BYTES,
					)
				} else {
					fmt.sbprintf(
						&b,
						"cue-arg entity.%s.%s.%s kind=%s width=%d bound=1\n",
						s.struct_name,
						f.name,
						f.arg_names[i],
						kind,
						width,
					)
				}
				append(
					&meta.arguments,
					Wire_Argument_Meta {
						owner = fact_path,
						name = f.arg_names[i],
						kind = kind,
						width = width,
						bound = variable ? WIRE_FIELD_MAX_BYTES : 1,
						variable = variable,
					},
				)
			}
			arg_span.count = len(meta.arguments) - arg_span.first
			append(
				&meta.facts,
				Wire_Fact_Meta {
					path = fact_path,
					entity = s.struct_name,
					name = f.name,
					id = int(cmd_wire_id(f.name)),
					anchor = f.anchor,
					source = "declared",
					args = arg_span,
				},
			)
		}
	}
	meta.canonical = strings.to_string(b)
	return meta
}
