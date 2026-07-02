package script_runtime

import "base:runtime"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "godot:gdext"
import gd "godot:godot"

// ----------------------------------------------------------------------------
// register_class — runtime-reflection registration (Phase 2 of the reflection
// migration). scriptgen no longer text-generates the Export/Onready tables; instead
// each generated `@(init)` calls `register_class(T, Class_Info{...})` and THIS file
// builds those tables by walking T's `base:runtime` type info (field offsets/sizes/
// types + the `gd:"..."` struct tags) at dlopen/startup.
//
// Class_Info carries only what reflection CANNOT see: the class/base names, lifecycle
// + method/signal/connection/rpc tables (trampolines are still codegen), and per-field
// metadata (source line, `///` doc, getter/setter proc pointers) keyed by field name.
// Class_Info NEVER crosses the core<->scripts dll boundary — only the Class_Desc built
// here does, so adding it does not touch the ABI contract (Registration_Error does
// cross, and is folded into ABI_VERSION in runtime.odin).
//
// Like `register`, everything here runs from `@(init)` — contextless, no allocator,
// no engine. Table entries and every string that must outlive the walk (field names,
// hint strings, defaults) are carved from fixed-size package-global pools below.
// Registration problems land in a static error table the CORE surfaces after boot
// (odin_scripts_registration_errors) — a bad export is dropped LOUDLY, never silently.
// ----------------------------------------------------------------------------

// Per-field metadata the type info cannot provide, keyed by field name. scriptgen
// emits one entry per @export field: the 1-based source line, the `///` doc comment,
// and — when the tag has `get=`/`set=` — the generated accessor wrapper proc pointers
// (reflection sees the get=/set= NAMES in the tag; the POINTERS must come from codegen).
Field_Meta :: struct {
	field:  cstring,
	line:   i32,
	doc:    cstring,
	getter: proc "c" (self: rawptr, ret: gdext.VariantPtr),
	setter: proc "c" (self: rawptr, value: gdext.VariantPtr),
}

// Everything reflection cannot see about a class. INTERNAL to the scripts dll (see
// the header comment); the C-shaped pointer+count pairs reference static arrays in
// the generated file, exactly like Class_Desc's.
Class_Info :: struct {
	name:              cstring,
	base:              cstring,
	lifecycle:         Lifecycle,
	methods:           [^]Method,
	methods_count:     i32,
	signals:           [^]Signal,
	signals_count:     i32,
	connections:       [^]Connection,
	connections_count: i32,
	rpcs:              [^]Rpc,
	rpcs_count:        i32,
	fields:            [^]Field_Meta,
	fields_count:      i32,
	tool:              bool,
	icon:              cstring,
	doc:               cstring,
}

// One registration problem. All three cstrings are static (literals or pool-carved),
// alive for the dll's lifetime; `field` is nil for a class-level problem. Crosses the
// dll boundary via odin_scripts_registration_errors.
Registration_Error :: struct {
	class: cstring,
	field: cstring,
	msg:   cstring,
}

// Called by each generated `@(init)` to publish a script class: walk T's fields into
// Export/Onready tables, merge Class_Info, and register the resulting Class_Desc.
register_class :: proc "contextless" ($T: typeid, info: Class_Info) {
	register(reflect_class_desc(T, info))
}

