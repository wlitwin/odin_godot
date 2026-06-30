package scriptgen

// ----------------------------------------------------------------------------
// scriptgen — the Phase 3.5 codegen preprocessor for odin_godot.
//
// Authors write a CLEAN `.odin` script (struct-tag exports, plain typed lifecycle
// /method procs, `//gd:` markers). For each such file `scriptgen` emits a sibling
// `<name>.gen.odin` (same package) containing the verbose Phase-3 registration
// boilerplate that those scripts otherwise hand-write: the uniform Variant
// trampolines, the `@(private="file")` backing arrays, the signal-emit helpers, and
// the `@(init) rt.register(Class_Desc{...})`. The generated output is byte-for-byte
// EQUIVALENT in effect to the hand-written Phase-3 showcase scripts.
//
// SINGLE-FILE AUTHORING: the authored `.odin` is the file the user attaches to a node
// (the loader reads its `//gd:class` marker to bind it to the compiled class). scriptgen
// emits ONLY the `<name>.gen.odin` build artifact beside the source; there is no separate
// resource stub. The `.gen.odin` is named so the loader ignores it as an attachable script.
//
// Parsing is done PROPERLY with `core:odin/parser` + `core:odin/ast` (the struct,
// its fields/tags, the procs + their typed signatures). The `//gd:` comment markers
// (extends/class/tool/signal) — which Phases 1-3 already recognize — are scanned
// from the source text, exactly as the core's ResourceLoader does.
//
// Usage:
//   scriptgen <scripts_dir>
//     - emits <name>.gen.odin next to each script in <scripts_dir>
//   (a legacy `-res:<dir>` flag is accepted but ignored — stubs are no longer emitted.)
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strconv"
import "core:strings"

// ---- Odin type -> Godot Variant mapping --------------------------------------

Variant_Kind :: enum {
	Int, // narrowable integers (i8..i64, uint, Int)
	Float, // f32 / f64
	Bool,
	Other, // engine-native width (String, Object, Vector2, ...)
	Nil, // void
}

Variant_Info :: struct {
	enum_name: string, // e.g. ".Int" — the gdext.Variant_Type member
	native:    string, // native Odin type behind the Variant (for signal-emit temps)
	kind:      Variant_Kind,
}

