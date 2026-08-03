package script_runtime

import "base:runtime"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "godot:gdext"
import gd "godot:godot"
import decl "godot:decl"

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
	// Godot class spelling scriptgen derived from a TYPED resource handle
	// (`gd.Packed_Scene` -> "PackedScene") when the tag spells no `resource=`.
	// Reflection cannot recover it (every refcounted handle erases to the same
	// ^rawptr), and the Resource_Type hint it synthesizes is what switches on
	// inst_set's refcount hold — without it the field would dangle.
	resource_class: cstring,
}

// Everything reflection cannot see about a class. INTERNAL to the scripts dll (see
// the header comment); the C-shaped pointer+count pairs reference static arrays in
// the generated file, exactly like Class_Desc's.
//
// `signals` is a HAND-WRITTEN escape hatch only: script signals are declared as typed
// struct fields (gd.Signal0 … Signal4) and built by the reflection walk — scriptgen no
// longer emits a signal table. A table passed here is folded in after the walked ones.
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
	// `//gd:group a b` — group names the core joins on READY (static cstrings in the
	// generated file, dll-lifetime).
	groups:            [^]cstring,
	groups_count:      i32,
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
		groups            = info.groups,
		groups_count      = info.groups_count,
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
	signals_start := signal_pool_count
	walk_members(info, st, 0, "", true)
	detect_dup_member_names(info.name, exports_start, signals_start)
	if n := export_pool_count - exports_start; n > 0 {
		desc.exports = raw_data(export_pool[exports_start:])
		desc.exports_count = i32(n)
	}
	if n := onready_pool_count - onready_start; n > 0 {
		desc.onready = raw_data(onready_pool[onready_start:])
		desc.onready_count = i32(n)
	}
	if signal_pool_count > signals_start {
		// Signal fields found. A hand-written Class_Info may ALSO carry its own signal
		// table — fold it into the same contiguous pool run so the desc stays one table.
		// (When no signal fields exist, desc.signals = info.signals from above, zero-copy.)
		for i in 0 ..< int(info.signals_count) {
			if signal_pool_count >= MAX_REFLECT_SIGNALS {
				record_error(info.name, nil, "registration signal pool exhausted — signal dropped")
				break
			}
			signal_pool[signal_pool_count] = info.signals[i]
			signal_pool_count += 1
		}
		desc.signals = raw_data(signal_pool[signals_start:])
		desc.signals_count = i32(signal_pool_count - signals_start)
	}
	return desc
}

// Walk a struct's fields into the Export/Onready/Signal pools, recursing into UNTAGGED
// embedded sub-structs so their members register with a computed NAME and cumulative
// offset — the runtime half of nested tagged fields (nested-replicate-fields KB doc).
//
//   * `using` embeds FLATTEN: members register under their promoted leaf name (`prefix`
//     unchanged) — Odin guarantees those are unique.
//   * plain embeds NAMESPACE: members register under `<field>_<...>_<leaf>` (`prefix`
//     grows by `<field>_`), mirroring the `self.field.x` access path. Two members that
//     collide are caught by detect_dup_member_names, not silently last-wins.
//
// `base` is the byte offset of `st` within the registered entity; `skip_owner` drops
// field 0 (the owner handle) at the TOP level only. Variant value types (Vector2/…) are
// leaves, never bundles, so recursion skips them. (`replicate` fields are handled entirely
// by scriptgen's Entity_Desc — walk_field returns early for them — so nesting them changes
// nothing at runtime.)
@(private = "file")
walk_members :: proc(info: Class_Info, st: runtime.Type_Info_Struct, base: uintptr, prefix: string, skip_owner: bool) {
	for i in 0 ..< int(st.field_count) {
		if skip_owner && i == 0 {continue} // the owner Object pointer — never a member
		// prefix "" (top level / all-`using` path) keeps the leaf name verbatim, so existing
		// flat classes register byte-identically.
		name := prefix == "" ? st.names[i] : strings.concatenate({prefix, st.names[i]})
		tag, has := reflect.struct_tag_lookup(reflect.Struct_Tag(st.tags[i]), "gd")
		// A signal field declares itself by TYPE (gd.Signal0 … Signal4, or the general
		// gd.SignalN) — the tag is OPTIONAL for the arity family and FORBIDDEN for
		// SignalN, so these checks precede the tagged-fields-only skip below.
		if arg_tis, is_signal := signal_field_args(st.types[i]); is_signal {
			walk_signal_field(info, name, arg_tis, tag, has)
			continue
		}
		if payload_ti, is_sn := signal_n_payload(st.types[i]); is_sn {
			walk_signal_n_field(info, name, payload_ti, has)
			continue
		}
		if has {
			walk_field(info, name, st.types[i], base + st.offsets[i], tag)
			continue
		}
		// Untagged struct field: recurse. Skip Variant value types (Vector2/Transform/… —
		// leaves, not component bundles) so we don't walk into engine math structs.
		if _, is_variant := variant_type_for(st.types[i].id); is_variant {continue}
		if sub, ok := runtime.type_info_base(st.types[i]).variant.(runtime.Type_Info_Struct); ok {
			sub_prefix := st.usings[i] ? prefix : strings.concatenate({prefix, st.names[i], "_"})
			walk_members(info, sub, base + st.offsets[i], sub_prefix, false)
		}
	}
}