// The non-parametric walk (register_class minus the registry append) — also the unit
// test surface (tests/reflect_register). Contextless signature; internally installs
// the default context for the pure (never-allocating) core:strings/strconv/reflect
// helpers the tag parsing uses.
reflect_class_desc :: proc "contextless" (id: typeid, info: Class_Info) -> Class_Desc {
	context = runtime.default_context()
	desc := Class_Desc {
		name              = info.name,
		base              = info.base,
		id                = id,
		lifecycle         = info.lifecycle,
		methods           = info.methods,
		methods_count     = info.methods_count,
		signals           = info.signals,
		signals_count     = info.signals_count,
		connections       = info.connections,
		connections_count = info.connections_count,
		rpcs              = info.rpcs,
		rpcs_count        = info.rpcs_count,
		tool              = info.tool,
		icon              = info.icon,
		doc               = info.doc,
	}
	ti := type_info_of(id)
	desc.size = ti.size
	desc.align = ti.align
	st, is_struct := runtime.type_info_base(ti).variant.(runtime.Type_Info_Struct)
	if !is_struct {
		record_error(info.name, nil, "registered type is not a struct")
		return desc
	}
	// The pools are appended one class at a time (the `@(init)` chain is sequential),
	// so this class's entries form the contiguous run [start, count).
	exports_start := export_pool_count
	onready_start := onready_pool_count
	for i in 0 ..< int(st.field_count) {
		if i == 0 {continue} // the owner Object pointer, by convention — never a member
		tag, has := reflect.struct_tag_lookup(reflect.Struct_Tag(st.tags[i]), "gd")
		if !has {continue}
		walk_field(info, st.names[i], st.types[i], st.offsets[i], tag)
	}
	if n := export_pool_count - exports_start; n > 0 {
		desc.exports = raw_data(export_pool[exports_start:])
		desc.exports_count = i32(n)
	}
	if n := onready_pool_count - onready_start; n > 0 {
		desc.onready = raw_data(onready_pool[onready_start:])
		desc.onready_count = i32(n)
	}
	return desc
}