// Map a rendered Odin type string -> the Variant it presents as. `ok=false` means
// the type is unsupported (the caller emits a clear codegen error).
//
// Coverage is the FULL gdext.Variant_Type set: the scalar atoms (Bool/Int/Float, with
// width-narrowing via `size` for the .Int/.Float/.Bool kinds), every math struct
// (Vector*/Rect*/Transform*/Plane/Quaternion/Aabb/Basis/Projection/Color), the string
// family (String/String_Name/Node_Path), the misc handles (Rid/Object/Callable/Signal/
// Dictionary/Array) and all ten Packed_*_Array types. For these whole-struct/handle
// kinds the field IS the binding type, so `size = size_of(field)` and the core does no
// narrowing — it hands the field straight to the cached Variant<->type constructors.
map_variant :: proc(type_text: string) -> (Variant_Info, bool) {
	t := strings.trim_space(type_text)
	// Any pointer-to-object (`^gd.Node2d`, `^gd.Object`, ...) is a Variant Object.
	if strings.has_prefix(t, "^") {
		return Variant_Info{".Object", "rawptr", .Other}, true
	}
	base := t
	if i := strings.last_index(base, "."); i >= 0 {
		base = base[i + 1:] // strip a `gd.` / `godot.` qualifier
	}
	// A whole-struct/handle Variant: enum member ".X", native binding type "gd.X".
	other :: proc(name: string) -> (Variant_Info, bool) {
		return Variant_Info{strings.concatenate({".", name}), strings.concatenate({"gd.", name}), .Other}, true
	}
	switch base {
	// ---- scalar atoms (narrowed to the field's real width via `size`) ----
	case "int", "i64", "i32", "i16", "i8", "u64", "u32", "u16", "u8", "uint", "uintptr", "Int":
		return Variant_Info{".Int", "i64", .Int}, true
	case "f32", "f64", "Float", "Real":
		return Variant_Info{".Float", "f64", .Float}, true
	case "bool", "Bool":
		return Variant_Info{".Bool", "bool", .Bool}, true
	// ---- string family ----
	case "String", "string":
		return Variant_Info{".String", "gd.String", .Other}, true
	case "String_Name":
		return other("String_Name")
	case "Node_Path":
		return other("Node_Path")
	// ---- math structs ----
	case "Vector2":
		return other("Vector2")
	case "Vector2i":
		return other("Vector2i")
	case "Rect2":
		return other("Rect2")
	case "Rect2i":
		return other("Rect2i")
	case "Vector3":
		return other("Vector3")
	case "Vector3i":
		return other("Vector3i")
	case "Transform2d":
		return other("Transform2d")
	case "Vector4":
		return other("Vector4")
	case "Vector4i":
		return other("Vector4i")
	case "Plane":
		return other("Plane")
	case "Quaternion":
		return other("Quaternion")
	case "Aabb":
		return other("Aabb")
	case "Basis":
		return other("Basis")
	case "Transform3d":
		return other("Transform3d")
	case "Projection":
		return other("Projection")
	case "Color":
		return other("Color")
	// ---- misc handles ----
	case "Rid":
		return other("Rid")
	case "Object":
		return Variant_Info{".Object", "gd.Object", .Other}, true
	case "Callable":
		return other("Callable")
	case "Signal":
		return other("Signal")
	case "Dictionary":
		return other("Dictionary")
	case "Array":
		return other("Array")
	// ---- packed arrays ----
	case "Packed_Byte_Array":
		return other("Packed_Byte_Array")
	case "Packed_Int32_Array":
		return other("Packed_Int32_Array")
	case "Packed_Int64_Array":
		return other("Packed_Int64_Array")
	case "Packed_Float32_Array":
		return other("Packed_Float32_Array")
	case "Packed_Float64_Array":
		return other("Packed_Float64_Array")
	case "Packed_String_Array":
		return other("Packed_String_Array")
	case "Packed_Vector2_Array":
		return other("Packed_Vector2_Array")
	case "Packed_Vector3_Array":
		return other("Packed_Vector3_Array")
	case "Packed_Color_Array":
		return other("Packed_Color_Array")
	case "Packed_Vector4_Array":
		return other("Packed_Vector4_Array")
	case:
		// Any other QUALIFIED `gd.<Pascal>` selector is a godot Object/class handle
		// (Node2d, Sprite2D, Texture2D, ...) — these are all ObjectPtr aliases, so they
		// marshal as a Variant Object. An UNQUALIFIED or non-PascalCase token (a typo, an
		// `[N]T`, a `map`, ...) is NOT silently an Object — the caller errors on ok=false.
		if strings.contains(t, ".") && len(base) > 0 && base[0] >= 'A' && base[0] <= 'Z' {
			return Variant_Info{".Object", "rawptr", .Other}, true
		}
	}
	return {}, false
}

LIFECYCLE_KEYWORDS := [?]string{"physics_process", "process", "ready", "enter_tree", "exit_tree", "reload"}

// ---- parsed model ------------------------------------------------------------

Export_Info :: struct {
	name:        string,
	type_text:   string,
	vi:          Variant_Info,
	hint:        int, // godot.Property_Hint int value (0 == None)
	hint_string: string, // companion string for the hint (Godot conventions)
	// richer-authoring #2: group/subgroup header this field starts (""=none).
	group:       string,
	subgroup:    string,
	// richer-authoring #3: parsed `default=...` literal. `default_num` carries Int/Float/Bool
	// (bool as 0/1); `default_str` carries String. Emitted into the rt.Export literal.
	has_default: bool,
	default_num: f64,
	default_str: string,
	// richer-authoring #4: author proc names from `get=`/`set=` (""=plain field access).
	getter:      string,
	setter:      string,
}

// richer-authoring #1: an `@onready` auto-wired node ref — a struct field of object-handle
// type tagged `gd:"onready=PATH"`. Resolved to get_node(owner, path) on READY. Private (not
// an @export), so it never enters the exports/property list.
Onready_Info :: struct {
	field: string, // struct field name (for offset_of)
	path:  string, // node path relative to owner
}