// A plain embed can produce two members with the same registered name (a top-level
// `aim_x` and `aim.x`, say). Odin can't catch that — the access paths differ — so a
// duplicate is reported here as a loud error, never a silent last-wins. Scoped to THIS
// class's pool run [start, count); O(n²) over a handful of members.
@(private = "file")
detect_dup_member_names :: proc(class: cstring, ex_start, sig_start: int) {
	for i in ex_start ..< export_pool_count {
		for j in ex_start ..< i {
			if string(export_pool[i].name) == string(export_pool[j].name) {
				record_error(class, export_pool[i].name, "duplicate member name from a nested embed — rename the field or reach it through `using`")
				break
			}
		}
	}
	for i in sig_start ..< signal_pool_count {
		for j in sig_start ..< i {
			if string(signal_pool[i].name) == string(signal_pool[j].name) {
				record_error(class, signal_pool[i].name, "duplicate signal name from a nested embed — rename the field or reach it through `using`")
				break
			}
		}
	}
}

// Classify the '%' characters in an onready/@(gd_connect) node path. A '%' at a
// SEGMENT START (path start or right after '/') is Godot's scene-unique-name marker
// (`%Hud`, `%doc/Sprite`) — engine NodePath syntax, passed through to get_node
// untouched. Only a MID-SEGMENT `%d` (`Card%d`) is the array/index template. The
// split is load-bearing: a unique name that happens to start with 'd' (`%dock`)
// contains the bytes "%d", and a naive index() would substitute into it. tmpl_at is
// the byte offset of the first mid-segment `%d` (-1 if none) — the core substitutes
// indices there; stray counts mid-segment '%'s that are neither (always refused).
// Exported: the core's resolve/probe loops use tmpl_at for the same reason, and
// scriptgen mirrors this rule build-time (scan_path_template in parse.odin).
scan_onready_template :: proc "contextless" (path: string) -> (tmpl_at: int, tmpl_count: int, stray: int) {
	tmpl_at = -1
	for i in 0 ..< len(path) {
		if path[i] != '%' {continue}
		if i == 0 || path[i - 1] == '/' {continue}
		if i + 1 < len(path) && path[i + 1] == 'd' {
			if tmpl_at < 0 {tmpl_at = i}
			tmpl_count += 1
		} else {
			stray += 1
		}
	}
	return
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
		// ARRAY onready — `[N]gd.Button` / `[N]^script struct` with a `%d` path template:
		// unwrap the fixed array here so the ELEMENT type runs through the same scalar
		// classification below; `count` marks the entry and the core substitutes 0-based
		// indices into the template at resolve time.
		elem_ti := fti
		count := 0
		if ai, is_arr := runtime.type_info_base(fti).variant.(runtime.Type_Info_Array); is_arr && ai.elem != nil {
			elem_ti = ai.elem
			count = ai.count
			if count <= 0 || count > 4096 {
				record_error(cls, name_c, "`onready=` array field needs a fixed length between 1 and 4096")
				return
			}
		}
		// The `%d` template contract: arrays need exactly one MID-NAME `%d` (and no
		// stray mid-name '%'); scalars none. A '%' at a segment start is Godot's
		// scene-unique-name marker (`%Hud`) — engine path syntax, passed through
		// untouched (see scan_onready_template for why the split matters).
		_, tmpl_count, stray := scan_onready_template(path)
		if count > 0 {
			if tmpl_count != 1 || stray != 0 {
				record_error(cls, name_c, "`onready=` on an array field needs exactly one mid-name `%d` in the path (e.g. `Shop/Card%d`), substituted with 0-based indices; a leading `%Name` is a scene-unique name and fine")
				return
			}
		} else if tmpl_count != 0 || stray != 0 {
			record_error(cls, name_c, "`onready=` path has a '%' inside a node name — only `%Name` at a segment start (scene-unique name) is valid here; the `%d` template form is for FIXED-ARRAY fields ([N]gd.Node2d, [N]^Script)")
			return
		}
		// SCRIPT-RESOLVING onready: the (element) type is `^S` where S is a struct — the
		// author wants the target's Odin SCRIPT STRUCT (rt.script_of), not the node
		// handle. Classified STRUCTURALLY, which is unambiguous: every Godot handle is a
		// rawptr alias (gd.Node2d, ...) or a pointer-to-rawptr (^gd.Resource and
		// friends) — never a pointer-to-struct. Whether S is actually a REGISTERED
		// script class can't be known mid-walk (its own `@(init)` may not have run yet),
		// so only the typeid is recorded here; fixup_onready_script_targets resolves or
		// refuses it at manifest time. Without this arm the blanket any-pointer->.Object
		// rule below accepted `^S` and the core wrote a raw NODE pointer into it — type
		// confusion wearing a passing build.
		script_id: typeid
		if pi, is_ptr := runtime.type_info_base(elem_ti).variant.(runtime.Type_Info_Pointer); is_ptr && pi.elem != nil {
			if _, is_st := runtime.type_info_base(pi.elem).variant.(runtime.Type_Info_Struct); is_st {
				script_id = pi.elem.id
			}
		}
		if script_id == nil {
			if vt, vok := variant_type_for(elem_ti.id); !vok || vt != .Object {
				record_error(cls, name_c, "`onready` field must be an object/node handle or pointer (or a fixed array of them)")
				return
			}
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
		onready_pool[onready_pool_count] = Onready{offset = offset, path = path_c, field = name_c, script_id = script_id, count = i32(count)}
		onready_pool_count += 1
		return
	}

	// The kit toolkit's tags — consumed entirely by scriptgen (descriptor
	// tables, backup codecs, the profile install, sim-block wiring); nothing
	// to reflect at runtime. This USED to be a hand-kept list, and `backup`
	// spent a while missing from it: every backup field logged a bogus
	// "unknown gd tag" on every boot. It is now a projection of the shared
	// schema (godot:decl) — a token added there is skipped here by
	// construction, and named in the error text below by the same table.
	if decl.field_is_build_only(tok0) {
		return
	}

	// `gd:"entity=Name:id"` — the one token BOTH halves act on. scriptgen builds
	// the factory table from it; the Inspector still needs the PackedScene slot
	// the author no longer spells out, so the `export` and `resource=PackedScene`
	// the declaration IMPLIES are synthesized here, mirroring scriptgen's
	// synthesis at build time. Trailing export specs (group=, default=) ride
	// behind and are parsed by the loop below exactly as they always were.
	entity_first := strings.has_prefix(tok0, "entity=")
	if entity_first {
		tok0 = "export"
	}

	if tok0 != "export" {
		if strings.has_prefix(tok0, "args=") {
			record_error(cls, name_c, "`args=` is only valid on a signal field (gd.Signal0 … gd.Signal4)")
			return
		}
		expected := decl.field_expected(context.temp_allocator)
		msg, _ := pool_cstr("unknown gd tag `", tok0, "` (expected ", expected, ")")
		if msg == nil {msg = "unknown gd tag"}
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
		// PROJECTION — the spec VOCABULARY, and whether a name is Inspector
		// plumbing or the field's one Property_Hint, come from godot:decl's
		// EXPORT_SPECS. This dispatch used to be two hand-written switches with no
		// shared vocabulary between them: the one here had NO DEFAULT ARM, so every
		// name it didn't recognize fell through to parse_hint_spec and came back as
		// "unknown export hint `gropu`" — the wrong sentence for a meta typo, and a
		// sentence neither switch could finish with the legal set, because neither
		// knew the other's labels. tests/scriptgen papered over the split by
		// extracting both switches' case labels with awk and asserting them equal to
		// the table; that test could see drift but could not prevent it. Now the
		// table SELECTS, and each switch below owns only what its names MEAN.
		sp, sok := decl.export_spec(sname)
		if !sok {
			specs := decl.export_specs_list(context.temp_allocator)
			msg, _ := pool_cstr("unknown export spec `", sname, "` (the set is: ", specs, ")")
			if msg == nil {msg = "unknown export spec"}
			record_error(cls, name_c, msg)
			continue
		}

		switch sp.kind {
		case .Meta:
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
				// godot:decl lists this name as .Meta and nothing here knows what it
				// DOES. The table records that a spec exists; this file owns its
				// effect, so the gap is real and silence would be a spec the author
				// wrote and the Inspector ignored. FIX: add an arm above, or mark the
				// row .Hint and give parse_hint_spec one.
				msg, _ := pool_cstr("export spec `", sname, "` is declared in godot:decl but walk_field has no arm for it — add one")
				if msg == nil {msg = "export spec declared in godot:decl with no walk_field arm"}
				record_error(cls, name_c, msg)
			}
		case .Hint:
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

	// The other half of the `entity=` synthesis: the PackedScene hint the tag no
	// longer spells. Applied AFTER the loop so a trailing spec can't be silently
	// outranked by it — an author-supplied hint beside `entity=` is scriptgen's
	// error to report at build time, not something to overwrite here at boot.
	if entity_first && !has_hint {
		if h, hs, hok := parse_hint_spec(cls, name_c, "resource", "PackedScene", vt); hok {
			has_hint = true
			ex.hint = h
			ex.hint_string = hs
		}
	}

	// OBJECT exports must end up hinted — the hint is load-bearing, not cosmetic:
	// inst_set's resource refcounting keys off Property_Hint.Resource_Type, so a
	// hint-less object export stores an UNREFERENCED pointer that dangles once the
	// loader's transient ref drops (a delayed SIGSEGV far from the field). scriptgen
	// derives the class from a typed handle (`gd.Packed_Scene`) and ships it here in
	// Field_Meta.resource_class; when neither that nor an explicit `resource=` /
	// `entity=` provided a hint, refuse the registration loudly.
	if vt == .Object && !has_hint {
		if meta != nil && meta.resource_class != nil {
			if h, hs, hok := parse_hint_spec(cls, name_c, "resource", string(meta.resource_class), vt); hok {
				has_hint = true
				ex.hint = h
				ex.hint_string = hs
			}
		} else {
			record_error(cls, name_c, "object export needs a resource class — type the field (e.g. `gd.Packed_Scene`) so the build derives it, or spell `resource=<Class>`; a hint-less object export stores an unreferenced pointer that dangles after scene load")
			return
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

// ---- signal fields (gd.Signal0 … Signal4, gd.SignalN) ---------------------------

// Detect an arity-family signal MARKER field type (godot/Signal_Fields.odin) and return the payload
// type infos. Matched by the instantiation's Named spelling ("Signal0", "Signal2($A=…")
// AND its structural shape — the single `_marker` phantom pointer whose pointee struct's
// field types ARE the payload typeids. Structural recovery is what lets the arg types go
// through the same variant_type_for every export uses (no rendered-name parsing).
@(private = "file")
signal_field_args :: proc(fti: ^runtime.Type_Info) -> (arg_tis: []^runtime.Type_Info, is_signal: bool) {
	named, is_named := fti.variant.(runtime.Type_Info_Named)
	if !is_named {return nil, false}
	n := named.name
	matched := n == "Signal0"
	if !matched {
		for prefix in ([4]string{"Signal1($A=", "Signal2($A=", "Signal3($A=", "Signal4($A="}) {
			if strings.has_prefix(n, prefix) {
				matched = true
				break
			}
		}
	}
	if !matched {return nil, false}
	st, sok := runtime.type_info_base(fti).variant.(runtime.Type_Info_Struct)
	if !sok || st.field_count != 1 || st.names[0] != "_marker" {return nil, false}
	ptr, pok := runtime.type_info_base(st.types[0]).variant.(runtime.Type_Info_Pointer)
	if !pok {return nil, false}
	inner, iok := runtime.type_info_base(ptr.elem).variant.(runtime.Type_Info_Struct)
	if !iok {return nil, false}
	return inner.types[:inner.field_count], true
}

// Detect the general-form marker (gd.SignalN — the struct-payload form) and return the
// PAYLOAD type info (the `_marker` pointee, i.e. the $P parameter). Matched like
// signal_field_args: the instantiation's Named spelling ("SignalN($P=…") AND the single
// `_marker` phantom-pointer shape. $P itself is NOT validated here — walk_signal_n_field
// owns the plain-struct / not-Variant-mappable rules so a bad parameter is a recorded
// registration error, never a silently skipped field.
@(private = "file")
signal_n_payload :: proc(fti: ^runtime.Type_Info) -> (payload: ^runtime.Type_Info, is_signal_n: bool) {
	named, is_named := fti.variant.(runtime.Type_Info_Named)
	if !is_named || !strings.has_prefix(named.name, "SignalN($P=") {return nil, false}
	st, sok := runtime.type_info_base(fti).variant.(runtime.Type_Info_Struct)
	if !sok || st.field_count != 1 || st.names[0] != "_marker" {return nil, false}
	ptr, pok := runtime.type_info_base(st.types[0]).variant.(runtime.Type_Info_Pointer)
	if !pok {return nil, false}
	return ptr.elem, true
}

// Synthesized payload names for a signal field without an `args=` tag. Static literals —
// the marker family tops out at 4 parameters, so no pooling needed.
@(private = "file")
SYNTH_ARG_NAMES := [4]cstring{"arg0", "arg1", "arg2", "arg3"}

// One signal field -> a Signal pool entry (or a recorded error). The signal name is the
// FIELD name; arg types come from the marker's phantom struct; arg names come from the
// optional `gd:"args=a,b"` tag (comma-separated, one per payload parameter) or synthesize
// as argN. `args=` is the ONLY tag a signal field accepts — in particular a signal cannot
// be `export`ed (it is not a property; it registers as a signal regardless).
@(private = "file")
walk_signal_field :: proc(info: Class_Info, fname: string, arg_tis: []^runtime.Type_Info, tag: string, has_tag: bool) {
	cls := info.name
	name_c, name_ok := pool_cstr(fname)
	if !name_ok {
		record_error(cls, nil, "registration name pool exhausted — signal dropped")
		return
	}

	sig := Signal {
		name = name_c,
	}

	if len(arg_tis) > len(SYNTH_ARG_NAMES) {
		// Unreachable via the marker family (max arity 4) — defensive for a hand-rolled
		// lookalike type.
		record_error(cls, name_c, "signal has too many payload parameters")
		return
	}
	if signal_pool_count >= MAX_REFLECT_SIGNALS {
		record_error(cls, name_c, "registration signal pool exhausted — signal dropped")
		return
	}

	// Payload types — every parameter must be Variant-able (the same rule as exports;
	// object/node handles present as .Object). One bad parameter drops the SIGNAL, loudly.
	if len(arg_tis) > 0 {
		if signal_arg_pool_count + len(arg_tis) > MAX_REFLECT_SIGNAL_ARGS {
			record_error(cls, name_c, "registration signal-arg pool exhausted — signal dropped")
			return
		}
		args_start := signal_arg_pool_count
		for ati in arg_tis {
			vt, vok := variant_type_for(ati.id)
			if !vok {
				record_error(cls, name_c, "signal payload parameter of unsupported type — every parameter must map to a Variant")
				signal_arg_pool_count = args_start // roll back this signal's partial run
				return
			}
			signal_arg_type_pool[signal_arg_pool_count] = vt
			signal_arg_name_pool[signal_arg_pool_count] = SYNTH_ARG_NAMES[signal_arg_pool_count - args_start]
			signal_arg_pool_count += 1
		}
		sig.arg_types = raw_data(signal_arg_type_pool[args_start:])
		sig.arg_types_count = i32(len(arg_tis))
		sig.arg_names = raw_data(signal_arg_name_pool[args_start:])
		sig.arg_names_count = i32(len(arg_tis))

		// Optional `args=a,b` names replace the synthesized argN slots, positionally.
		if has_tag {
			if !strings.has_prefix(tag, "args=") {
				record_error(cls, name_c, "a signal field's gd tag must be `args=name1,name2` (signals register by type and cannot be exported)")
			} else {
				rest := tag[len("args="):]
				idx := 0
				ok := true
				for ok {
					part := rest
					if ci := strings.index_byte(rest, ','); ci >= 0 {
						part = rest[:ci]
						rest = rest[ci + 1:]
					} else {
						rest = ""
					}
					part = strings.trim_space(part)
					if part == "" || idx >= len(arg_tis) {
						ok = false
						break
					}
					pc, pok := pool_cstr(part)
					if !pok {
						ok = false
						break
					}
					signal_arg_name_pool[args_start + idx] = pc
					idx += 1
					if rest == "" {break}
				}
				if !ok || idx != len(arg_tis) {
					record_error(cls, name_c, "`args=` must name each payload parameter exactly once (comma-separated) — synthesized names kept")
					for i in 0 ..< len(arg_tis) {
						signal_arg_name_pool[args_start + i] = SYNTH_ARG_NAMES[i]
					}
				}
			}
		}
	} else if has_tag {
		// A zero-payload signal accepts no tag at all (there is nothing to name).
		record_error(cls, name_c, "a signal field's gd tag must be `args=name1,name2` (signals register by type and cannot be exported)")
	}

	signal_pool[signal_pool_count] = sig
	signal_pool_count += 1
}

// One SignalN field -> a Signal pool entry (or a recorded error). The signal name is the
// FIELD name; the payload struct's FIELD NAMES are the arg names (authoritative — a gd
// tag, `args=` included, is an error) and its field types the arg types. The $P rules
// live here: it must be a plain struct, and never itself a Variant-mappable type (the
// one-arg-vs-arg-list ambiguity is rejected at the boundary — see Signal_Fields.odin).
@(private = "file")
walk_signal_n_field :: proc(info: Class_Info, fname: string, payload_ti: ^runtime.Type_Info, has_tag: bool) {
	cls := info.name
	name_c, name_ok := pool_cstr(fname)
	if !name_ok {
		record_error(cls, nil, "registration name pool exhausted — signal dropped")
		return
	}

	if has_tag {
		// Registered anyway (loudly), like a bad tag on the arity family: the field names
		// already carry everything a tag could say.
		record_error(cls, name_c, "a SignalN field takes no gd tag — the payload struct's field names ARE the arg names")
	}
	if _, mappable := variant_type_for(payload_ti.id); mappable {
		record_error(cls, name_c, "SignalN's parameter is the argument LIST as a struct, not a single payload type — use Signal1(Vector2) or SignalN(struct { pos: Vector2 })")
		return
	}
	inner, iok := runtime.type_info_base(payload_ti).variant.(runtime.Type_Info_Struct)
	if !iok || .raw_union in inner.flags {
		record_error(cls, name_c, "SignalN's parameter must be a plain struct — its field names/types are the signal's payload")
		return
	}

	if signal_pool_count >= MAX_REFLECT_SIGNALS {
		record_error(cls, name_c, "registration signal pool exhausted — signal dropped")
		return
	}
	sig := Signal {
		name = name_c,
	}

	// Payload fields — same Variant rule as the arity family, plus the field NAMES go
	// through the name pool (SignalN has no arity cap, so no static synth table applies;
	// pool exhaustion stays a recorded error).
	if n := int(inner.field_count); n > 0 {
		if signal_arg_pool_count + n > MAX_REFLECT_SIGNAL_ARGS {
			record_error(cls, name_c, "registration signal-arg pool exhausted — signal dropped")
			return
		}
		args_start := signal_arg_pool_count
		for j in 0 ..< n {
			vt, vok := variant_type_for(inner.types[j].id)
			if !vok {
				record_error(cls, name_c, "signal payload parameter of unsupported type — every parameter must map to a Variant")
				signal_arg_pool_count = args_start // roll back this signal's partial run
				return
			}
			arg_c, aok := pool_cstr(inner.names[j])
			if !aok {
				record_error(cls, name_c, "registration name pool exhausted — signal dropped")
				signal_arg_pool_count = args_start
				return
			}
			signal_arg_type_pool[signal_arg_pool_count] = vt
			signal_arg_name_pool[signal_arg_pool_count] = arg_c
			signal_arg_pool_count += 1
		}
		sig.arg_types = raw_data(signal_arg_type_pool[args_start:])
		sig.arg_types_count = i32(n)
		sig.arg_names = raw_data(signal_arg_name_pool[args_start:])
		sig.arg_names_count = i32(n)
	}

	signal_pool[signal_pool_count] = sig
	signal_pool_count += 1
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
	// gd.Object (a DISTINCT rawptr — its typeid is its own) and every class handle
	// alias of it (gd.Node2d, ...); bare rawptr kept for hand-spelled interop fields.
	case rawptr, gd.Object:
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
		// NOT the misspelling gate any more — walk_field refuses every name
		// godot:decl does not list, before this proc is ever called, and names the
		// legal set while doing it. Reaching here means the schema grew a .Hint row
		// this file has no arm for, i.e. a hint the author was allowed to write and
		// the engine would never see. FIX: add a case above with the Property_Hint
		// and hint_string the name means.
		msg, _ := pool_cstr("export hint `", name, "` is declared in godot:decl but parse_hint_spec has no arm for it — add one")
		if msg == nil {msg = "export hint declared in godot:decl with no parse_hint_spec arm"}
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
@(private = "file") MAX_REFLECT_SIGNALS :: 256
@(private = "file") MAX_REFLECT_SIGNAL_ARGS :: 512
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

// Signal tables: one Signal per declared field, plus the parallel arg name/type runs the
// Signal's C-shaped pointer+count pairs reference (one shared cursor — the pools advance
// in lockstep, a signal's args forming one contiguous run in both).
@(private = "file")
signal_pool: [MAX_REFLECT_SIGNALS]Signal
@(private = "file")
signal_pool_count: int

@(private = "file")
signal_arg_name_pool: [MAX_REFLECT_SIGNAL_ARGS]cstring
@(private = "file")
signal_arg_type_pool: [MAX_REFLECT_SIGNAL_ARGS]gdext.Variant_Type
@(private = "file")
signal_arg_pool_count: int

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

// Package-visible (not file-private): `register` in runtime.odin also records here
// for duplicate-class detection.
@(private)
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

// Resolve every script-onready entry's target typeid to its registered class name.
// Called ONCE from odin_scripts_manifest (native and web both pull the manifest right
// after boot, before the registration-errors drain): every class `@(init)` has run by
// then, so a `^S` whose S is a script struct resolves NOW — mid-walk it could not
// (registration order). An S that is NOT a registered script class is refused loudly,
// and the entry is NEUTRALIZED (path = nil; the core skips those): the fallback would
// be writing a raw node pointer into a typed struct field, the exact confusion the
// structural classification exists to kill.
fixup_onready_script_targets :: proc "contextless" () {
	for i in 0 ..< registry_count {
		for &o in desc_onready(registry[i]) {
			if o.script_id == nil || o.script_class != nil {
				continue
			}
			if name := class_name_for_typeid(o.script_id); name != nil {
				o.script_class = name
			} else {
				record_error(
					registry[i].name,
					o.field,
					"`onready=` on a `^T` field resolves the target node's SCRIPT STRUCT (rt.script_of semantics), so T must be a registered script struct — this T is not one. For a plain node reference use a class handle type (gd.Node, gd.Node2d, ...), not a pointer to a struct",
				)
				o.path = nil
			}
		}
	}
}

// TEST-ONLY: reset the walk's pools + error table + the CLASS REGISTRY (runtime.odin —
// same package) so `odin test` cases (which share one process) can exercise exhaustion
// and duplicate-registration without poisoning later cases. Never called in
// production — a dll's pools/registry live exactly as long as the dll.
reflect_register_reset_for_tests :: proc "contextless" () {
	name_pool_used = 0
	export_pool_count = 0
	onready_pool_count = 0
	signal_pool_count = 0
	signal_arg_pool_count = 0
	reg_error_count = 0
	registry_count = 0
	onready_fixup_done = false
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