// One tagged field -> an Export or Onready pool entry (or a recorded error). Ports
// scriptgen's tag grammar verbatim: the first comma-separated token selects the kind
// (`export` / `onready=PATH`), the rest are group/subgroup/default/get/set plus at
// most one hint spec.
@(private = "file")
walk_field :: proc(info: Class_Info, fname: string, fti: ^runtime.Type_Info, offset: uintptr, tag: string) {
	cls := info.name
	name_c, name_ok := pool_cstr(fname)
	if !name_ok {
		record_error(cls, nil, "registration name pool exhausted — field dropped")
		return
	}

	rest := tag
	tok0 := rest
	if ci := strings.index_byte(rest, ','); ci >= 0 {
		tok0 = rest[:ci]
		rest = rest[ci + 1:]
	} else {
		rest = ""
	}
	tok0 = strings.trim_space(tok0)

	// `gd:"onready=PATH"` — a private auto-wired node ref, not an export.
	if strings.has_prefix(tok0, "onready=") {
		path := strings.trim_space(tok0[len("onready="):])
		if path == "" {
			record_error(cls, name_c, "`onready=` needs a node path")
			return
		}
		if vt, vok := variant_type_for(fti.id); !vok || vt != .Object {
			record_error(cls, name_c, "`onready` field must be an object/node handle or pointer")
			return
		}
		if onready_pool_count >= MAX_REFLECT_ONREADY {
			record_error(cls, name_c, "registration onready pool exhausted — field dropped")
			return
		}
		path_c, pok := pool_cstr(path)
		if !pok {
			record_error(cls, name_c, "registration name pool exhausted — field dropped")
			return
		}
		onready_pool[onready_pool_count] = Onready{offset = offset, path = path_c}
		onready_pool_count += 1
		return
	}

	if tok0 != "export" {
		msg, _ := pool_cstr("unknown gd tag `", tok0, "` (expected `export` or `onready=PATH`)")
		if msg == nil {msg = "unknown gd tag (expected `export` or `onready=PATH`)"}
		record_error(cls, name_c, msg)
		return
	}

	vt, vok := variant_type_for(fti.id)
	if !vok {
		record_error(cls, name_c, "export field of unsupported type")
		return
	}

	ex := Export {
		name        = name_c,
		type        = vt,
		offset      = offset,
		size        = fti.size,
		hint_string = "",
	}

	// Per-field codegen metadata: source line, doc, accessor wrapper proc pointers.
	meta: ^Field_Meta
	for i in 0 ..< int(info.fields_count) {
		m := &info.fields[i]
		if m.field != nil && string(m.field) == fname {
			meta = m
			break
		}
	}
	if meta != nil {
		ex.line = meta.line
		ex.doc = meta.doc
	}

	// Trailing tokens: at most one hint spec, plus optional group/subgroup/default/get/set.
	has_hint := false
	want_get, want_set := false, false
	for len(rest) > 0 {
		spec := rest
		if ci := strings.index_byte(rest, ','); ci >= 0 {
			spec = rest[:ci]
			rest = rest[ci + 1:]
		} else {
			rest = ""
		}
		spec = strings.trim_space(spec)
		if spec == "" {continue}
		sname := spec
		value := ""
		if eq := strings.index_byte(spec, '='); eq >= 0 {
			sname = strings.trim_space(spec[:eq])
			value = strings.trim_space(spec[eq + 1:])
		}
		switch sname {
		case "group":
			if g, gok := pool_cstr(value); gok {ex.group = g} else {
				record_error(cls, name_c, "registration name pool exhausted — group dropped")
			}
		case "subgroup":
			if g, gok := pool_cstr(value); gok {ex.subgroup = g} else {
				record_error(cls, name_c, "registration name pool exhausted — subgroup dropped")
			}
		case "default":
			num, str, dok := parse_default(cls, name_c, vt, value)
			if dok {
				ex.has_default = true
				ex.default_num = num
				ex.default_str = str
			}
		case "get":
			want_get = true
		case "set":
			want_set = true
		case:
			// Anything else is a hint spec (range/enum/multiline/file/resource/...).
			if has_hint {
				record_error(cls, name_c, "only one export hint allowed")
				continue
			}
			h, hs, hok := parse_hint_spec(cls, name_c, sname, value, vt)
			if hok {
				has_hint = true
				ex.hint = h
				ex.hint_string = hs
			}
		}
	}

	// Type-driven typed collections: a `Typed_Array(T)` / `Typed_Dictionary(K,V)` field
	// derives its export hint from the type itself — no `array=`/`dict=` tag needed
	// (mixing the two is a conflict, as in scriptgen).
	if matched, th, ths, tok := derive_typed_collection_hint(cls, name_c, fti); matched {
		if has_hint {
			record_error(cls, name_c, "typed collection already declares its element type(s) — remove the redundant hint spec")
		} else if tok {
			ex.hint = th
			ex.hint_string = ths
		}
	}

	// get=/set= route reads/writes through generated wrapper procs. The NAMES live in
	// the tag; the POINTERS only exist in the generated file's Field_Meta table — a
	// requested accessor with no wrapper must fail loudly, not fall back to raw access.
	if want_get {
		if meta != nil && meta.getter != nil {
			ex.getter = meta.getter
		} else {
			record_error(cls, name_c, "`get=` requested but no getter wrapper was provided in Class_Info.fields")
		}
	}
	if want_set {
		if meta != nil && meta.setter != nil {
			ex.setter = meta.setter
		} else {
			record_error(cls, name_c, "`set=` requested but no setter wrapper was provided in Class_Info.fields")
		}
	}

	if export_pool_count >= MAX_REFLECT_EXPORTS {
		record_error(cls, name_c, "registration export pool exhausted — field dropped")
		return
	}
	export_pool[export_pool_count] = ex
	export_pool_count += 1
}

// ---- Odin typeid -> Godot Variant type ----------------------------------------