// `godot.Property_Hint` int values used by the struct-tag hint specs. Kept in sync with
// `godot/godot.gen.odin`'s `Property_Hint :: enum int`.
HINT_RANGE :: 1
HINT_ENUM :: 2
HINT_FILE :: 13
HINT_DIR :: 14
HINT_GLOBAL_FILE :: 15
HINT_GLOBAL_DIR :: 16
HINT_RESOURCE_TYPE :: 17
HINT_MULTILINE_TEXT :: 18
HINT_TYPE_STRING :: 23 // typed Array/Dictionary element-type encoding (Godot's own choice)

// Parse one `gd:"export,..."` hint spec into its (Property_Hint int, hint_string).
//
// SYNTAX. The struct tag is `gd:"export[,SPEC]"` with at most one hint SPEC. Top-level
// tokens are comma-separated; values WITHIN a spec are colon-separated (so list values
// like a file filter never collide with the comma separator) and are rewritten to the
// comma-joined form Godot's hint_string conventions expect:
//   - range=MIN:MAX        -> Range,        hint_string "MIN,MAX"
//   - range=MIN:MAX:STEP   -> Range,        hint_string "MIN,MAX,STEP"
//   - enum=A:B:C           -> Enum,         hint_string "A,B,C"
//   - multiline            -> Multiline_Text
//   - file                 -> File,         hint_string ""   (any file)
//   - file=*.png:*.jpg     -> File,         hint_string "*.png,*.jpg"
//   - dir                  -> Dir
//   - global_file[=...]    -> Global_File
//   - global_dir           -> Global_Dir
//   - resource=Texture2D   -> Resource_Type, hint_string "Texture2D"
parse_hint_spec :: proc(owner, field, spec: string, field_vt: string) -> (hint: int, hint_string: string, ok: bool) {
	name := spec
	value := ""
	if eq := strings.index(spec, "="); eq >= 0 {
		name = strings.trim_space(spec[:eq])
		value = strings.trim_space(spec[eq + 1:])
	}
	// colon-separated list values -> Godot's comma-separated hint_string form.
	csv :: proc(v: string) -> string {
		return strings.replace_all(v, ":", ",") or_else v
	}
	switch name {
	case "range":
		if value == "" {
			errorf("%s.%s: `range` hint needs MIN:MAX[:STEP]", owner, field)
			return 0, "", false
		}
		return HINT_RANGE, csv(value), true
	case "enum":
		if value == "" {
			errorf("%s.%s: `enum` hint needs A:B:C", owner, field)
			return 0, "", false
		}
		return HINT_ENUM, csv(value), true
	case "multiline":
		return HINT_MULTILINE_TEXT, "", true
	case "file":
		return HINT_FILE, csv(value), true
	case "dir":
		return HINT_DIR, csv(value), true
	case "global_file":
		return HINT_GLOBAL_FILE, csv(value), true
	case "global_dir":
		return HINT_GLOBAL_DIR, csv(value), true
	case "resource":
		if value == "" {
			errorf("%s.%s: `resource` hint needs a type name, e.g. resource=Texture2D", owner, field)
			return 0, "", false
		}
		return HINT_RESOURCE_TYPE, value, true
	case "array":
		// Typed Array export: `gd.Array `gd:"export,array=int"`` (or a Resource class, e.g.
		// `array=Texture2D`). Renders the Inspector's typed-array editor.
		if field_vt != ".Array" {
			errorf("%s.%s: `array=` hint requires the field to be `gd.Array` (got %s)", owner, field, field_vt)
			return 0, "", false
		}
		part, pok := encode_type_part(owner, field, value)
		if !pok {return 0, "", false}
		return HINT_TYPE_STRING, part, true
	case "dict":
		// Typed Dictionary export: `gd.Dictionary `gd:"export,dict=String;int"`` — KEY and VALUE
		// separated by `;` (each a builtin like int/float/String or a Resource class). Renders
		// the Inspector's typed-dictionary editor (Godot 4.4+).
		if field_vt != ".Dictionary" {
			errorf("%s.%s: `dict=` hint requires the field to be `gd.Dictionary` (got %s)", owner, field, field_vt)
			return 0, "", false
		}
		semi := strings.index(value, ";")
		if semi < 0 {
			errorf("%s.%s: `dict=` needs KEY;VALUE, e.g. dict=String;int", owner, field)
			return 0, "", false
		}
		kpart, kok := encode_type_part(owner, field, value[:semi])
		vpart, vok := encode_type_part(owner, field, value[semi + 1:])
		if !kok || !vok {return 0, "", false}
		return HINT_TYPE_STRING, strings.concatenate({kpart, ";", vpart}), true
	case:
		errorf("%s.%s: unknown export hint %q", owner, field, name)
		return 0, "", false
	}
}