// The reflection replacement for scriptgen's text-driven map_variant: which Variant a
// field of type `id` presents as. Same coverage — the scalar atoms (width-narrowed via
// Export.size), every math struct, the string family, misc handles, all ten packed
// arrays — with the handle rule expressed structurally: every Godot object/class handle
// is an alias of `rawptr` (Object) or a pointer (`^gd.Node2d`, resource handles =
// `^rawptr`), so `rawptr` + any pointer type map to .Object. ok=false means the type is
// not exportable (the caller records a registration error).
variant_type_for :: proc "contextless" (id: typeid) -> (gdext.Variant_Type, bool) {
	switch id {
	// ---- scalar atoms (narrowed to the field's real width via Export.size) ----
	case i8, i16, i32, i64, int, u8, u16, u32, u64, uint, uintptr:
		return .Int, true
	case f32, f64:
		return .Float, true
	case bool:
		return .Bool, true
	// ---- string family ----
	case string, gd.String:
		return .String, true
	case gd.String_Name:
		return .String_Name, true
	case gd.Node_Path:
		return .Node_Path, true
	// ---- math structs ----
	case gd.Vector2:
		return .Vector2, true
	case gd.Vector2i:
		return .Vector2i, true
	case gd.Rect2:
		return .Rect2, true
	case gd.Rect2i:
		return .Rect2i, true
	case gd.Vector3:
		return .Vector3, true
	case gd.Vector3i:
		return .Vector3i, true
	case gd.Transform2d:
		return .Transform2d, true
	case gd.Vector4:
		return .Vector4, true
	case gd.Vector4i:
		return .Vector4i, true
	case gd.Plane:
		return .Plane, true
	case gd.Quaternion:
		return .Quaternion, true
	case gd.Aabb:
		return .Aabb, true
	case gd.Basis:
		return .Basis, true
	case gd.Transform3d:
		return .Transform3d, true
	case gd.Projection:
		return .Projection, true
	case gd.Color:
		return .Color, true
	// ---- misc handles ----
	case gd.Rid:
		return .Rid, true
	case rawptr: // gd.Object and every non-refcounted class handle alias (gd.Node2d, ...)
		return .Object, true
	case gd.Callable:
		return .Callable, true
	case gd.Signal:
		return .Signal, true
	case gd.Dictionary:
		return .Dictionary, true
	case gd.Array:
		return .Array, true
	// ---- packed arrays ----
	case gd.Packed_Byte_Array:
		return .Packed_Byte_Array, true
	case gd.Packed_Int32_Array:
		return .Packed_Int32_Array, true
	case gd.Packed_Int64_Array:
		return .Packed_Int64_Array, true
	case gd.Packed_Float32_Array:
		return .Packed_Float32_Array, true
	case gd.Packed_Float64_Array:
		return .Packed_Float64_Array, true
	case gd.Packed_String_Array:
		return .Packed_String_Array, true
	case gd.Packed_Vector2_Array:
		return .Packed_Vector2_Array, true
	case gd.Packed_Vector3_Array:
		return .Packed_Vector3_Array, true
	case gd.Packed_Color_Array:
		return .Packed_Color_Array, true
	case gd.Packed_Vector4_Array:
		return .Packed_Vector4_Array, true
	}
	// Typed collections resolve to plain Array/Dictionary Variants (the element types
	// drive the export HINT, derived separately — see derive_typed_collection_hint).
	if kind, _, is_tc := typed_collection_params(id); is_tc {
		return kind, true
	}
	// Any pointer is an object handle: `^gd.Node2d`, refcounted/resource handles
	// (gd.Texture2d = Ref_Counted = ^rawptr), pointers to user resource structs.
	ti := runtime.type_info_base(type_info_of(id))
	if _, is_ptr := ti.variant.(runtime.Type_Info_Pointer); is_ptr {
		return .Object, true
	}
	return .Nil, false
}

// Detect a `Typed_Array(T)` / `Typed_Dictionary(K, V)` instantiation and return its
// type-parameter list. Parametric instantiations carry no structural record of their
// parameters, but their NAMED type info renders them canonically —
// "Typed_Array($T=i64)" / "Typed_Dictionary($K=String, $V=i64)" — so the parameters
// are recovered from that spelling ("i64" / "String, $V=i64", one trailing ')' cut).
@(private = "file")
typed_collection_params :: proc "contextless" (id: typeid) -> (kind: gdext.Variant_Type, params: string, ok: bool) {
	named, is_named := type_info_of(id).variant.(runtime.Type_Info_Named)
	if !is_named || len(named.name) == 0 || named.name[len(named.name) - 1] != ')' {
		return .Nil, "", false
	}
	n := named.name[:len(named.name) - 1]
	ARR :: "Typed_Array($T="
	DICT :: "Typed_Dictionary($K="
	if len(n) > len(ARR) && n[:len(ARR)] == ARR {
		return .Array, n[len(ARR):], true
	}
	if len(n) > len(DICT) && n[:len(DICT)] == DICT {
		return .Dictionary, n[len(DICT):], true
	}
	return .Nil, "", false
}

// The export hint for a typed-collection field type (`matched` is false when the field
// is not one). Elements must be BUILTIN Variant types: a class-handle element type is
// an alias of rawptr, so its class name is unrecoverable by reflection — that case is
// a registration error pointing at the equivalent `array=`/`dict=` tag form (which
// carries the class name in the tag and fully works).
@(private = "file")
derive_typed_collection_hint :: proc(cls, field: cstring, fti: ^runtime.Type_Info) -> (matched: bool, hint: i64, hint_string: cstring, ok: bool) {
	kind, params, is_tc := typed_collection_params(fti.id)
	if !is_tc {
		return false, 0, "", false
	}
	if kind == .Array {
		p, pok := encode_builtin_part(cls, field, params)
		if !pok {return true, 0, "", false}
		return true, HINT_TYPE_STRING, p, true
	}
	SEP :: ", $V="
	semi := strings.index(params, SEP)
	if semi < 0 {
		record_error(cls, field, "malformed typed dictionary type parameters")
		return true, 0, "", false
	}
	k, kok := encode_builtin_part(cls, field, params[:semi])
	v, vok := encode_builtin_part(cls, field, params[semi + len(SEP):])
	if !kok || !vok {return true, 0, "", false}
	hs, hok := pool_cstr(string(k), ";", string(v))
	if !hok {
		record_error(cls, field, "registration name pool exhausted — hint dropped")
		return true, 0, "", false
	}
	return true, HINT_TYPE_STRING, hs, true
}

// Encode one TYPE-DRIVEN element (a rendered Odin type spelling from the type-info
// name) as a PROPERTY_HINT_TYPE_STRING part: "<variant int>:". Non-distinct aliases
// render canonically (gd.Vector2 -> "[2]f32"), so both spellings are recognized.
@(private = "file")
encode_builtin_part :: proc(cls, field: cstring, t: string) -> (cstring, bool) {
	n := strings.trim_space(t)
	vt := builtin_variant_int_rendered(n)
	if vt < 0 {
		record_error(cls, field, "typed collection element must be a builtin Variant type — for a Resource class use the `array=`/`dict=` tag form (the class name is not recoverable by reflection)")
		return "", false
	}
	buf: [8]byte
	hs, hok := pool_cstr(strconv.write_int(buf[:], i64(vt), 10), ":")
	if !hok {
		record_error(cls, field, "registration name pool exhausted — hint dropped")
		return "", false
	}
	return hs, true
}

// Variant::Type integer for a RENDERED Odin type spelling (as it appears in a
// parametric type-info name). The [N]fXX rows are the canonical spellings of the
// non-distinct vector/basis/projection aliases; both Real widths are listed so a
// double-precision build (`-define:REAL_PRECISION=double`) resolves identically.
@(private = "file")
builtin_variant_int_rendered :: proc "contextless" (n: string) -> int {
	switch n {
	case "bool":
		return 1
	case "int", "i64", "i32", "i16", "i8", "u64", "u32", "u16", "u8", "uint", "uintptr":
		return 2
	case "f32", "f64":
		return 3
	case "string", "cstring", "String":
		return 4
	case "[2]f32", "[2]f64":
		return 5 // Vector2
	case "[2]i32":
		return 6 // Vector2i
	case "Rect2":
		return 7
	case "Rect2i":
		return 8
	case "[3]f32", "[3]f64":
		return 9 // Vector3
	case "[3]i32":
		return 10 // Vector3i
	case "Transform2d":
		return 11
	case "[4]f32", "[4]f64":
		return 12 // Vector4
	case "[4]i32":
		return 13 // Vector4i
	case "Plane":
		return 14
	case "quaternion128", "quaternion256":
		return 15 // Quaternion
	case "Aabb":
		return 16
	case "[3][3]f32", "[3][3]f64":
		return 17 // Basis
	case "Transform3d":
		return 18
	case "[4][4]f32", "[4][4]f64":
		return 19 // Projection
	case "Color":
		return 20
	case "String_Name":
		return 21
	case "Node_Path":
		return 22
	case "Rid":
		return 23
	}
	return -1
}

// ---- hint / default parsing (ported from scriptgen) ----------------------------