// encode_type_part encodes ONE key/value/element type for a typed Array/Dictionary export
// hint_string (Godot's PROPERTY_HINT_TYPE_STRING form). A builtin renders as
// "<variant_type_int>:" (int -> "2:", String -> "4:"); anything else is taken to be a Resource
// class and renders "24/17:ClassName" (24=TYPE_OBJECT, 17=HINT_RESOURCE_TYPE) — only
// Resource-derived objects are serializable as exports.
encode_type_part :: proc(owner, field, t: string) -> (string, bool) {
	n := strings.trim_space(t)
	if i := strings.last_index(n, "."); i >= 0 {
		n = n[i + 1:] // strip a gd./godot. qualifier
	}
	if n == "" {
		errorf("%s.%s: typed Array/Dictionary export has an empty element type", owner, field)
		return "", false
	}
	if vt := builtin_variant_int(n); vt >= 0 {
		buf: [8]byte
		return strings.concatenate({strconv.itoa(buf[:], vt), ":"}), true
	}
	return strings.concatenate({"24/17:", n}), true
}

// builtin_variant_int maps a builtin type name (Godot or Odin spelling) to its Variant::Type
// integer, or -1 if it's not a builtin (then it's treated as a Resource class). Values are the
// ABI-stable Godot 4 Variant type ids.
builtin_variant_int :: proc(n: string) -> int {
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

// Parse an `@export default=...` literal (richer-authoring #3) for a field of Variant `vi`.
// Scalars only: Int/Float/Bool -> default_num (bool as 0/1); String -> default_str (quotes
// stripped). Returns ok=false (with a clear error) for unsupported types / bad literals.
parse_default :: proc(owner, field: string, vi: Variant_Info, value: string) -> (num: f64, str: string, ok: bool) {
	v := strings.trim_space(value)
	switch vi.kind {
	case .Int:
		n, pok := strconv.parse_i64(v)
		if !pok {
			errorf("%s.%s: bad integer default %q", owner, field, v)
			return 0, "", false
		}
		return f64(n), "", true
	case .Float:
		f, pok := strconv.parse_f64(v)
		if !pok {
			errorf("%s.%s: bad float default %q", owner, field, v)
			return 0, "", false
		}
		return f, "", true
	case .Bool:
		switch v {
		case "true":
			return 1, "", true
		case "false":
			return 0, "", true
		case:
			errorf("%s.%s: bool default must be true/false (got %q)", owner, field, v)
			return 0, "", false
		}
	case .Other:
		// Only the String Variant supports a `default=` (other Other-kinds — Vector*, Color,
		// Object, packed arrays — are not yet supported; report rather than silently drop).
		if vi.enum_name == ".String" {
			return 0, strings.trim(v, "\"`"), true
		}
		errorf("%s.%s: `default=` only supported for int/float/bool/String (type %s)", owner, field, vi.enum_name)
		return 0, "", false
	case .Nil:
		errorf("%s.%s: `default=` on a void-typed field", owner, field)
		return 0, "", false
	}
	return 0, "", false
}

Arg :: struct {
	name:      string,
	type_text: string,
	vi:        Variant_Info,
}

Method_Info :: struct {
	proc_name: string, // the user's Odin proc
	gd_name:   string, // the name exposed to GDScript
	args:      [dynamic]Arg,
	ret:       Variant_Info, // .Nil kind => void
}

Lifecycle_Info :: struct {
	keyword:   string, // ready / process / physics_process / enter_tree / exit_tree
	proc_name: string,
	has_delta: bool,
}

Signal_Arg :: struct {
	name: string,
	vi:   Variant_Info,
}

Signal_Info :: struct {
	name: string,
	args: [dynamic]Signal_Arg,
}

// A `@(gd_connect="signal")` declaration on a method: auto-connect owner.signal -> method.
Connection_Info :: struct {
	signal: string, // the signal name on the owner node
	method: string, // the GDScript-exposed method name (the @(gd_method) gd_name)
}

// `MultiplayerAPI.RPCMode` int values (extension_api.json: MultiplayerAPI.RPCMode).
RPC_MODE_ANY_PEER :: 1
RPC_MODE_AUTHORITY :: 2

// `MultiplayerPeer.TransferMode` int values (extension_api.json: MultiplayerPeer.TransferMode).
TRANSFER_MODE_UNRELIABLE :: 0
TRANSFER_MODE_UNRELIABLE_ORDERED :: 1
TRANSFER_MODE_RELIABLE :: 2

// A `@(gd_rpc[="..."])` declaration on a `@(gd_method)` proc. `method` is the GDScript-exposed
// name; the rest is the resolved per-method RPC config the core hands the engine. Defaults
// mirror GDScript's bare `@rpc`: authority / reliable / no call_local / channel 0.
Rpc_Info :: struct {
	method:     string,
	mode:       int, // RPCMode int
	transfer:   int, // TransferMode int
	call_local: bool,
	channel:    int,
}

Script :: struct {
	pkg:         string,
	struct_name: string,
	class_name:  string,
	base:        string,
	marked:      bool, // saw at least one valid `//gd:` marker (intent signal for diagnostics)
	tool:        bool,
	icon:        string, // `//gd:icon <res-path>` — custom class icon (""=none)
	exports:     [dynamic]Export_Info,
	lifecycles:  [dynamic]Lifecycle_Info,
	methods:     [dynamic]Method_Info,
	signals:     [dynamic]Signal_Info,
	connections: [dynamic]Connection_Info,
	onready:     [dynamic]Onready_Info,
	rpcs:        [dynamic]Rpc_Info,
}

had_error: bool

errorf :: proc(format: string, args: ..any) {
	fmt.eprintf("scriptgen: error: ")
	fmt.eprintf(format, ..args)
	fmt.eprintln()
	had_error = true
}

// Non-fatal diagnostic — prints but does NOT fail the build (used for likely-typo hints
// where scriptgen can't be sure, e.g. a proc whose name is one edit away from a lifecycle).
warnf :: proc(format: string, args: ..any) {
	fmt.eprintf("scriptgen: warning: ")
	fmt.eprintf(format, ..args)
	fmt.eprintln()
}

// ---- main --------------------------------------------------------------------

main :: proc() {
	args := os.args[1:]
	if len(args) < 1 {
		fmt.eprintln("usage: scriptgen <scripts_dir>")
		os.exit(2)
	}
	scripts_dir := ""
	for a in args {
		// `-res:<dir>` is a legacy flag from the two-file (stub) model — accepted but
		// ignored now that the authored source IS the attached resource.
		if strings.has_prefix(a, "-res:") {
			continue
		}
		scripts_dir = a
	}
	if scripts_dir == "" {
		fmt.eprintln("usage: scriptgen <scripts_dir>")
		os.exit(2)
	}

	dir_fh, oerr := os.open(scripts_dir)
	if oerr != nil {
		fmt.eprintfln("scriptgen: cannot open dir %q", scripts_dir)
		os.exit(1)
	}
	files, rderr := os.read_dir(dir_fh, -1, context.allocator)
	os.close(dir_fh)
	if rderr != nil {
		fmt.eprintfln("scriptgen: cannot read dir %q", scripts_dir)
		os.exit(1)
	}

	emitted := 0
	pkg := "" // the scripts package name (for the generated boot); from the first source file
	has_boot := false // a hand-written `odin_scripts_boot` exists — don't generate one
	seen_classes := make(map[string]string) // //gd:class name -> file that declared it
	defer delete(seen_classes)
	for fi in files {
		if fi.type == .Directory {continue}
		if !strings.has_suffix(fi.name, ".odin") {continue}
		if strings.has_suffix(fi.name, ".gen.odin") {continue}
		path := fi.fullpath

		src_bytes, rerr := os.read_entire_file_from_path(path, context.allocator)
		if rerr != nil {
			errorf("cannot read %q", path)
			continue
		}
		src := string(src_bytes)

		// Track the package name + whether the project already supplies its own boot. We
		// scan EVERY source file (not just scripts) so a hand-written boot.odin — which has
		// no owner-struct and so isn't a "script" — is still detected and respected.
		if pkg == "" {
			if p := scan_package(src); p != "" {pkg = p}
		}
		if strings.contains(src, "odin_scripts_boot") {has_boot = true}

		script, has := parse_script(path, src)
		if !has {continue} // not a script file (no owner-struct) — skip silently
		if had_error {continue}

		// Duplicate //gd:class across files: the core's name->desc map would silently let the
		// last-loaded win and mis-bind the other. Catch it here with both file paths.
		if prev, dup := seen_classes[script.class_name]; dup {
			errorf("duplicate //gd:class %q in %q and %q", script.class_name, prev, path)
			continue
		}
		seen_classes[script.class_name] = path

		gen := generate(&script)
		out_path := strings.concatenate({path[:len(path) - len(".odin")], ".gen.odin"})
		if werr := os.write_entire_file(out_path, transmute([]byte)gen); werr != nil {
			errorf("cannot write %q", out_path)
			continue
		}
		fmt.printfln("scriptgen: wrote %s", out_path)
		emitted += 1
	}

	if had_error {
		os.exit(1)
	}

	// Generate the REQUIRED boot shim (the `odin_scripts_boot` export the core calls after
	// dlopen) so users never hand-copy it — UNLESS the project already defines its own.
	// Skipped when the package has no name (nothing to compile anyway).
	if !has_boot && pkg != "" {
		dir := strings.trim_suffix(scripts_dir, "/")
		boot_path := strings.concatenate({dir, "/odin_godot_boot.gen.odin"})
		if werr := os.write_entire_file(boot_path, transmute([]byte)gen_boot(pkg)); werr != nil {
			errorf("cannot write %q", boot_path)
		} else {
			fmt.printfln("scriptgen: wrote %s (boot shim)", boot_path)
		}
	}

	fmt.printfln("scriptgen: generated %d script(s)", emitted)
}

// First `package <name>` declaration in a source file (cheap line scan — independent of the
// full parser so it works on any .odin, including non-script helpers).
scan_package :: proc(src: string) -> string {
	it := src
	for line in strings.split_lines_iterator(&it) {
		t := strings.trim_space(line)
		if !strings.has_prefix(t, "package ") {continue}
		rest := strings.trim_space(t[len("package "):])
		// Cut at the first whitespace or line comment.
		end := len(rest)
		for r, i in rest {
			if r == ' ' || r == '\t' || (r == '/' && i + 1 < len(rest) && rest[i + 1] == '/') {
				end = i
				break
			}
		}
		return strings.trim_space(rest[:end])
	}
	return ""
}

// The generated boot shim: the `@(export) odin_scripts_boot` the core invokes right after
// it dlopens the scripts dll, so the dll initializes its OWN gdext/godot package globals
// before any script proc runs. (Define your own `odin_scripts_boot` to opt out.)
gen_boot :: proc(pkg: string) -> string {
	b: strings.Builder
	strings.builder_init(&b)
	fmt.sbprintf(&b, "package %s\n\n", pkg)
	w :: strings.write_string
	w(&b, "// GENERATED by scriptgen — do not edit. The odin_godot CORE dll calls\n")
	w(&b, "// `odin_scripts_boot` immediately after it dlopens this compiled scripts dll, so the\n")
	w(&b, "// dll can initialize its OWN gdext/godot package globals before any of your script\n")
	w(&b, "// procs run. Define your own `odin_scripts_boot` in a hand-written file to opt out.\n\n")
	w(&b, "import \"godot:gdext\"\n")
	w(&b, "import \"godot:godot\"\n\n")
	w(&b, "@(export)\n")
	w(&b, "odin_scripts_boot :: proc \"c\" (\n")
	w(&b, "\tget_proc_address: gdext.ExtensionInterfaceGetProcAddress,\n")
	w(&b, "\tlibrary: gdext.ExtensionClassLibraryPtr,\n")
	w(&b, ") {\n")
	w(&b, "\tgdext.init(library, get_proc_address)\n")
	w(&b, "\tgodot.init()\n")
	w(&b, "}\n")
	return strings.to_string(b)
}