// `godot.Property_Hint` int values used by the struct-tag hint specs. Kept in sync
// with `godot/godot.gen.odin`'s `Property_Hint :: enum int`.
@(private = "file") HINT_RANGE :: 1
@(private = "file") HINT_ENUM :: 2
@(private = "file") HINT_FILE :: 13
@(private = "file") HINT_DIR :: 14
@(private = "file") HINT_GLOBAL_FILE :: 15
@(private = "file") HINT_GLOBAL_DIR :: 16
@(private = "file") HINT_RESOURCE_TYPE :: 17
@(private = "file") HINT_MULTILINE_TEXT :: 18
@(private = "file") HINT_TYPE_STRING :: 23 // typed Array/Dictionary element-type encoding

// Parse one `gd:"export,..."` hint spec (already split into name=value) into its
// (Property_Hint, hint_string). Values WITHIN a spec are colon-separated and rewritten
// to Godot's comma-joined hint_string form while being copied into the name pool:
//   range=MIN:MAX[:STEP] / enum=A:B:C / multiline / file[=...] / dir / global_file[=...]
//   / global_dir / resource=Class / array=ELEM / dict=KEY;VALUE
@(private = "file")
parse_hint_spec :: proc(cls, field: cstring, name, value: string, vt: gdext.Variant_Type) -> (hint: i64, hint_string: cstring, ok: bool) {
	// colon-separated list values -> Godot's comma-separated hint_string form.
	csv :: proc(cls, field: cstring, v: string) -> (cstring, bool) {
		c, cok := pool_cstr_csv(v)
		if !cok {
			record_error(cls, field, "registration name pool exhausted — hint dropped")
		}
		return c, cok
	}
	switch name {
	case "range":
		if value == "" {
			record_error(cls, field, "`range` hint needs MIN:MAX[:STEP]")
			return 0, "", false
		}
		hs, cok := csv(cls, field, value)
		return HINT_RANGE, hs, cok
	case "enum":
		if value == "" {
			record_error(cls, field, "`enum` hint needs A:B:C")
			return 0, "", false
		}
		hs, cok := csv(cls, field, value)
		return HINT_ENUM, hs, cok
	case "multiline":
		return HINT_MULTILINE_TEXT, "", true
	case "file":
		hs, cok := csv(cls, field, value)
		return HINT_FILE, hs, cok
	case "dir":
		hs, cok := csv(cls, field, value)
		return HINT_DIR, hs, cok
	case "global_file":
		hs, cok := csv(cls, field, value)
		return HINT_GLOBAL_FILE, hs, cok
	case "global_dir":
		hs, cok := csv(cls, field, value)
		return HINT_GLOBAL_DIR, hs, cok
	case "resource":
		if value == "" {
			record_error(cls, field, "`resource` hint needs a type name, e.g. resource=Texture2D")
			return 0, "", false
		}
		hs, cok := pool_cstr(value)
		if !cok {
			record_error(cls, field, "registration name pool exhausted — hint dropped")
			return 0, "", false
		}
		return HINT_RESOURCE_TYPE, hs, true
	case "array":
		// Typed Array export: `gd.Array `gd:"export,array=int"`` (or a Resource class).
		if vt != .Array {
			record_error(cls, field, "`array=` hint requires the field to be `gd.Array`")
			return 0, "", false
		}
		part, pok := encode_tag_part(cls, field, value)
		if !pok {return 0, "", false}
		return HINT_TYPE_STRING, part, true
	case "dict":
		// Typed Dictionary export: KEY and VALUE separated by `;` (Godot 4.4+).
		if vt != .Dictionary {
			record_error(cls, field, "`dict=` hint requires the field to be `gd.Dictionary`")
			return 0, "", false
		}
		semi := strings.index_byte(value, ';')
		if semi < 0 {
			record_error(cls, field, "`dict=` needs KEY;VALUE, e.g. dict=String;int")
			return 0, "", false
		}
		kpart, kok := encode_tag_part(cls, field, value[:semi])
		vpart, vok := encode_tag_part(cls, field, value[semi + 1:])
		if !kok || !vok {return 0, "", false}
		hs, hok := pool_cstr(string(kpart), ";", string(vpart))
		if !hok {
			record_error(cls, field, "registration name pool exhausted — hint dropped")
			return 0, "", false
		}
		return HINT_TYPE_STRING, hs, true
	case:
		msg, _ := pool_cstr("unknown export hint `", name, "`")
		if msg == nil {msg = "unknown export hint"}
		record_error(cls, field, msg)
		return 0, "", false
	}
}

// Encode ONE key/value/element from the `array=`/`dict=` TAG form for a typed
// Array/Dictionary hint_string (PROPERTY_HINT_TYPE_STRING). A builtin renders as
// "<variant int>:"; anything else is taken to be a Resource class (passed verbatim)
// and renders "24/17:ClassName" (24=TYPE_OBJECT, 17=HINT_RESOURCE_TYPE).
@(private = "file")
encode_tag_part :: proc(cls, field: cstring, t: string) -> (cstring, bool) {
	n := strings.trim_space(t)
	if i := strings.last_index_byte(n, '.'); i >= 0 {
		n = n[i + 1:] // strip a gd./godot. qualifier
	}
	if n == "" {
		record_error(cls, field, "typed Array/Dictionary export has an empty element type")
		return "", false
	}
	pool_fail :: proc(cls, field: cstring) -> (cstring, bool) {
		record_error(cls, field, "registration name pool exhausted — hint dropped")
		return "", false
	}
	if vt := builtin_variant_int_tag(n); vt >= 0 {
		buf: [8]byte
		hs, hok := pool_cstr(strconv.write_int(buf[:], i64(vt), 10), ":")
		if !hok {return pool_fail(cls, field)}
		return hs, true
	}
	hs, hok := pool_cstr("24/17:", n)
	if !hok {return pool_fail(cls, field)}
	return hs, true
}

// Variant::Type integer for a builtin type name in the `array=`/`dict=` TAG form
// (Godot or Odin spelling), or -1 when it's not a builtin (then it's treated as a
// Resource class). Ported verbatim from scriptgen's builtin_variant_int.
@(private = "file")
builtin_variant_int_tag :: proc "contextless" (n: string) -> int {
	switch n {
	case "bool", "Bool":
		return 1
	case "int", "Int", "i64", "i32", "i16", "i8", "u64", "u32", "u16", "u8":
		return 2
	case "float", "Float", "f64", "f32":
		return 3
	case "String", "string", "cstring":
		return 4
	case "Vector2":
		return 5
	case "Vector2i":
		return 6
	case "Rect2":
		return 7
	case "Rect2i":
		return 8
	case "Vector3":
		return 9
	case "Vector3i":
		return 10
	case "Transform2d", "Transform2D":
		return 11
	case "Vector4":
		return 12
	case "Vector4i":
		return 13
	case "Plane":
		return 14
	case "Quaternion":
		return 15
	case "Aabb", "AABB":
		return 16
	case "Basis":
		return 17
	case "Transform3d", "Transform3D":
		return 18
	case "Projection":
		return 19
	case "Color":
		return 20
	case "String_Name", "StringName":
		return 21
	case "Node_Path", "NodePath":
		return 22
	case "Rid", "RID":
		return 23
	}
	return -1
}

// Parse an `@export default=...` literal for a field presenting as Variant `vt`.
// Scalars only: Int/Float/Bool -> default_num (bool as 0/1); String -> default_str
// (quotes/backticks stripped, nil when empty — matching what scriptgen emitted).
@(private = "file")
parse_default :: proc(cls, field: cstring, vt: gdext.Variant_Type, value: string) -> (num: f64, str: cstring, ok: bool) {
	v := strings.trim_space(value)
	#partial switch vt {
	case .Int:
		n, pok := strconv.parse_i64(v)
		if !pok {
			record_error(cls, field, "bad integer default")
			return 0, nil, false
		}
		return f64(n), nil, true
	case .Float:
		f, pok := strconv.parse_f64(v)
		if !pok {
			record_error(cls, field, "bad float default")
			return 0, nil, false
		}
		return f, nil, true
	case .Bool:
		switch v {
		case "true":
			return 1, nil, true
		case "false":
			return 0, nil, true
		case:
			record_error(cls, field, "bool default must be true/false")
			return 0, nil, false
		}
	case .String:
		s := strings.trim(v, "\"`")
		if s == "" {
			return 0, nil, true // has_default with a nil default_str == empty string
		}
		sc, sok := pool_cstr(s)
		if !sok {
			record_error(cls, field, "registration name pool exhausted — default dropped")
			return 0, nil, false
		}
		return 0, sc, true
	}
	record_error(cls, field, "`default=` only supported for int/float/bool/String")
	return 0, nil, false
}

// ---- static pools + the error table --------------------------------------------
// Sized generously; all per-dll statics (a fresh dll — initial load or hot reload —
// starts empty). Exhaustion is a recorded registration error, never corruption.

@(private = "file") REFLECT_NAME_POOL_SIZE :: 64 * 1024
@(private = "file") MAX_REFLECT_EXPORTS :: 1024
@(private = "file") MAX_REFLECT_ONREADY :: 256
@(private = "file") MAX_REG_ERRORS :: 64

@(private = "file")
name_pool: [REFLECT_NAME_POOL_SIZE]byte
@(private = "file")
name_pool_used: int

@(private = "file")
export_pool: [MAX_REFLECT_EXPORTS]Export
@(private = "file")
export_pool_count: int

@(private = "file")
onready_pool: [MAX_REFLECT_ONREADY]Onready
@(private = "file")
onready_pool_count: int

@(private = "file")
reg_errors: [MAX_REG_ERRORS]Registration_Error
@(private = "file")
reg_error_count: int

// Concatenate `parts` into the name pool, NUL-terminated -> a static-lifetime cstring.
@(private = "file")
pool_cstr :: proc "contextless" (parts: ..string) -> (cstring, bool) {
	need := 1
	for p in parts {need += len(p)}
	if name_pool_used + need > REFLECT_NAME_POOL_SIZE {
		return nil, false
	}
	start := name_pool_used
	for p in parts {
		copy(name_pool[name_pool_used:], p)
		name_pool_used += len(p)
	}
	name_pool[name_pool_used] = 0
	name_pool_used += 1
	return cstring(&name_pool[start]), true
}

// pool_cstr + the hint-value rewrite: colon-separated spec values become Godot's
// comma-joined hint_string form during the copy.
@(private = "file")
pool_cstr_csv :: proc "contextless" (s: string) -> (cstring, bool) {
	c, ok := pool_cstr(s)
	if !ok {
		return nil, false
	}
	p := ([^]byte)(c)
	for i in 0 ..< len(s) {
		if p[i] == ':' {p[i] = ','}
	}
	return c, true
}

@(private = "file")
record_error :: proc "contextless" (class: cstring, field: cstring, msg: cstring) {
	if reg_error_count >= MAX_REG_ERRORS {
		return
	}
	reg_errors[reg_error_count] = Registration_Error{class = class, field = field, msg = msg}
	reg_error_count += 1
}

// Scripts-dll-side view of the error table (also the unit-test assertion surface).
registration_errors :: proc "contextless" () -> []Registration_Error {
	return reg_errors[:reg_error_count]
}

// TEST-ONLY: reset the walk's pools + error table so `odin test` cases (which share
// one process) can exercise exhaustion without poisoning later cases. Never called
// in production — a dll's pools live exactly as long as the dll.
reflect_register_reset_for_tests :: proc "contextless" () {
	name_pool_used = 0
	export_pool_count = 0
	onready_pool_count = 0
	reg_error_count = 0
}

// The core pulls this right after the manifest (dlsym'd by name on native, called
// directly on web) to surface registration problems via push_error once the engine
// is up. C-shaped: out-param count + returned pointer, like odin_scripts_manifest.
@(export)
odin_scripts_registration_errors :: proc "c" (out_count: ^i32) -> [^]Registration_Error {
	if out_count != nil {
		out_count^ = i32(reg_error_count)
	}
	return raw_data(reg_errors[:])
}
