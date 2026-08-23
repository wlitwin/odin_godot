package scriptgen

import "core:fmt"
import "core:slice"
import "core:strings"
import decl "godot:decl"

// Maps a Variant enum member like ".Int" to the bare token used to build cached
// constructor variable names (`_to_Int`, `_from_Int`).
ctor_tag :: proc(enum_name: string) -> string {
	return enum_name[1:] // drop leading '.'
}

// ---- replicated-field expressions (nested-replicate-fields) -------------------
//
// A replicated field is addressed by its PATH from the entity root (Replicate_Info.path):
// {"hp"} for a top-level field, {"m","x"} for one reached through a `using`/embedded
// sub-struct. These build the offset/size/type-of expressions the descriptor and the POD
// #assert consume. A length-1 path emits byte-identical output to the pre-nesting code.

// The value-type expression: {"hp"} -> `type_of(Cls{}.hp)`; {"m","x"} -> `type_of(Cls{}.m.x)`.
field_type_expr :: proc(cls: string, path: []string) -> string {
	return fmt.tprintf("type_of(%s{{}}.%s)", cls, join_path(path))
}

// The byte-offset expression. Nested paths compose per segment via `type_of` on the
// container, so no intermediate struct type is ever NAMED — the generated file needs no
// import of the sub-struct's package (works for imported bundles too):
//   {"hp"}        -> offset_of(Cls, hp)
//   {"m","x"}     -> offset_of(Cls, m) + offset_of(type_of(Cls{}.m), x)
//   {"a","b","x"} -> offset_of(Cls, a) + offset_of(type_of(Cls{}.a), b) + offset_of(type_of(Cls{}.a.b), x)
field_offset_expr :: proc(cls: string, path: []string) -> string {
	if len(path) == 1 {
		return fmt.tprintf("offset_of(%s, %s)", cls, path[0])
	}
	b := strings.builder_make()
	for seg, i in path {
		if i > 0 {strings.write_string(&b, " + ")}
		if i == 0 {
			fmt.sbprintf(&b, "offset_of(%s, %s)", cls, seg)
		} else {
			fmt.sbprintf(&b, "offset_of(type_of(%s{{}}.%s), %s)", cls, join_path(path[:i]), seg)
		}
	}
	return strings.to_string(b)
}

// gd:"backup" — the host-local migration/save codec (Backup_Info). A
// version-hashed <class>_backup_write/_read pair over the tagged fields, so a
// takeover or a resume restores the campaign with no hand-matched write/read
// lists to drift. POD fields ride whole (knet.write_pod); map[POD]POD and
// [dynamic]POD get a length-prefixed loop. The version const is an FNV-1a of the
// field SIGNATURE, so a stale blob from a mismatched build bails on read instead
// of misreading bytes — the automatic form of the hand-kept version byte.
emit_backup :: proc(b: ^strings.Builder, s: ^Script) {
	if len(s.backups) == 0 {return}
	cls := s.struct_name
	snake := to_snake(cls)
	upper := strings.to_upper(snake)
	w :: strings.write_string

	// FNV-1a over the field signature — a stable compile-time version stamp
	// (the shared hash law's 32-bit namespace; see godot:decl).
	ver := decl.FNV32_OFFSET
	for bk in s.backups {
		sig := fmt.tprintf("%s|%v|%s|%s;", join_path(bk.path), bk.kind, bk.key, bk.elem)
		ver = decl.fnv1a32_acc(ver, sig)
	}

	pod :: proc(x: string) -> string {
		return fmt.tprintf(
			"intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s)",
			x, x, x,
		)
	}

	w(b, "// ---- gd:\"backup\": host-local migration + save codec ----\n")
	for bk in s.backups {
		switch bk.kind {
		case .Pod:
			fmt.sbprintf(b, "#assert(%s, \"%s.%s: gd:\\\"backup\\\" fields must be POD (no strings, slices, maps, or pointers)\")\n", pod(field_type_expr(cls, bk.path)), cls, bk.field)
		case .Map:
			fmt.sbprintf(b, "#assert(%s, \"%s.%s: gd:\\\"backup\\\" map key must be POD\")\n", pod(bk.key), cls, bk.field)
			fmt.sbprintf(b, "#assert(%s, \"%s.%s: gd:\\\"backup\\\" map value must be POD\")\n", pod(bk.elem), cls, bk.field)
		case .Dyn:
			fmt.sbprintf(b, "#assert(%s, \"%s.%s: gd:\\\"backup\\\" element must be POD\")\n", pod(bk.elem), cls, bk.field)
		}
	}
	fmt.sbprintf(b, "\n%s_BACKUP_VERSION :: u32(0x%x)\n\n", upper, ver)

	// ---- write ----
	fmt.sbprintf(b, "%s_backup_write :: proc(self: ^%s, w: ^knet.Writer) {{\n", snake, cls)
	fmt.sbprintf(b, "\tknet.write_u32(w, %s_BACKUP_VERSION)\n", upper)
	for bk in s.backups {
		acc := fmt.tprintf("self.%s", join_path(bk.path))
		switch bk.kind {
		case .Pod:
			fmt.sbprintf(b, "\tknet.write_pod(w, %s)\n", acc)
		case .Map:
			fmt.sbprintf(b, "\tknet.write_u32(w, u32(len(%s)))\n\tfor k, v in %s {{knet.write_pod(w, k); knet.write_pod(w, v)}}\n", acc, acc)
		case .Dyn:
			fmt.sbprintf(b, "\tknet.write_u32(w, u32(len(%s)))\n\tfor e in %s {{knet.write_pod(w, e)}}\n", acc, acc)
		}
	}
	w(b, "}\n\n")

	// ---- read (false on a version mismatch or a truncated blob) ----
	fmt.sbprintf(b, "%s_backup_read :: proc(self: ^%s, r: ^knet.Reader) -> bool {{\n", snake, cls)
	fmt.sbprintf(b, "\tif knet.read_u32(r) != %s_BACKUP_VERSION {{return false}}\n", upper)
	for bk in s.backups {
		acc := fmt.tprintf("self.%s", join_path(bk.path))
		switch bk.kind {
		case .Pod:
			fmt.sbprintf(b, "\t%s = knet.read_pod(r, type_of(%s))\n", acc, acc)
		case .Map:
			fmt.sbprintf(b, "\t{{\n\t\tn := knet.read_u32(r)\n\t\tif r.err {{return false}}\n\t\tclear(&%s)\n\t\tfor _ in 0 ..< n {{\n\t\t\tk := knet.read_pod(r, %s)\n\t\t\tv := knet.read_pod(r, %s)\n\t\t\tif r.err {{return false}}\n\t\t\t%s[k] = v\n\t\t}}\n\t}}\n", acc, bk.key, bk.elem, acc)
		case .Dyn:
			fmt.sbprintf(b, "\t{{\n\t\tn := knet.read_u32(r)\n\t\tif r.err {{return false}}\n\t\tclear(&%s)\n\t\tfor _ in 0 ..< n {{\n\t\t\te := knet.read_pod(r, %s)\n\t\t\tif r.err {{return false}}\n\t\t\tappend(&%s, e)\n\t\t}}\n\t}}\n", acc, bk.elem, acc)
		}
	}
	w(b, "\treturn !r.err\n}\n\n")
}

// ---- main emitter ------------------------------------------------------------
//
// ONE consolidated `odin_godot_scripts.gen.odin` per scripts dir carries the
// generated code for EVERY annotated script in that dir: one header, one
// `package`, one import block (the UNION of what the sections need), one shared
// cached-Variant-constructor block, then one section per script introduced by a
// `// ==== <source>.odin (class <Class>) ====` banner.
//
// Merging is safe because every generated top-level name is either PUBLIC — and
// so already had to be unique across the package, separate files shared one
// namespace too — or `@(private = "file")` and prefixed with the owning class's
// snake. The one un-prefixed group is the cached-Variant-constructor block
// (`_to_Int`, `_ensure_ctors`, ...), which is hoisted to file scope here and
// emitted ONCE over the union of every section's tags.

// A script's slot in the consolidated file.
Gen_Section :: struct {
	src_name: string, // the REAL authored basename ("mob.odin"), not the class snake
	script:   ^Script,
}

// What ONE script needs from the fixed import set. The file imports the UNION over
// its sections, so an import is emitted exactly when at least one section names it
// — never one no section uses (an unused import is a compile error in Odin).
Gen_Needs :: struct {
	knet, intrinsics, ksim, ksess, kboot, netgd: bool,
}

script_needs :: proc(s: ^Script) -> (n: Gen_Needs) {
	// A gd:"replicate" field needs the kit/net descriptor + the POD compile-time
	// check (commands imply replicates — parse validation enforces it — but keep the
	// condition independent for robustness). @(gd_message) thunks name knet.Player_Id.
	n.knet =
		len(s.replicates) > 0 || len(s.commands) > 0 || len(s.entities) > 0 ||
		len(s.backups) > 0 || len(s.messages) > 0
	n.intrinsics = len(s.replicates) > 0 || len(s.backups) > 0
	// @(gd_tick) generates the sim-lane thunk + Sim_Set (kit/sim) — and an
	// entity TABLE references a target's Sim_Set when that class ticks.
	ticked_entities := false
	for e in s.entities {
		if e.has_tick {
			ticked_entities = true
			break
		}
	}
	// A boot-routed authority step (s.step_boot) is NOT lane wiring — the coop
	// game's fixed step rides `<snake>_step` + the boot accumulator instead.
	has_lane_wiring := len(s.input_classes) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot)
	n.ksim = s.tick.proc_name != "" || len(s.block_ticks) > 0 || ticked_entities || has_lane_wiring
	// Any declared migration half pulls kboot (the hooks table + the events-tail
	// drain) and ksess (the events proc's signature).
	has_succ := s.succ_backup != "" || s.succ_took_over != "" || s.succ_wiped != "" || s.succ_migrating != ""
	// entity tables (`entity=Name:id` scene fields) name ksess.Entity_Type and
	// build kboot.Entity_Kind rows; the lane wiring names ksess.Session; the
	// standard transport forwards route into netgd/ksess; the boot-routed step
	// and the session-event dispatch name ksess too. @(gd_message) names
	// ksess.Typed_Route / session_app_* / Session / Peer_Id / Channel.
	n.ksess =
		len(s.entities) > 0 || has_lane_wiring || len(s.std_forwards) > 0 || s.step_boot ||
		len(s.event_halves) > 0 || has_succ || s.profile_type != "" || len(s.messages) > 0
	// The unified `<verb>_cmd` wrappers take the game's one handle (^kboot.Boot)
	// on BOTH models, so any class with commands names kboot.
	n.kboot = len(s.entities) > 0 || len(s.commands) > 0 || has_succ
	n.netgd = len(s.std_forwards) > 0
	return
}

// The consolidated file's import block. Keyed BOTH ways: by path (a package named
// by two sections is imported once) and by effective alias (two different paths can
// never claim one alias — that would be a duplicate declaration inside DO NOT EDIT
// code, reported as a confusing error against generated source).
Import_Table :: struct {
	by_path:  map[string]string, // path  -> alias
	by_alias: map[string]string, // alias -> path
	lines:    [dynamic]string,
}

// `bare` emits `import "<path>"` (the alias IS the package's own name); otherwise
// `import <alias> "<path>"`. Either way `alias` is the name the bodies write.
import_add :: proc(t: ^Import_Table, alias, path: string, bare := false) {
	if have, dup := t.by_path[path]; dup {
		if have != alias {
			errorf(
				"generated import conflict: %q is imported as %q and also wanted as %q — one package, one alias per generated file",
				path, have, alias,
			)
		}
		return
	}
	if other, taken := t.by_alias[alias]; taken {
		errorf(
			"generated import conflict: the alias %q is claimed by both %q and %q — rename one package's directory",
			alias, other, path,
		)
		return
	}
	t.by_path[path] = alias
	t.by_alias[alias] = path
	if bare {
		append(&t.lines, fmt.aprintf("import %q\n", path))
	} else {
		append(&t.lines, fmt.aprintf("import %s %q\n", alias, path))
	}
}

// The single import block: the fixed trio, the conditional kit imports under the
// UNION of the sections' needs, then the verb-composition packages deduped across
// the whole file.
emit_imports :: proc(b: ^strings.Builder, sections: []Gen_Section) {
	need: Gen_Needs
	for sec in sections {
		n := script_needs(sec.script)
		need.knet |= n.knet
		need.intrinsics |= n.intrinsics
		need.ksim |= n.ksim
		need.ksess |= n.ksess
		need.kboot |= n.kboot
		need.netgd |= n.netgd
	}

	t: Import_Table
	t.by_path = make(map[string]string, context.temp_allocator)
	t.by_alias = make(map[string]string, context.temp_allocator)
	t.lines = make([dynamic]string, context.temp_allocator)

	import_add(&t, "gd", "godot:godot")
	import_add(&t, "gdext", "godot:gdext", bare = true)
	import_add(&t, "rt", "godot:runtime")
	if need.knet {import_add(&t, "knet", "godot:kit/net")}
	if need.intrinsics {import_add(&t, "intrinsics", "base:intrinsics", bare = true)}
	if need.ksim {import_add(&t, "ksim", "godot:kit/sim")}
	if need.ksess {import_add(&t, "ksess", "godot:kit/session")}
	if need.kboot {import_add(&t, "kboot", "godot:kit/boot")}
	if need.netgd {import_add(&t, "netgd", "godot:kit/netgd")}
	fixed := len(t.lines)

	// verb-composition: import each package a COMPOSED command's/method's/block
	// tick's proc lives in, so the routed thunk can name `play.gun_fire`. "" = the
	// entity's own package (no import). The fixed imports above are already in the
	// table, so a block that unusually lives in one is never double-imported —
	// it collides loudly instead of emitting an unresolvable qualifier.
	for sec in sections {
		s := sec.script
		for c in s.commands {
			if c.pkg_path != "" {import_add(&t, c.pkg_alias, c.pkg_path)}
		}
		for m in s.methods {
			if m.pkg_path != "" {import_add(&t, m.pkg_alias, m.pkg_path)}
		}
		for bt in s.block_ticks {
			if bt.pkg_path != "" {import_add(&t, bt.pkg_alias, bt.pkg_path)}
		}
	}
	// The fixed imports keep their canonical order; the composed ones sort, so the
	// same inputs produce a byte-identical block however the sections arrived.
	slice.sort(t.lines[fixed:])
	for line in t.lines {
		strings.write_string(b, line)
	}
	// The trampolines/lifecycle wrappers establish `context = rt.script_context()` before
	// calling the user's plain Odin procs. On native that is `runtime.default_context()`
	// (heap-backed); on web the core installs an engine-backed context with a working
	// temp allocator (the freestanding default context has none). See runtime/context.odin.
	strings.write_string(b, "\n")
}

// The ONE cached-Variant-constructor block, over the union of every section's tags.
// It is the only generated group whose names are not class-prefixed, so sharing one
// file means sharing one definition — every trampoline already calls exactly these
// names, so hoisting needs no change at the call sites.
emit_ctors :: proc(b: ^strings.Builder, sections: []Gen_Section) {
	w :: strings.write_string
	add :: proc(set: ^[dynamic]string, tag: string) {
		for e in set {if e == tag {return}}
		append(set, tag)
	}
	to_set := make([dynamic]string, context.temp_allocator)
	from_set := make([dynamic]string, context.temp_allocator)
	// Every method/accessor trampoline opens with `_ensure_ctors()`, so its definition must
	// exist whenever ANY such trampoline is emitted — even if no arg/return needs a Variant
	// constructor (a zero-arg `@(gd_method)` on a script with no other ctor needs). In that
	// case the proc is a cheap no-op; without it the call is an undeclared-name error.
	has_trampoline := false
	for sec in sections {
		s := sec.script
		st, sf := collect_ctors(s)
		for tag in st {add(&to_set, tag)}
		for tag in sf {add(&from_set, tag)}
		if len(s.methods) > 0 {has_trampoline = true}
		for ex in s.exports {
			if ex.getter != "" || ex.setter != "" {has_trampoline = true; break}
		}
	}
	if len(to_set) == 0 && len(from_set) == 0 && !has_trampoline {return}

	w(b, "// ---- cached Variant constructors (shared by every section) ----\n")
	for tag in to_set {
		fmt.sbprintf(b, "@(private = \"file\")\n_to_%s: gdext.TypeFromVariantConstructorProc\n", tag)
	}
	for tag in from_set {
		fmt.sbprintf(b, "@(private = \"file\")\n_from_%s: gdext.VariantFromTypeConstructorProc\n", tag)
	}
	w(b, "@(private = \"file\")\n_ctors_ready: bool\n")
	w(b, "@(private = \"file\")\n_ensure_ctors :: proc \"contextless\" () {\n")
	w(b, "\tif _ctors_ready {return}\n")
	for tag in to_set {
		fmt.sbprintf(b, "\t_to_%s = gdext.get_variant_to_type_constructor(.%s)\n", tag, tag)
	}
	for tag in from_set {
		fmt.sbprintf(b, "\t_from_%s = gdext.get_variant_from_type_constructor(.%s)\n", tag, tag)
	}
	w(b, "\t_ctors_ready = true\n}\n\n")
}

// generate_all — the whole consolidated artifact for one scripts dir. `sections` is
// already in its final (source-filename) order; the caller owns the sorting so the
// same inputs always produce a byte-identical file.
generate_all :: proc(pkg: string, sections: []Gen_Section) -> string {
	b := strings.builder_make()
	w :: strings.write_string

	w(&b, "// Code generated by scriptgen. DO NOT EDIT.\n")
	fmt.sbprintf(
		&b, "// One artifact per scripts dir: %d script section(s), banner-marked below.\n",
		len(sections),
	)
	fmt.sbprintf(&b, "package %s\n\n", pkg)

	emit_imports(&b, sections)
	emit_ctors(&b, sections)

	for sec in sections {
		// The editor's deletion probe (core/reload.odin SECTION_BANNER) parses this
		// exact banner to find sections whose authored source is gone — keep in sync.
		fmt.sbprintf(&b, "// ==== %s (class %s) ====\n\n", sec.src_name, sec.script.class_name)
		emit_script(&b, sec.script)
	}
	return strings.to_string(b)
}

// One script's section: everything below the shared header/imports/ctors.
emit_script :: proc(b: ^strings.Builder, s: ^Script) {
	w :: strings.write_string
	cls := s.struct_name
	snake := to_snake(cls)

	// ---- lifecycle wrappers (plain proc -> rt.Lifecycle `proc \"c\"`) ----
	for lc in s.lifecycles {
		fname := fmt.tprintf("_%s_lc_%s", snake, lc.keyword)
		if lc.keyword == "process" || lc.keyword == "physics_process" {
			fmt.sbprintf(b, "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr, delta: f64) {{\n", fname)
			w(b, "\tcontext = rt.script_context()\n")
			if lc.has_delta {
				fmt.sbprintf(b, "\t%s(cast(^%s)self_raw, delta)\n}}\n\n", lc.proc_name, cls)
			} else {
				fmt.sbprintf(b, "\t%s(cast(^%s)self_raw)\n}}\n\n", lc.proc_name, cls)
			}
		} else {
			fmt.sbprintf(b, "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr) {{\n", fname)
			w(b, "\tcontext = rt.script_context()\n")
			if lc.keyword == "ready" && s.profile_type != "" {
				// gd:"profile=T" — the declaration form of session_profile_install:
				// wired BEFORE the game's ready so a ready that *_starts (role
				// launches do) already has the row type installed. The install's
				// own #asserts hold the POD/size contract against the named type.
				fmt.sbprintf(b, "\tksess.session_profile_install(&(cast(^%s)self_raw).%s, %s) // gd:\"profile\"\n", cls, s.profile_ses, s.profile_type)
			}
			fmt.sbprintf(b, "\t%s(cast(^%s)self_raw)\n}}\n\n", lc.proc_name, cls)
		}
	}

	// ---- method trampolines ----
	for m in s.methods {
		emit_method_trampoline(b, s, m)
	}

	// ---- getter/setter wrappers (richer-authoring #4) ----
	for ex in s.exports {
		if ex.getter != "" || ex.setter != "" {
			emit_accessor_wrappers(b, s, ex)
		}
	}

	// ---- typed signal emit helpers ----
	if len(s.signals) > 0 {
		emit_signal_helpers(b, s)
	}

	// ---- backing arrays + registration ----
	emit_registration(b, s)
}

// to_/from_ constructor tag sets needed across all methods.
collect_ctors :: proc(s: ^Script) -> (to_set: [dynamic]string, from_set: [dynamic]string) {
	add :: proc(set: ^[dynamic]string, tag: string) {
		for e in set {if e == tag {return}}
		append(set, tag)
	}
	for m in s.methods {
		for a in m.args {
			add(&to_set, ctor_tag(a.vi.enum_name))
		}
		if m.ret.kind != .Nil {
			add(&from_set, ctor_tag(m.ret.enum_name))
		}
	}
	// getter/setter wrappers (richer-authoring #4): a getter marshals field->Variant
	// (from_), a setter marshals Variant->field (to_).
	for ex in s.exports {
		if ex.getter != "" {
			add(&from_set, ctor_tag(ex.vi.enum_name))
		}
		if ex.setter != "" {
			add(&to_set, ctor_tag(ex.vi.enum_name))
		}
	}
	return
}

emit_method_trampoline :: proc(b: ^strings.Builder, s: ^Script, m: Method_Info) {
	w :: strings.write_string
	cls := s.struct_name
	snake := to_snake(cls)
	fname := fmt.tprintf("_%s_m_%s", snake, m.gd_name)

	fmt.sbprintf(b, "// %s(", m.gd_name)
	for a, i in m.args {
		if i > 0 {w(b, ", ")}
		fmt.sbprintf(b, "%s: %s", a.name, a.type_text)
	}
	w(b, ")")
	if m.ret.kind != .Nil {fmt.sbprintf(b, " -> %s", m.ret.enum_name)}
	w(b, "\n")

	fmt.sbprintf(b, "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {{\n", fname)
	// Arity guard (dll-boundary defense in depth; the core's inst_call checks too): the
	// unpack below reads exactly this many Variants — a short call must not read past them.
	if len(m.args) > 0 {
		fmt.sbprintf(b, "\tif argc < %d {{return}}\n", len(m.args))
	}
	w(b, "\tcontext = rt.script_context()\n")
	w(b, "\t_ensure_ctors()\n")
	fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)

	// Unpack args.
	call_args := make([dynamic]string)
	for a, i in m.args {
		tag := ctor_tag(a.vi.enum_name)
		switch a.vi.kind {
		case .Int:
			fmt.sbprintf(b, "\t_a%d: i64\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
			append(&call_args, fmt.tprintf("%s(_a%d)", a.type_text, i))
		case .Float:
			fmt.sbprintf(b, "\t_a%d: f64\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
			append(&call_args, fmt.tprintf("%s(_a%d)", a.type_text, i))
		case .Bool:
			fmt.sbprintf(b, "\t_a%d: bool\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
			append(&call_args, fmt.tprintf("_a%d", i))
		case .Other:
			fmt.sbprintf(b, "\t_a%d: %s\n\t_to_%s(&_a%d, args[%d])\n", i, a.type_text, tag, i, i)
			append(&call_args, fmt.tprintf("_a%d", i))
		case .Nil:
		}
	}

	// Call the user proc. A composed block method routes into &self.<path>, qualifies the proc with
	// its package, and (if it declared one) passes `self` as the owner; a direct method runs `self`.
	args_joined := strings.join(call_args[:], ", ")
	defer delete(args_joined)
	recv := len(m.path) > 0 ? fmt.tprintf("&self.%s", join_path(m.path)) : "self"
	qual := m.pkg_alias != "" ? fmt.tprintf("%s.", m.pkg_alias) : ""
	prefix := recv
	if m.owner {prefix = fmt.tprintf("%s, self", prefix)} // the block asked for its wielder
	if len(call_args) > 0 {prefix = fmt.tprintf("%s, %s", prefix, args_joined)}
	if m.ret.kind == .Nil {
		fmt.sbprintf(b, "\t%s%s(%s)\n", qual, m.proc_name, prefix)
	} else {
		fmt.sbprintf(b, "\t_r := %s%s(%s)\n", qual, m.proc_name, prefix)
		tag := ctor_tag(m.ret.enum_name)
		switch m.ret.kind {
		case .Int:
			fmt.sbprintf(b, "\t_rv := i64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
		case .Float:
			fmt.sbprintf(b, "\t_rv := f64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
		case .Bool, .Other:
			fmt.sbprintf(b, "\t_rv := _r\n\t_from_%s(ret, &_rv)\n", tag)
		case .Nil:
		}
	}
	w(b, "}\n\n")
}

// Getter/setter wrappers (richer-authoring #4). A getter wrapper marshals the author's
// `get_<x>(self) -> V` result into the out-Variant; a setter wrapper unpacks the in-Variant
// into a typed value and calls `set_<x>(self, v)`. These are the proc ptrs the core's
// inst_get/inst_set call instead of raw field access. Marshalling mirrors the method
// trampoline's arg/return conventions.
emit_accessor_wrappers :: proc(b: ^strings.Builder, s: ^Script, ex: Export_Info) {
	w :: strings.write_string
	cls := s.struct_name
	snake := to_snake(cls)
	tag := ctor_tag(ex.vi.enum_name)

	if ex.getter != "" {
		fmt.sbprintf(b, "// getter for @export `%s` -> %s\n", ex.name, ex.getter)
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_get_%s :: proc \"c\" (self_raw: rawptr, ret: gdext.VariantPtr) {{\n", snake, ex.name)
		w(b, "\tcontext = rt.script_context()\n")
		w(b, "\t_ensure_ctors()\n")
		fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)
		fmt.sbprintf(b, "\t_r := %s(self)\n", ex.getter)
		switch ex.vi.kind {
		case .Int:
			fmt.sbprintf(b, "\t_rv := i64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
		case .Float:
			fmt.sbprintf(b, "\t_rv := f64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
		case .Bool, .Other:
			fmt.sbprintf(b, "\t_rv := _r\n\t_from_%s(ret, &_rv)\n", tag)
		case .Nil:
		}
		w(b, "}\n\n")
	}

	if ex.setter != "" {
		fmt.sbprintf(b, "// setter for @export `%s` -> %s\n", ex.name, ex.setter)
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_set_%s :: proc \"c\" (self_raw: rawptr, value: gdext.VariantPtr) {{\n", snake, ex.name)
		w(b, "\tcontext = rt.script_context()\n")
		w(b, "\t_ensure_ctors()\n")
		fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)
		switch ex.vi.kind {
		case .Int:
			fmt.sbprintf(b, "\t_v: i64\n\t_to_%s(&_v, value)\n", tag)
			fmt.sbprintf(b, "\t%s(self, %s(_v))\n", ex.setter, ex.type_text)
		case .Float:
			fmt.sbprintf(b, "\t_v: f64\n\t_to_%s(&_v, value)\n", tag)
			fmt.sbprintf(b, "\t%s(self, %s(_v))\n", ex.setter, ex.type_text)
		case .Bool:
			fmt.sbprintf(b, "\t_v: bool\n\t_to_%s(&_v, value)\n", tag)
			fmt.sbprintf(b, "\t%s(self, _v)\n", ex.setter)
		case .Other:
			fmt.sbprintf(b, "\t_v: %s\n\t_to_%s(&_v, value)\n", ex.type_text, tag)
			fmt.sbprintf(b, "\t%s(self, _v)\n", ex.setter)
		case .Nil:
		}
		w(b, "}\n\n")
	}
}

// Typed emit helpers, one per signal FIELD: `<snake>_emit_<field>(self, payload…)`. Thin
// wrappers over the godot package's `gd.emit`/`gd.emit_args` (which own the emit_signal
// MethodBind caching + CallError handling); the value they add is the TYPED signature —
// the field name and payload types are compile-checked at every emit site. The returned
// Error surfaces a misspelled/unregistered signal; callers are free to ignore it.
emit_signal_helpers :: proc(b: ^strings.Builder, s: ^Script) {
	w :: strings.write_string
	cls := s.struct_name
	snake := to_snake(cls)

	w(b, "// ---- typed signal emit helpers (over gd.emit/gd.emit_args) ----\n")
	for sig in s.signals {
		fmt.sbprintf(b, "// emit the `%s` signal (declared by the %s.%s field) with its payload.\n", sig.name, cls, sig.name)
		fmt.sbprintf(b, "%s_emit_%s :: proc \"contextless\" (self: ^%s", snake, sig.name, cls)
		for a in sig.args {
			fmt.sbprintf(b, ", %s: %s", a.name, a.vi.native)
		}
		w(b, ") -> gd.Error {\n")
		if len(sig.args) == 0 {
			fmt.sbprintf(b, "\treturn gd.emit(self.owner, \"%s\")\n", sig.name)
		} else {
			for a, i in sig.args {
				fmt.sbprintf(b, "\t_v%d := %s\n\t_va%d := gd.variant_from(&_v%d)\n", i, a.name, i, i)
			}
			fmt.sbprintf(b, "\t_err := gd.emit_args(self.owner, \"%s\"", sig.name)
			for i in 0 ..< len(sig.args) {
				fmt.sbprintf(b, ", _va%d", i)
			}
			w(b, ")\n")
			for i in 0 ..< len(sig.args) {
				fmt.sbprintf(b, "\tgdext.variant_destroy(&_va%d)\n", i)
			}
			w(b, "\treturn _err\n")
		}
		w(b, "}\n\n")
	}
}

emit_registration :: proc(b: ^strings.Builder, s: ^Script) {
	w :: strings.write_string
	cls := s.struct_name
	snake := to_snake(cls)

	w(b, "// ---- registration ----\n")

	// Per-export field metadata reflection cannot see: source line, `///` doc, and the
	// getter/setter WRAPPER proc pointers for `get=`/`set=` tags. The Export/Onready
	// tables themselves are built at registration by the runtime reflection walk
	// (rt.register_class -> runtime/register_class.odin).
	if len(s.exports) > 0 {
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_fields := [?]rt.Field_Meta {{\n", snake)
		for ex in s.exports {
			fmt.sbprintf(b, "\t{{field = \"%s\", line = %d", ex.name, ex.line)
			if ex.doc != "" {
				// %q — user-authored text can carry quotes/backslashes.
				fmt.sbprintf(b, ", doc = %q", ex.doc)
			}
			if ex.res_class != "" {
				// Hint class derived from the typed resource handle (see parse.odin's
				// object-export block) — the runtime synthesizes resource=<this> from it.
				fmt.sbprintf(b, ", resource_class = \"%s\"", ex.res_class)
			}
			if ex.getter != "" {
				fmt.sbprintf(b, ", getter = _%s_get_%s", snake, ex.name)
			}
			if ex.setter != "" {
				fmt.sbprintf(b, ", setter = _%s_set_%s", snake, ex.name)
			}
			w(b, "},\n")
		}
		w(b, "}\n\n")
	}

	// per-method arg-type arrays
	for m in s.methods {
		if len(m.args) == 0 {continue}
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_%s_args := [?]gdext.Variant_Type{{", snake, m.gd_name)
		for a, i in m.args {
			if i > 0 {w(b, ", ")}
			w(b, a.vi.enum_name)
		}
		w(b, "}\n")
	}
	if len(s.methods) > 0 {
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_methods := [?]rt.Method {{\n", snake)
		for m in s.methods {
			// C-shaped table: pointer + count into the static per-method arg-type array.
			// An empty arg list stays at the zero value (nil + 0).
			args_ref := ""
			if len(m.args) > 0 {
				args_ref = fmt.tprintf(
					"arg_types = raw_data(_%s_%s_args[:]), arg_types_count = %d, ",
					snake,
					m.gd_name,
					len(m.args),
				)
			}
			fmt.sbprintf(
				b,
				"\t{{name = \"%s\", trampoline = _%s_m_%s, %sreturn_type = %s}},\n",
				m.gd_name,
				snake,
				m.gd_name,
				args_ref,
				m.ret.enum_name,
			)
		}
		w(b, "}\n\n")
	}

	// (No signal tables: signals are declared by typed struct fields, so the runtime
	// reflection walk builds the rt.Signal tables itself at registration.)

	// connections (@(gd_connect="signal") / @(gd_connect="Path:signal") declarations)
	if len(s.connections) > 0 {
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_connections := [?]rt.Connection {{\n", snake)
		for c in s.connections {
			switch {
			case c.indexed:
				fmt.sbprintf(b, "\t{{signal = \"%s\", method = \"%s\", path = \"%s\", indexed = true}},\n", c.signal, c.method, c.path)
			case c.path != "":
				fmt.sbprintf(b, "\t{{signal = \"%s\", method = \"%s\", path = \"%s\"}},\n", c.signal, c.method, c.path)
			case:
				fmt.sbprintf(b, "\t{{signal = \"%s\", method = \"%s\"}},\n", c.signal, c.method)
			}
		}
		w(b, "}\n\n")
	}

	// groups (//gd:group declarations) — joined by the core on READY.
	if len(s.groups) > 0 {
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_groups := [?]cstring {{", snake)
		for g, i in s.groups {
			if i > 0 {w(b, ", ")}
			fmt.sbprintf(b, "%q", g)
		}
		w(b, "}\n\n")
	}

	// rpcs (@(gd_rpc[="..."]) declarations) — per-method multiplayer RPC config.
	if len(s.rpcs) > 0 {
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_rpcs := [?]rt.Rpc {{\n", snake)
		for r in s.rpcs {
			fmt.sbprintf(
				b,
				"\t{{method = \"%s\", mode = %d, transfer = %d, call_local = %v, channel = %d}},\n",
				r.method,
				r.mode,
				r.transfer,
				r.call_local,
				r.channel,
			)
		}
		w(b, "}\n\n")
	}

	// kit/net replication descriptor (gd:"replicate" fields — friendslop toolkit).
	// The #asserts enforce the POD-only contract where the field TYPE is actually
	// known (this package's compile), failing the build with the field's name —
	// a tagged string/slice/map can never silently ship. `type_of(Cls{}.f)` is an
	// unevaluated expression: no instance is constructed.
	if len(s.replicates) > 0 {
		for r in s.replicates {
			// nearly_simple_compare = memcmp-safe layout INCLUDING floats (plain
			// simple_compare excludes them over NaN semantics — for shadow diffing,
			// bitwise is exactly right). Pointers are memcmp-safe but meaningless on
			// the wire, hence the explicit exclusion.
			te := field_type_expr(cls, r.path)
			fmt.sbprintf(
				b,
				"#assert(intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s), \"%s.%s: gd:\\\"replicate\\\" fields must be POD (ints/floats/bools/enums/vectors/fixed arrays — no strings, slices, maps, or pointers)\")\n",
				te, te, te, cls, join_path(r.path),
			)
		}
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_net_fields := [?]knet.Field_Desc {{\n", snake)
		for r in s.replicates {
			flags := ""
			switch {
			case r.interp && r.owner:
				flags = "{.Interp, .Owner_Stream}"
			case r.interp && r.predict:
				flags = "{.Interp, .Predicted}"
			case r.interp:
				flags = "{.Interp}"
			case r.owner:
				flags = "{.Owner_Stream}"
			case r.predict:
				flags = "{.Predicted}"
			case:
				flags = "{}"
			}
			lerp := len(r.lerp) > 0 ? fmt.tprintf(", lerp = %s", r.lerp) : ""
			if len(r.blend) > 0 {
				lerp = fmt.tprintf(", lerp = .Custom, blend = %s", r.blend)
			}
			wire := len(r.wire) > 0 ? fmt.tprintf(", wire = %s", r.wire) : ""
			if len(r.codec) > 0 {
				wire = fmt.tprintf(", wire = .Custom, codec = %s", r.codec)
			}
			slack := len(r.slack) > 0 ? fmt.tprintf(", slack = %s", r.slack) : ""
			glide := len(r.glide) > 0 ? fmt.tprintf(", glide = %s", r.glide) : ""
			cut := len(r.cut) > 0 ? fmt.tprintf(", cut = %s", r.cut) : ""
			fmt.sbprintf(
				b,
				"\t{{offset = %s, size = size_of(%s), name = %q, flags = %s%s%s%s%s%s}},\n",
				field_offset_expr(cls, r.path), field_type_expr(cls, r.path), join_path(r.path), flags, lerp, wire, slack, glide, cut,
			)
		}
		w(b, "}\n\n")
		fmt.sbprintf(
			b,
			"// kit/net replication descriptor for %s — consumed by the toolkit session layer.\n%s_net_desc := knet.Entity_Desc{{fields = _%s_net_fields[:], name = %q}}\n\n",
			cls, snake, snake, cls,
		)
	}

	// @(gd_command) dispatch + typed issue wrappers (friendslop toolkit).
	// Three artifacts per class: decode thunks (client and host execute a command
	// from byte-identical args — the thunk decodes, checks the reader, THEN calls
	// the author's proc), the Command_Desc table, and one `<proc>_cmd` wrapper per
	// command. The wrapper holds the ONLY role branch in the entire feature:
	// authority runs the proc directly (and fires the game's command hook, the
	// same cross-entity path client commands take); clients predict (iff
	// declared) and send. A name-paired `<wrapper>_then` consequence, when the
	// game declares one, fires on the authority right after the verb applies —
	// in the thunk for received commands, in the wrapper for the host's own —
	// with the issuer, the wire args, and the verb's returned payload.
	upper := strings.to_upper(snake)
	// A class that TICKS executes its verbs inside the tick pipeline instead
	// (kit/sim command scheduling) — the knet command loop's optimistic-apply
	// and the lane's resim would otherwise fight over one baseline. Its knet
	// command table and ctx-shaped wrappers are skipped whole; the sim block
	// below emits the tick-scheduled equivalents.
	is_sim := s.tick.proc_name != "" || len(s.block_ticks) > 0
	if len(s.commands) > 0 && !is_sim {
		w(b, "// ---- @(gd_command) dispatch + typed issue wrappers ----\n\n")
		w(b, "// Command wire ids — a stable FNV-1a hash of each verb's name, NOT a\n")
		w(b, "// position: reordering (or adding/removing) procs never renumbers the\n")
		w(b, "// wire, and a version-skewed peer's unknown id rejects instead of\n")
		w(b, "// misdispatching. Typed knet.Cmd_Id so a coop id can't be handed to a\n")
		w(b, "// sim verb's proc (it still crosses the wire as a plain u16).\n")
		for c in s.commands {
			fmt.sbprintf(b, "%s_CMD_%s :: knet.Cmd_Id(0x%x)\n", upper, strings.to_upper(c.name), cmd_wire_id(c.name))
		}
		w(b, "\n")
		for c in s.commands {
			// A composed command routes into the embedded field (`&self.gun`) and qualifies the
			// proc with its package (`play.gun_fire`); a direct one runs `runner_fire(self, …)`.
			recv := len(c.path) > 0 ? fmt.tprintf("&self.%s", join_path(c.path)) : "self"
			qual := c.pkg_alias != "" ? fmt.tprintf("%s.", c.pkg_alias) : ""
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_cmd_%s :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {{\n", snake, c.name)
			fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
			for a, i in c.args {
				fmt.sbprintf(b, "\t_a%d := knet.read_%s(r)\n", i, a.wire)
			}
			w(b, "\tif r.err {return false}\n")
			// The verb call — payload returns are captured for the consequence
			// (or blanked when nothing consumes them).
			if c.then_proc == "" && c.payload_count == 0 {
				fmt.sbprintf(b, "\treturn %s%s(%s", qual, c.proc_name, recv)
				if c.owner {w(b, ", self")} // the block asked for its wielder — pass the entity
				if c.wants_by {w(b, ", env.by")} // the declared issuer — ctx.me predicting, the sender on the host
				for _, i in c.args {
					fmt.sbprintf(b, ", _a%d", i)
				}
				w(b, ")\n}\n\n")
				continue
			}
			w(b, "\t_ok")
			for i in 0 ..< c.payload_count {
				if c.then_proc != "" {
					fmt.sbprintf(b, ", _p%d", i)
				} else {
					w(b, ", _") // payload declined — the block offered, nobody consumes
				}
			}
			fmt.sbprintf(b, " := %s%s(%s", qual, c.proc_name, recv)
			if c.owner {w(b, ", self")}
			if c.wants_by {w(b, ", env.by")}
			for _, i in c.args {
				fmt.sbprintf(b, ", _a%d", i)
			}
			w(b, ")\n")
			if c.then_proc != "" {
				// The consequence: authority-only, once, after the verb applied —
				// predictions and replays run this same thunk with authority=false.
				w(b, "\tif _ok && env.authority {\n")
				if c.then_game != "" {
					fmt.sbprintf(b, "\t\tassert(env.user != nil, \"%s needs the game pointer — session_set_factory's user is what consequences receive (tests: set ctx.game_user)\")\n", c.then_proc)
					fmt.sbprintf(b, "\t\t%s(cast(^%s)env.user, self, env.by", c.then_proc, c.then_game)
				} else {
					fmt.sbprintf(b, "\t\t%s(self, env.by", c.then_proc)
				}
				for _, i in c.args {
					fmt.sbprintf(b, ", _a%d", i)
				}
				for i in 0 ..< c.payload_count {
					fmt.sbprintf(b, ", _p%d", i)
				}
				w(b, ")\n\t}\n")
			}
			w(b, "\treturn _ok\n}\n\n")
		}

		fmt.sbprintf(b, "@(private = \"file\")\n_%s_commands := [?]knet.Command_Desc {{\n", snake)
		for c in s.commands {
			fmt.sbprintf(b, "\t{{name = %q, id = %s_CMD_%s, predict = %v, invoke = _%s_cmd_%s}},\n", c.name, upper, strings.to_upper(c.name), c.predict, snake, c.name)
		}
		w(b, "}\n\n")
	}

	// ---- `<field>_edge` halves: delta-lane change presentation ----
	// One thunk per declared half (cast, deref old, call the author's proc —
	// the new value is the field itself at fire time) plus the Edge_Desc
	// table wired into the command set; the session's per-frame edge pass
	// (knet.registry_edges_tick) does the rest — mirror, net diff, resync
	// silence — so no seen_* scratch and no re-seed handling exist to forget.
	has_edges := false
	for r in s.replicates {
		if r.edge_proc != "" {has_edges = true; break}
	}
	if has_edges {
		for r in s.replicates {
			if r.edge_proc == "" {continue}
			leaf := join_snake(r.path)
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_edge_%s :: proc(entity: rawptr, game: rawptr, old: rawptr) {{\n", snake, leaf)
			fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
			// The old-value cast derives its type from the field itself
			// (type_of) — no spelled type, so an imported block's field needs
			// no qualifier and no import here.
			if r.edge_game != "" {
				fmt.sbprintf(b, "\tassert(game != nil, \"%s needs the game pointer — session_set_factory's user is what edge halves receive\")\n", r.edge_proc)
				fmt.sbprintf(b, "\t%s(cast(^%s)game, self, (cast(^type_of(self.%s))old)^, self.%s)\n", r.edge_proc, r.edge_game, join_path(r.path), join_path(r.path))
			} else {
				fmt.sbprintf(b, "\t%s(self, (cast(^type_of(self.%s))old)^, self.%s)\n", r.edge_proc, join_path(r.path), join_path(r.path))
			}
			w(b, "}\n\n")
		}
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_edges := [?]knet.Edge_Desc {{\n", snake)
		for r, i in s.replicates {
			if r.edge_proc == "" {continue}
			fmt.sbprintf(b, "\t{{field = %d, fire = _%s_edge_%s}},\n", i, snake, join_snake(r.path))
		}
		w(b, "}\n\n")
	}

	// The command set is emitted for EVERY entity with a descriptor — desc-only
	// entities (no commands) used to force a hand-built set in the game. A
	// ticking class's set stays desc-only: its verbs ride the lane.
	if len(s.replicates) > 0 || len(s.commands) > 0 {
		cmds := len(s.commands) > 0 && !is_sim ? fmt.tprintf(", commands = _%s_commands[:]", snake) : ""
		net_id := s.net_id_type != "" ? fmt.tprintf(", net_id_offset = int(offset_of(%s, net_id))", cls) : ""
		edges := has_edges ? fmt.tprintf(", edges = _%s_edges[:]", snake) : ""
		fmt.sbprintf(
			b,
			"// kit/net command set for %s — the command table + the replicated-field descriptor.\n%s_command_set := knet.Command_Set{{entity_desc = &%s_net_desc%s%s%s}}\n\n",
			cls, snake, snake, cmds, net_id, edges,
		)
	}

	if len(s.commands) > 0 && !is_sim {
		for c in s.commands {
			// A composed command routes into the block and qualifies the proc; its wrapper is
			// named per-entity (`runner_gun_fire_cmd`) so two blocks of the same type never collide.
			recv := len(c.path) > 0 ? fmt.tprintf("&self.%s", join_path(c.path)) : "self"
			qual := c.pkg_alias != "" ? fmt.tprintf("%s.", c.pkg_alias) : ""
			wrapper := len(c.path) > 0 ? fmt.tprintf("%s_%s", snake, c.name) : c.proc_name
			fmt.sbprintf(b, "// Issue `%s` — the SAME call on every peer AND on both models, zero role\n", c.name)
			if c.predict {
				w(b, "// branches. Authority: runs the proc directly. Client: predicts optimistically\n")
				w(b, "// (rejection or a lost result auto-reverts the declared fields) and sends.\n")
			} else {
				w(b, "// branches. Authority: runs the proc directly. Client: sends (no prediction\n")
				w(b, "// declared); the state change arrives through normal replication.\n")
			}
			w(b, "// Returns a knet.Command_Outcome — .Applied (host accept), .Predicted (client\n")
			w(b, "// optimistic + sent), or .Rejected — the SAME meaning on every peer.\n")
			w(b, "// `knet.command_ok(r)` is the \"applied on my screen?\" check. The boot is the\n")
			w(b, "// game's one handle: promoting this class to the sim lane re-routes the verb\n")
			w(b, "// without touching a single issue site.\n")
			fmt.sbprintf(b, "%s_cmd :: proc(b: ^kboot.Boot, self: ^%s", wrapper, cls)
			for a in c.args {
				fmt.sbprintf(b, ", %s: %s", a.name, a.type_text)
			}
			w(b, ") -> knet.Command_Outcome {\n")
			w(b, "\tctx := &b.ses.ctx\n")
			w(b, "\tif ctx.is_authority {\n")
			w(b, "\t\t_ok")
			for i in 0 ..< c.payload_count {
				if c.then_proc != "" {
					fmt.sbprintf(b, ", _p%d", i)
				} else {
					w(b, ", _")
				}
			}
			fmt.sbprintf(b, " := %s%s(%s", qual, c.proc_name, recv)
			if c.owner {w(b, ", self")}
			if c.wants_by {w(b, ", ctx.me")} // the authority's own issue: the host player IS the issuer
			for a in c.args {
				fmt.sbprintf(b, ", %s", a.name)
			}
			w(b, ")\n")
			if c.then_proc != "" {
				// The host's own issue takes the same consequence path a client's
				// command does (fired in the receive thunk there).
				w(b, "\t\tif _ok {\n")
				if c.then_game != "" {
					fmt.sbprintf(b, "\t\t\tassert(ctx.game_user != nil, \"%s needs the game pointer — session_set_factory's user is what consequences receive (tests: set ctx.game_user)\")\n", c.then_proc)
					fmt.sbprintf(b, "\t\t\t%s(cast(^%s)ctx.game_user, self, ctx.me", c.then_proc, c.then_game)
				} else {
					fmt.sbprintf(b, "\t\t\t%s(self, ctx.me", c.then_proc)
				}
				for a in c.args {
					fmt.sbprintf(b, ", %s", a.name)
				}
				for i in 0 ..< c.payload_count {
					fmt.sbprintf(b, ", _p%d", i)
				}
				w(b, ")\n\t\t}\n")
			}
			fmt.sbprintf(b, "\t\tknet.command_hook_local(ctx, self.net_id, %s_CMD_%s, _ok) // same cross-entity path client commands take\n", upper, strings.to_upper(c.name))
			w(b, "\t\tif _ok {return .Applied}\n\t\treturn .Rejected\n\t}\n")
			fmt.sbprintf(b, "\tknet.command_begin(ctx, self.net_id, %s_CMD_%s)\n", upper, strings.to_upper(c.name))
			for a in c.args {
				fmt.sbprintf(b, "\tknet.write_%s(&ctx.msg, %s)\n", a.wire, a.name)
			}
			if c.predict {
				// The optimistic apply either held (.Predicted) or reverted (.Rejected).
				fmt.sbprintf(b, "\tif knet.command_issue(ctx, self, &%s_command_set, %s_CMD_%s) {{return .Predicted}}\n\treturn .Rejected\n}}\n\n", snake, upper, strings.to_upper(c.name))
			} else {
				// No local prediction runs, so a client can't locally reject — a
				// successful send is simply in flight; the host's verdict lands as state.
				fmt.sbprintf(b, "\t_ = knet.command_issue(ctx, self, &%s_command_set, %s_CMD_%s)\n\treturn .Predicted\n}}\n\n", snake, upper, strings.to_upper(c.name))
			}
		}
	}

	// ---- @(gd_message): typed app-message routes, written by nobody ----
	// The runtime (ksess.Typed_Route + session_app_listen + session_app_send_typed)
	// already decodes a POD payload for the handler; generated here is the WIRING:
	// one game-owned route per message, a `<class>_messages` proc the game calls
	// once in ready() to register them all, and `<proc>_send`/`<proc>_send_to`
	// doors. NOT lane-scoped — a coop game and a sim game get these identically
	// (messages ride the session's app router, not a lane).
	if len(s.messages) > 0 {
		w(b, "// ---- @(gd_message) typed app-message routes ----\n\n")
		for m in s.messages {
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_route: ksess.Typed_Route(%s)\n", m.proc_name, m.payload_type)
		}
		w(b, "\n")
		fmt.sbprintf(b, "// Register every @(gd_message) route on this class — call ONCE in ready()\n")
		fmt.sbprintf(b, "// (after boot_attach): `%s_messages(self, &self.ses)`. Routes survive\n", snake)
		w(b, "// *_start, so once is enough even across a back-to-menu rehost.\n")
		fmt.sbprintf(b, "%s_messages :: proc(self: ^%s, s: ^ksess.Session) {{\n", snake, cls)
		for m in s.messages {
			fmt.sbprintf(
				b,
				"\tksess.session_app_listen(s, %s, &_%s_route, self, proc(user: rawptr, from: knet.Player_Id, msg: %s) {{\n",
				m.tag_ident, m.proc_name, m.payload_type,
			)
			fmt.sbprintf(b, "\t\t%s(cast(^%s)user, from, msg)\n", m.proc_name, cls)
			w(b, "\t})\n")
		}
		w(b, "}\n\n")
		for m in s.messages {
			fmt.sbprintf(b, "// Send a %s under the %q route to `to_peer` (ksess.HOST_PEER, a seated\n", m.payload_type, m.name)
			w(b, "// peer, or ksess.BROADCAST_PEER); .Reliable unless you pass otherwise.\n")
			fmt.sbprintf(
				b,
				"%s_send :: proc(s: ^ksess.Session, msg: %s, to_peer: ksess.Peer_Id, channel := ksess.Channel.Reliable) {{\n",
				m.proc_name, m.payload_type,
			)
			fmt.sbprintf(b, "\tksess.session_app_send_typed(s, %s, msg, to_peer, channel)\n}}\n\n", m.tag_ident)
			fmt.sbprintf(b, "// Send a %s to a specific PLAYER (the seat is resolved on the authority).\n", m.payload_type)
			fmt.sbprintf(b, "%s_send_to :: proc(s: ^ksess.Session, player: knet.Player_Id, msg: %s) {{\n", m.proc_name, m.payload_type)
			fmt.sbprintf(b, "\tksess.session_app_send_typed_to(s, player, %s, msg)\n}}\n\n", m.tag_ident)
		}
	}

	// ---- @(gd_tick): the sim-lane step thunk + Sim_Set (kit/sim) ----
	// The thunk is the whole bridge: the lane drives entities through rawptrs
	// (live ticks AND resim replays take the identical path), the author's
	// proc stays typed and single-player-shaped. The input struct crosses the
	// wire raw, so the same POD contract as replicated fields is #asserted at
	// the consumer compile, naming the type.
	if s.tick.proc_name != "" || len(s.block_ticks) > 0 {
		w(b, "// ---- @(gd_tick) sim-lane step ----\n\n")
		if s.tick.input_type != "" {
			fmt.sbprintf(
				b,
				"#assert(intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s), \"%s: @(gd_tick) input structs must be POD (they cross the wire raw — no strings, slices, maps, or pointers)\")\n\n",
				s.tick.input_type, s.tick.input_type, s.tick.input_type, s.tick.input_type,
			)
		}
		fmt.sbprintf(b, "@(private = \"file\")\n_%s_tick_step :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {{\n", snake)
		if s.tick.proc_name != "" && s.tick.input_type != "" {
			w(b, "\tif input == nil {return} // no input drives this entity here this tick: coast\n")
		}
		consumed := s.tick.then_proc != "" || s.tick.fx_proc != ""
		need_self := consumed || len(s.block_ticks) > 0
		if need_self {
			fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
		}
		if s.tick.proc_name != "" {
			if s.tick.payload_count > 0 {
				w(b, "\t")
				for i in 0 ..< s.tick.payload_count {
					if i > 0 {w(b, ", ")}
					if consumed {
						fmt.sbprintf(b, "_p%d", i)
					} else {
						w(b, "_") // payload offered, nobody consumes (warned at build)
					}
				}
				w(b, " := ")
			} else {
				w(b, "\t")
			}
			if need_self {
				fmt.sbprintf(b, "%s(self", s.tick.proc_name)
			} else {
				fmt.sbprintf(b, "%s(cast(^%s)entity", s.tick.proc_name, cls)
			}
			if s.tick.input_type != "" {
				fmt.sbprintf(b, ", (cast(^%s)input)^", s.tick.input_type)
			}
			if s.tick.wants_lane {
				w(b, ", lane")
			}
			w(b, ")\n")
		}
		// Composed block ticks, AFTER the entity's own step in field order —
		// the entity writes intent first, blocks integrate.
		for bt in s.block_ticks {
			qual := bt.pkg_alias != "" ? fmt.tprintf("%s.", bt.pkg_alias) : ""
			fmt.sbprintf(b, "\t%s%s(&self.%s", qual, bt.proc_name, join_path(bt.path))
			if bt.wants_owner {
				w(b, ", self")
			}
			if bt.wants_lane {
				w(b, ", lane")
			}
			w(b, ")\n")
		}
		// The role gates the game used to hand-write, held HERE: the
		// consequence on the authority (which never resims), the fx on the
		// owning peer's live pass only — a replay re-runs the tick, never
		// the presentation, and never double-fires a consequence.
		if s.tick.then_proc != "" {
			// in_auth marks the authority-only context for lane_fact's
			// provenance-aware owner skip: a fact door announced from a `_then`
			// must INCLUDE the anchor's owner — their screen never ran this half.
			w(b, "\tif ksim.lane_is_authority(lane) {\n\t\tlane.in_auth = true\n\t\t")
			if s.tick.then_game != "" {
				fmt.sbprintf(b, "assert(ksim.lane_game(lane) != nil, \"%s needs the game pointer — lane_set_sim's user is what tick consequences receive\")\n\t\t", s.tick.then_proc)
				fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, owner", s.tick.then_proc, s.tick.then_game)
			} else {
				fmt.sbprintf(b, "%s(self, owner", s.tick.then_proc)
			}
			for i in 0 ..< s.tick.payload_count {
				fmt.sbprintf(b, ", _p%d", i)
			}
			w(b, ")\n\t\tlane.in_auth = false\n\t}\n")
		}
		if s.tick.fx_proc != "" && !s.tick.fx_mine {
			w(b, "\tif owner == ksim.lane_me(lane) && !lane.resimming {\n\t\t")
			if s.tick.fx_game != "" {
				fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self", s.tick.fx_proc, s.tick.fx_game)
			} else {
				fmt.sbprintf(b, "%s(self", s.tick.fx_proc)
			}
			for i in 0 ..< s.tick.payload_count {
				fmt.sbprintf(b, ", _p%d", i)
			}
			w(b, ")\n\t}\n")
		}
		if s.tick.fx_proc != "" && s.tick.fx_mine {
			// The EVERY-SCREEN form: on an event tick (any bool fact true) the
			// authority broadcasts the fact tuple (watchers fire it from the
			// watch clock — lane_fact), and the screens whose live pass just
			// simulated it fire inline: the owner's (mine=true) and the
			// authority's own view of everyone else (mine=false, live truth).
			w(b, "\tif ")
			first := true
			for wire, i in s.tick.payload_wires {
				if wire != "bool" {continue}
				if !first {w(b, " || ")}
				fmt.sbprintf(b, "_p%d", i)
				first = false
			}
			w(b, " { // an event tick: the facts present\n")
			w(b, "\t\tif ksim.lane_is_authority(lane) {\n")
			w(b, "\t\t\t_fw := knet.writer_make(64, context.temp_allocator)\n")
			for wire, i in s.tick.payload_wires {
				fmt.sbprintf(b, "\t\t\tknet.write_%s(&_fw, _p%d)\n", wire, i)
			}
			w(b, "\t\t\tksim.lane_fact(lane, entity, knet.writer_bytes(&_fw))\n")
			w(b, "\t\t}\n")
			w(b, "\t\tif !lane.resimming {\n")
			w(b, "\t\t\t_mine := owner == ksim.lane_me(lane)\n")
			w(b, "\t\t\tif _mine || ksim.lane_is_authority(lane) {\n\t\t\t\t")
			if s.tick.fx_game != "" {
				fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, _mine", s.tick.fx_proc, s.tick.fx_game)
			} else {
				fmt.sbprintf(b, "%s(self, _mine", s.tick.fx_proc)
			}
			for i in 0 ..< s.tick.payload_count {
				fmt.sbprintf(b, ", _p%d", i)
			}
			w(b, ")\n\t\t\t}\n\t\t}\n\t}\n")
		}
		w(b, "}\n\n")
		if s.tick.fx_proc != "" && s.tick.fx_mine {
			// The fx DECODE thunk (Sim_Set.fx): SIM_FACT bytes → typed facts →
			// the presentation half. The lane fires it on WATCHING screens when
			// the watch clock reaches the fact's tick; the live pass above
			// called the half directly.
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_fx :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {{\n", snake)
			fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
			w(b, "\tr := knet.reader_make(args)\n")
			for wire, i in s.tick.payload_wires {
				fmt.sbprintf(b, "\t_p%d := knet.read_%s(&r)\n", i, wire)
			}
			w(b, "\tif r.err {return}\n\t")
			if s.tick.fx_game != "" {
				fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, mine", s.tick.fx_proc, s.tick.fx_game)
			} else {
				fmt.sbprintf(b, "%s(self, mine", s.tick.fx_proc)
			}
			for i in 0 ..< s.tick.payload_count {
				fmt.sbprintf(b, ", _p%d", i)
			}
			w(b, ")\n}\n\n")
		}
		// ---- @(gd_command) on a ticking class: tick-scheduled verbs ----
		// The verb executes INSIDE the tick pipeline on both ends (kit/sim
		// command.odin): the client speculates at its next tick and resims
		// re-apply the captured patch; the authority executes at the stamped
		// tick and its `_then` fires there — the exec thunk holds that gate.
		if len(s.commands) > 0 {
			w(b, "// Command wire ids — a stable FNV-1a hash of each verb's name, NOT a\n")
			w(b, "// position: reordering procs never renumbers the wire. Typed ksim.Cmd_Id\n")
			w(b, "// so a sim verb id can't be handed to a coop command (still a plain u16\n")
			w(b, "// on the wire).\n")
			for c in s.commands {
				fmt.sbprintf(b, "%s_CMD_%s :: ksim.Cmd_Id(0x%x)\n", upper, strings.to_upper(c.name), cmd_wire_id(c.name))
			}
			w(b, "\n")
			for c in s.commands {
				recv := len(c.path) > 0 ? fmt.tprintf("&self.%s", join_path(c.path)) : "self"
				qual := c.pkg_alias != "" ? fmt.tprintf("%s.", c.pkg_alias) : ""
				fmt.sbprintf(b, "@(private = \"file\")\n_%s_simcmd_%s :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {{\n", snake, c.name)
				fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
				if len(c.args) > 0 {
					w(b, "\tr := knet.reader_make(args)\n")
					for a, i in c.args {
						fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, a.wire)
					}
					w(b, "\tif r.err {return false}\n")
				}
				w(b, "\t_ok")
				for i in 0 ..< c.payload_count {
					if c.then_proc != "" {
						fmt.sbprintf(b, ", _p%d", i)
					} else {
						w(b, ", _")
					}
				}
				fmt.sbprintf(b, " := %s%s(%s", qual, c.proc_name, recv)
				if c.owner {w(b, ", self")}
				if c.wants_by {w(b, ", by")} // the declared issuer — the lane resolved it (me speculating, the seat on the host)
				for _, i in c.args {
					fmt.sbprintf(b, ", _a%d", i)
				}
				w(b, ")\n")
				if c.apply_proc != "" {
					// The predicted-effect half, on the live pass — resims
					// re-run it alone, with the ledgered args.
					fmt.sbprintf(b, "\tif _ok {{%s(self", c.apply_proc)
					for _, i in c.args {
						fmt.sbprintf(b, ", _a%d", i)
					}
					w(b, ")}\n")
				}
				if c.then_proc != "" {
					// in_auth: a fact door announced from this authority-only
					// half must include the anchor's owner in the broadcast.
					w(b, "\tif _ok && ksim.lane_is_authority(lane) {\n\t\tlane.in_auth = true\n")
					if c.then_game != "" {
						fmt.sbprintf(b, "\t\tassert(ksim.lane_game(lane) != nil, \"%s needs the game pointer — lane_set_sim's user is what consequences receive\")\n", c.then_proc)
						fmt.sbprintf(b, "\t\t%s(cast(^%s)ksim.lane_game(lane), self, by", c.then_proc, c.then_game)
					} else {
						fmt.sbprintf(b, "\t\t%s(self, by", c.then_proc)
					}
					for _, i in c.args {
						fmt.sbprintf(b, ", _a%d", i)
					}
					for i in 0 ..< c.payload_count {
						fmt.sbprintf(b, ", _p%d", i)
					}
					w(b, ")\n\t\tlane.in_auth = false\n\t}\n")
				}
				w(b, "\treturn _ok\n}\n\n")
				if c.apply_proc != "" {
					// The resim's door into the apply half: decode the
					// LEDGERED args, re-run the effect against corrected
					// pre-state — never the verb, never its delta writes.
					fmt.sbprintf(b, "@(private = \"file\")\n_%s_simcmd_%s_apply :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane) {{\n", snake, c.name)
					fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
					if len(c.args) > 0 {
						w(b, "\tr := knet.reader_make(args)\n")
						for a, i in c.args {
							fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, a.wire)
						}
						w(b, "\tif r.err {return}\n")
					}
					fmt.sbprintf(b, "\t%s(self", c.apply_proc)
					for _, i in c.args {
						fmt.sbprintf(b, ", _a%d", i)
					}
					w(b, ")\n}\n\n")
				}
			}
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_sim_cmds := [?]ksim.Sim_Cmd {{\n", snake)
			for c in s.commands {
				aseat := c.any_seat ? ", any_seat = true" : ""
				if c.apply_proc != "" {
					fmt.sbprintf(b, "\t{{name = %q, id = %s_CMD_%s, exec = _%s_simcmd_%s, apply = _%s_simcmd_%s_apply%s}},\n", c.name, upper, strings.to_upper(c.name), snake, c.name, snake, c.name, aseat)
				} else {
					fmt.sbprintf(b, "\t{{name = %q, id = %s_CMD_%s, exec = _%s_simcmd_%s%s}},\n", c.name, upper, strings.to_upper(c.name), snake, c.name, aseat)
				}
			}
			w(b, "}\n\n")
			for c in s.commands {
				wrapper := len(c.path) > 0 ? fmt.tprintf("%s_%s", snake, c.name) : c.proc_name
				fmt.sbprintf(b, "// Issue `%s` — tick-scheduled on the sim lane: the SAME call on every peer\n", c.name)
				w(b, "// AND on both models, zero role branches. Your own entity speculates at your\n")
				w(b, "// next tick; the authority executes at the stamped tick and answers with a\n")
				w(b, "// verdict — a rejection unwinds the delta-lane writes and the reconcile\n")
				w(b, "// scrubs the predicted ones. Returns a knet.Command_Outcome: .Predicted =\n")
				w(b, "// scheduled and in flight on my screen (even the authority's own issue runs\n")
				w(b, "// at the stamped tick, never inline — .Applied is a coop-loop word); the\n")
				w(b, "// verdict is state. `knet.command_ok(r)` reads it, same as any coop verb.\n")
				fmt.sbprintf(b, "%s_cmd :: proc(b: ^kboot.Boot, self: ^%s", wrapper, cls)
				for a in c.args {
					fmt.sbprintf(b, ", %s: %s", a.name, a.type_text)
				}
				w(b, ") -> knet.Command_Outcome {\n")
				fmt.sbprintf(b, "\tassert(b.lane != nil, \"%s_cmd rides the sim lane — kboot.boot_lane(&boot, &lane) installs it\")\n", wrapper)
				if len(c.args) > 0 {
					w(b, "\t_w := knet.writer_make(64, context.temp_allocator)\n")
					for a in c.args {
						fmt.sbprintf(b, "\tknet.write_%s(&_w, %s)\n", a.wire, a.name)
					}
					fmt.sbprintf(b, "\tif ksim.lane_command(b.lane, self.net_id, %s_CMD_%s, knet.writer_bytes(&_w)) {{return .Predicted}}\n\treturn .Rejected\n}}\n\n", upper, strings.to_upper(c.name))
				} else {
					fmt.sbprintf(b, "\tif ksim.lane_command(b.lane, self.net_id, %s_CMD_%s, nil) {{return .Predicted}}\n\treturn .Rejected\n}}\n\n", upper, strings.to_upper(c.name))
				}
			}
		}

		in_size := s.tick.input_type != "" ? fmt.tprintf("size_of(%s)", s.tick.input_type) : "0"
		// The wire class the input rides (resolve_sim assigned it package-wide);
		// 0 for the primary or an inputless tick, emitted only when it differs.
		in_class := s.tick.input_type != "" && s.tick.input_class != 0 ? fmt.tprintf(", input_class = %d", s.tick.input_class) : ""
		contested := s.tick.contested ? ", contested = true" : ""
		sim_cmds := len(s.commands) > 0 ? fmt.tprintf(", commands = _%s_sim_cmds[:]", snake) : ""
		fx := s.tick.fx_mine ? fmt.tprintf(", fx = _%s_fx", snake) : ""
		fmt.sbprintf(
			b,
			"// kit/sim set for %s — ksim.lane_track_set(&lane, id, self, &%s_sim_set, owner)\n%s_sim_set := ksim.Sim_Set{{entity_desc = &%s_net_desc, tick = _%s_tick_step, input_size = %s%s%s%s%s}}\n\n",
			cls, snake, snake, snake, snake, in_size, in_class, contested, sim_cmds, fx,
		)
	}

	// ---- the standard transport forwards (a kboot.Boot field declares them) ----
	// Bodies for the Method_Info entries resolve_boot_forwards synthesized:
	// the four one-liners every session game used to copy, wired through the
	// boot's own wire/session pointers. Name-dispatched like any method, so
	// they survive hot reload; a hand-written same-name method suppressed the
	// synthesis entirely.
	for name in s.std_forwards {
		switch name {
		case "on_packet":
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_std_on_packet :: proc(self: ^%s, id: gd.Int, packet: gd.Packed_Byte_Array) {{\n\tnetgd.wire_receive(&self.%s.wire, id, packet)\n}}\n\n",
				snake, cls, s.boot_field,
			)
		case "on_peer_left":
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_std_on_peer_left :: proc(self: ^%s, id: gd.Int) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_peer_disconnected(self.%s.ses, ksess.Peer_Id(id))\n}}\n\n",
				snake, cls, s.boot_field, s.boot_field,
			)
		case "on_net_up":
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_std_on_net_up :: proc(self: ^%s) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_client_join(self.%s.ses)\n}}\n\n",
				snake, cls, s.boot_field, s.boot_field,
			)
		case "on_net_down":
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_std_on_net_down :: proc(self: ^%s) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_peer_disconnected(self.%s.ses, ksess.HOST_PEER)\n}}\n\n",
				snake, cls, s.boot_field, s.boot_field,
			)
		}
	}

	// ---- @(gd_sample)/@(gd_step): the lane wiring, written by nobody ----
	// The thunks hold the rawptr casts; `<snake>_lane_init` carries the input
	// size (from the package's tick input struct — resolve_sim pinned the
	// sample to it) and up to two world passes: @(gd_step) runs everywhere,
	// @(gd_step="authority") on the host alone. Game wiring is two lines:
	// `<snake>_lane_init(self, &self.lane, &self.ses, cfg = {...})` beside
	// boot_attach, then `kboot.boot_lane(&self.boot, &self.lane)`. (A
	// boot-routed authority step — s.step_boot — is not lane wiring; its
	// `<snake>_step` is emitted below with the session-event dispatch.)
	if len(s.input_classes) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot) {
		w(b, "// ---- @(gd_sample)/@(gd_step) lane wiring ----\n\n")
		// One typed device-read thunk per input class that has a sample.
		for ic in s.input_classes {
			if ic.sample != "" {
				fmt.sbprintf(
					b,
					"@(private = \"file\")\n_%s_lane_sample_%d :: proc(user: rawptr, tick: u64, dst: rawptr) {{\n\t%s(cast(^%s)user, tick, cast(^%s)dst)\n}}\n\n",
					snake, ic.class_id, ic.sample, cls, ic.type_name,
				)
			}
		}
		if s.step.proc_name != "" {
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_lane_step :: proc(user: rawptr, tick: u64) {{\n\t%s(cast(^%s)user%s)\n}}\n\n",
				snake, s.step.proc_name, cls, s.step.wants_tick ? ", tick" : "",
			)
		}
		if s.step_auth.proc_name != "" {
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_lane_step_auth :: proc(user: rawptr, tick: u64) {{\n\t%s(cast(^%s)user%s)\n}}\n\n",
				snake, s.step_auth.proc_name, cls, s.step_auth.wants_tick ? ", tick" : "",
			)
		}
		step_ref := s.step.proc_name != "" ? fmt.tprintf("_%s_lane_step", snake) : "nil"
		step_auth_ref := s.step_auth.proc_name != "" ? fmt.tprintf("_%s_lane_step_auth", snake) : "nil"
		// The primary class (id 0) rides lane_init + lane_set_sim; extras
		// register after. An inputless lane (no classes) passes size 0 / nil.
		primary_size := "0"
		primary_sample := "nil"
		if len(s.input_classes) > 0 {
			p := s.input_classes[0] // sorted by id: [0] is the primary
			primary_size = fmt.tprintf("size_of(%s)", p.type_name)
			if p.sample != "" {
				primary_sample = fmt.tprintf("_%s_lane_sample_%d", snake, p.class_id)
			}
		}
		fmt.sbprintf(
			b,
			"// The lane beside the session: the input classes, each with its typed\n"+
			"// sample, and up to two world passes (everywhere + authority) — all from\n"+
			"// the attributes. A single-input game registers one class; a game driving\n"+
			"// two entity kinds registers both. cfg tunes; zero = defaults. Each class\n"+
			"// stamps its input TYPE so lane_input_of resolves by type, not size.\n"+
			"%s_lane_init :: proc(self: ^%s, l: ^ksim.Lane, ses: ^ksess.Session, tag := ksim.SIM_TAG, cfg := ksim.Lane_Config{{}}) {{\n"+
			"\tksim.lane_init(l, ses, %s, tag, cfg)\n"+
			"\tksim.lane_set_sim(l, self, %s, %s, %s)\n",
			snake, cls, primary_size, primary_sample, step_ref, step_auth_ref,
		)
		if len(s.input_classes) > 0 && s.input_classes[0].type_name != "" {
			fmt.sbprintf(b, "\tksim.lane_class_set_type(l, 0, typeid_of(%s))\n", s.input_classes[0].type_name)
		}
		if len(s.input_classes) > 1 {
			for ic in s.input_classes[1:] {
				sample_ref := ic.sample != "" ? fmt.tprintf("_%s_lane_sample_%d", snake, ic.class_id) : "nil"
				fmt.sbprintf(b, "\tksim.lane_add_input_class(l, %d, size_of(%s), %s)\n", ic.class_id, ic.type_name, sample_ref)
				fmt.sbprintf(b, "\tksim.lane_class_set_type(l, %d, typeid_of(%s))\n", ic.class_id, ic.type_name)
			}
		}
		if len(s.facts) > 0 {
			fmt.sbprintf(b, "\tksim.lane_set_facts(l, _%s_fact_table[:])\n", snake)
		}
		w(b, "}\n\n")

		// ---- @(gd_fact): the world-pass fact doors, written by nobody ----
		// The author wrote `<event>_fx` (the presentation half); each door here
		// is the bare `<event>` name the sim calls where it DISCOVERS the event.
		// Every gate lives in the door, so the call site is role-free.
		if len(s.facts) > 0 {
			w(b, "// ---- @(gd_fact) world-pass facts: the announce doors ----\n")
			w(b, "// Stable wire ids — an FNV-1a hash of each event's name, never a position:\n")
			w(b, "// reordering declarations can't renumber the wire.\n")
			for f in s.facts {
				fmt.sbprintf(b, "FACT_%s :: u16(0x%x)\n", strings.to_upper(f.name), cmd_wire_id(f.name))
			}
			w(b, "\n")
			for f in s.facts {
				fmt.sbprintf(b, "// Announce %q — call it where the sim discovers the event (the world\n", f.name)
				w(b, "// pass, or an authority-only half). The door holds every gate: the\n")
				w(b, "// authority broadcasts to watching screens (they fire on the watch\n")
				w(b, "// clock, beside the delayed avatar), the causer's live pass fires now\n")
				w(b, "// (mine=true), a resim replay never re-fires, and screens with no part\n")
				if f.anchor != "" {
					w(b, "// in it stay silent. Announced on a CORPSE (an anchor the game already\n")
					w(b, "// despawned/untracked) it shows nowhere — not on the wire, not here, not\n")
					w(b, "// later on a watcher: a fact meant to be seen is announced BEFORE the despawn.\n")
				} else {
					w(b, "// in it stay silent.\n")
				}
				fmt.sbprintf(b, "%s :: proc(l: ^ksim.Lane", f.name)
				if f.anchor != "" {
					fmt.sbprintf(b, ", %s: ^%s", f.anchor_param, f.anchor)
				}
				for a, i in f.arg_names {
					fmt.sbprintf(b, ", %s: %s", a, f.arg_types[i])
				}
				w(b, ") {\n")
				if f.anchor != "" {
					// The corpse gate, FIRST: lane_fact skips the wire for an untracked
					// anchor and fire_facts drops a filed fact whose anchor died, but the
					// authority clause below would still present it on the host's own
					// screen — the one place nobody else sees. Nowhere, consistently.
					fmt.sbprintf(b, "\tif !ksim.lane_tracks_entity(l, %s) {{\n\t\treturn // a corpse: already untracked — nobody is told, so nobody shows it (the host included)\n\t}}\n", f.anchor_param)
				}
				w(b, "\tif ksim.lane_is_authority(l) {\n")
				w(b, "\t\t_fw := knet.writer_make(64, context.temp_allocator)\n")
				for a, i in f.arg_names {
					fmt.sbprintf(b, "\t\tknet.write_%s(&_fw, %s)\n", f.arg_wires[i], a)
				}
				anchor_ref := f.anchor != "" ? f.anchor_param : "nil"
				fmt.sbprintf(b, "\t\tksim.lane_fact(l, %s, knet.writer_bytes(&_fw), FACT_%s)\n", anchor_ref, strings.to_upper(f.name))
				w(b, "\t}\n")
				if f.anchor != "" {
					w(b, "\tif ksim.lane_live(l) {\n")
					fmt.sbprintf(b, "\t\t_owner := ksim.lane_owner_of(l, %s)\n", f.anchor_param)
					w(b, "\t\t_mine := _owner != knet.PLAYER_ID_INVALID && _owner == ksim.lane_me(l)\n")
					w(b, "\t\tif _mine || ksim.lane_is_authority(l) {\n")
					fmt.sbprintf(b, "\t\t\t%s(cast(^%s)ksim.lane_game(l), %s, _mine", f.fx_proc, cls, f.anchor_param)
					for a in f.arg_names {
						fmt.sbprintf(b, ", %s", a)
					}
					w(b, ")\n\t\t}\n\t}\n")
				} else {
					// Anchorless: the WORLD caused it — the authority's own live
					// simulation is the causer (mine=true on its screen alone);
					// every client presents from the broadcast, on the watch clock.
					w(b, "\tif ksim.lane_is_authority(l) && ksim.lane_live(l) {\n")
					fmt.sbprintf(b, "\t\t%s(cast(^%s)ksim.lane_game(l), true", f.fx_proc, cls)
					for a in f.arg_names {
						fmt.sbprintf(b, ", %s", a)
					}
					w(b, ")\n\t}\n")
				}
				w(b, "}\n\n")
				// The decode thunk (the lane's fact table): SIM_FACT bytes →
				// typed args → the half, fired when the watch clock arrives.
				fmt.sbprintf(b, "@(private = \"file\")\n_%s_fact_%s :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {{\n", snake, f.name)
				if len(f.arg_names) > 0 {
					w(b, "\tr := knet.reader_make(args)\n")
					for wr, i in f.arg_wires {
						fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, wr)
					}
					w(b, "\tif r.err {return}\n")
				}
				if f.anchor != "" {
					fmt.sbprintf(b, "\t%s(cast(^%s)ksim.lane_game(lane), cast(^%s)entity, mine", f.fx_proc, cls, f.anchor)
				} else {
					w(b, "\t_ = entity\n")
					fmt.sbprintf(b, "\t%s(cast(^%s)ksim.lane_game(lane), mine", f.fx_proc, cls)
				}
				for _, i in f.arg_names {
					fmt.sbprintf(b, ", _a%d", i)
				}
				w(b, ")\n}\n\n")
			}
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_fact_table := [?]ksim.Fact_Desc{{\n", snake)
			for f in s.facts {
				fmt.sbprintf(b, "\t{{id = FACT_%s, fx = _%s_fact_%s}},\n", strings.to_upper(f.name), snake, f.name)
			}
			w(b, "}\n\n")
		}
	}

	// ---- the BOOT-routed authority step (@(gd_step="authority"), no lane) ----
	// The coop game's fixed step: role gate, tick loop, and the same-frame edge
	// pass in ONE generated proc — the call site is role-free (`<snake>_step(self,
	// ticks)` with boot_pump's ticks, every peer; clients no-op). The edge pass
	// runs HERE because the authored pass mutates after boot_pump's automatic
	// one — a half that MOVES something the next tick reads must not land a
	// frame late (the pass is idempotent: everyone else pays a memcmp).
	if s.step_boot {
		fmt.sbprintf(
			b,
			"// Run this frame's authority steps — %s, `ticks` times, HOST only —\n"+
			"// then fire the authority's fresh edges same-frame. Call it right after\n"+
			"// boot_pump (or wherever your frame wants the world to advance):\n"+
			"//\n"+
			"//   events, marks, ticks := kboot.boot_pump(&self.%s, delta, now)\n"+
			"//   %s_step(self, ticks)\n"+
			"%s_step :: proc(self: ^%s, ticks: int) {{\n"+
			"\tif self.%s.ses == nil || !self.%s.ses.is_host {{return}}\n"+
			"\tfor _ in 0 ..< ticks {{\n"+
			"\t\t%s(self)\n"+
			"\t}}\n"+
			"\tksess.session_run_edges(self.%s.ses)\n"+
			"}}\n\n",
			s.step_auth.proc_name, s.boot_field, snake, snake, cls,
			s.boot_field, s.boot_field, s.step_auth.proc_name, s.boot_field,
		)
	}

	// ---- session-event dispatch: the declared halves, switched by nobody ----
	// One generated proc replaces the game shell's event-drain switch: each
	// declared `<game>_<event>` half fires wherever the event fires, and each
	// `_then` half fires on the AUTHORITY alone — the role gates live here,
	// never in game code. Single-role events get their annotation enforced at
	// dispatch too: a (client) event queued just BEFORE a takeover flipped
	// is_host dies at the gate instead of re-running takeover code (the double
	// transport-death signal queues Ev_Succession twice in one batch — the gate
	// is what makes the second one harmless). Call it with boot_pump's events,
	// any frame order you like: `<snake>_events(self, events)`.
	has_succ := s.succ_backup != "" || s.succ_took_over != "" || s.succ_wiped != "" || s.succ_migrating != ""
	if len(s.event_halves) > 0 || has_succ {
		fmt.sbprintf(
			b,
			"// Dispatch this frame's session events to the class's declared halves\n"+
			"// (role gates generated: client-only events skip a host — a takeover\n"+
			"// mid-batch kills the stale re-fire — and `_then` halves fire on the\n"+
			"// authority alone).\n"+
			"%s_events :: proc(self: ^%s, events: []ksess.Event) {{\n",
			snake, cls,
		)
		if len(s.event_halves) == 0 {
			w(b, "\t_ = events\n")
		} else {
			w(b, "\tfor ev in events {\n\t\t#partial switch e in ev {\n")
		}
		for h in s.event_halves {
			ev := SESSION_EVENTS[h.ev]
			args := strings.builder_make(context.temp_allocator)
			for p in ev.params {
				fmt.sbprintf(&args, ", %s", p.field)
			}
			fmt.sbprintf(b, "\t\tcase ksess.%s:\n", ev.variant)
			if len(ev.params) == 0 {
				w(b, "\t\t\t_ = e\n")
			}
			switch ev.role {
			case .Every:
				if h.bare != "" {
					fmt.sbprintf(b, "\t\t\t%s(self%s)\n", h.bare, strings.to_string(args))
				}
				if h.then_proc != "" {
					fmt.sbprintf(
						b,
						"\t\t\tif self.%s.ses != nil && self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
						s.boot_field, s.boot_field, h.then_proc, strings.to_string(args),
					)
				}
			case .Client:
				fmt.sbprintf(
					b,
					"\t\t\tif self.%s.ses != nil && !self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
					s.boot_field, s.boot_field, h.bare, strings.to_string(args),
				)
			case .Host:
				fmt.sbprintf(
					b,
					"\t\t\tif self.%s.ses != nil && self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
					s.boot_field, s.boot_field, h.bare, strings.to_string(args),
				)
			}
		}
		if len(s.event_halves) > 0 {
			w(b, "\t\t}\n\t}\n")
		}
		if has_succ {
			// The migration drain: boot_pump only NOTED a succession; the
			// mechanics run here, AFTER the words halves saw the old world.
			fmt.sbprintf(b, "\tkboot.boot_migrate_pending(&self.%s)\n", s.boot_field)
		}
		w(b, "}\n\n")
	}

	// ---- host migration: the declared halves -> kboot.boot_migration's table ----
	// The dance itself is the kit's (kit/boot/succession.odin): the torch on
	// Ev_Backup_Target, the takeover/chase fork, the census-driven wipe, the
	// chase caps and latches. These thunks are the game's four seams.
	if has_succ {
		w(b, "// ---- host migration (the `_backup`/`_took_over`/`_wiped`/`_migrating` halves) ----\n\n")
		if s.succ_backup != "" {
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_succ_backup :: proc(game: rawptr, w: ^knet.Writer) {{\n\t%s(cast(^%s)game, w)\n}}\n\n", snake, s.succ_backup, cls)
		}
		if s.succ_took_over != "" {
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_succ_took_over :: proc(game: rawptr, r: ^knet.Reader) {{\n\t%s(cast(^%s)game, r)\n}}\n\n", snake, s.succ_took_over, cls)
		}
		if s.succ_wiped != "" {
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_succ_wiped :: proc(game: rawptr) {{\n\t%s(cast(^%s)game)\n}}\n\n", snake, s.succ_wiped, cls)
		}
		if s.succ_migrating != "" {
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_succ_migrating :: proc(game: rawptr, step: kboot.Migrate_Step, target: string, try: int) {{\n\t%s(cast(^%s)game, step, target, try)\n}}\n\n", snake, s.succ_migrating, cls)
		}
		fmt.sbprintf(
			b,
			"// The migration hook table — pass to kboot.boot_migration(&self.%s, self,\n"+
			"// %s_succ_hooks) in ready, after boot_attach. Arms off the SESSION's backup\n"+
			"// config; the halves only supply bytes and words.\n",
			s.boot_field, snake,
		)
		fmt.sbprintf(b, "%s_succ_hooks := kboot.Succ_Hooks {{\n", snake)
		if s.succ_backup != "" {
			fmt.sbprintf(b, "\tbackup = _%s_succ_backup,\n", snake)
		}
		if s.succ_took_over != "" {
			fmt.sbprintf(b, "\ttook_over = _%s_succ_took_over,\n", snake)
		}
		if s.succ_wiped != "" {
			fmt.sbprintf(b, "\twiped = _%s_succ_wiped,\n", snake)
		}
		if s.succ_migrating != "" {
			fmt.sbprintf(b, "\tmigrating = _%s_succ_migrating,\n", snake)
		}
		w(b, "}\n\n")
	}

	// ---- entity kinds: `entity=Name:id` scene fields -> the kboot table ----
	// The tag on the exported PackedScene field is the whole factory
	// declaration: TYPE consts (the wire ids games used to hand-keep), typed
	// rt.script_of thunks, typed spawn/free hook thunks, and one
	// kboot.Entity_Kind row per tag. kit/boot's boot_entities drives it.
	if len(s.entities) > 0 {
		w(b, "// ---- entity kinds (gd:\"...,entity=Name:id\" scene fields) ----\n\n")
		w(b, "// The stable wire ids, named like the hand-kept consts they replace.\n")
		for e in s.entities {
			fmt.sbprintf(b, "%s_TYPE :: ksess.Entity_Type(%d)\n", strings.to_upper(to_snake(e.target)), e.type_id)
		}
		w(b, "\n")
		for e in s.entities {
			tsnake := to_snake(e.target)
			fmt.sbprintf(b, "@(private = \"file\")\n_%s_ent_make_%s :: proc(node: gd.Node) -> rawptr {{\n\treturn rt.script_of(node, %s)\n}}\n\n", snake, tsnake, e.target)
			if e.spawned != "" {
				fmt.sbprintf(b, "@(private = \"file\")\n_%s_ent_spawned_%s :: proc(game: rawptr, entity: rawptr, id: knet.Net_Id, owner: knet.Player_Id) {{\n\t%s(cast(^%s)game, cast(^%s)entity, id, owner)\n}}\n\n", snake, tsnake, e.spawned, cls, e.target)
			}
			if e.freed != "" {
				fmt.sbprintf(b, "@(private = \"file\")\n_%s_ent_freed_%s :: proc(game: rawptr, entity: rawptr, id: knet.Net_Id) {{\n\t%s(cast(^%s)game, cast(^%s)entity, id)\n}}\n\n", snake, tsnake, e.freed, cls, e.target)
			}
		}
		fmt.sbprintf(b, "// The factory table — %s_entities(self, &self.boot) installs it (below); the raw\n", snake)
		w(b, "// door is kboot.boot_entities(&self.boot, self, <table>[:], <events>).\n")
		fmt.sbprintf(b, "%s_entity_kinds := [?]kboot.Entity_Kind {{\n", snake)
		for e in s.entities {
			tsnake := to_snake(e.target)
			fmt.sbprintf(
				b,
				"\t{{type = %s_TYPE, name = %q, set = &%s_command_set, script_of = _%s_ent_make_%s, scene_offset = offset_of(%s, %s)",
				strings.to_upper(tsnake), e.target, tsnake, snake, tsnake, cls, e.field,
			)
			if e.spawned != "" {
				fmt.sbprintf(b, ", spawned = _%s_ent_spawned_%s", snake, tsnake)
			}
			if e.freed != "" {
				fmt.sbprintf(b, ", freed = _%s_ent_freed_%s", snake, tsnake)
			}
			if e.has_tick {
				// The class ticks: the row carries its Sim_Set, so boot_lane's
				// factory puts every spawn on the sim lane — no game code.
				fmt.sbprintf(b, ", sim_set = &%s_sim_set", tsnake)
			}
			if e.stream_hz > 0 {
				fmt.sbprintf(b, ", stream_hz = %d", e.stream_hz)
			}
			if e.avatar {
				w(b, ", avatar = true")
			}
			w(b, "},\n")
		}
		w(b, "}\n\n")

		// The install wrapper: the table AND the game's event dispatcher, handed
		// to boot in one typed call — the dispatcher is what lets the AUTHORITY's
		// own spawns be born at the send (boot_born: `<game>_entity_spawned`
		// fires inside boot_spawn_send, not from the next pump's batch). A class
		// that declares no session-event halves has no dispatcher to hand over;
		// it passes nil and keeps the queue path (nothing to dress at born).
		has_events := len(s.event_halves) > 0 || s.succ_backup != "" || s.succ_took_over != "" || s.succ_wiped != "" || s.succ_migrating != ""
		if has_events {
			fmt.sbprintf(
				b,
				"@(private = \"file\")\n_%s_events_thunk :: proc(game: rawptr, events: []ksess.Event) {{\n\t%s_events(cast(^%s)game, events)\n}}\n\n",
				snake, snake, cls,
			)
		}
		fmt.sbprintf(
			b,
			"// Install the generated entity factory on the boot (ready(), after boot_attach):\n"+
			"// the kind table above plus the class's event dispatcher, so the authority's own\n"+
			"// spawns are BORN AT THE SEND — `%s_entity_spawned` runs inside\n"+
			"// kboot.boot_spawn_send, before it returns, never a frame later.\n"+
			"%s_entities :: proc(self: ^%s, b: ^kboot.Boot) {{\n"+
			"\tkboot.boot_entities(b, self, %s_entity_kinds[:], %s)\n"+
			"}}\n\n",
			snake, snake, cls, snake, has_events ? fmt.tprintf("_%s_events_thunk", snake) : "nil",
		)

		// The typed census — the registry/boot ledgers queried back, so the
		// hand-kept `map[Net_Id]^T` + owner + avatar_of mirrors become the
		// exception (genuinely game-shaped bookkeeping), not the tax. A
		// hand-written proc of the same name suppresses that accessor
		// (resolve_census) and keeps its own meaning.
		for e in s.entities {
			tsnake := to_snake(e.target)
			if e.gen_of || e.gen_owned || e.gen_my || e.gen_ids {
				fmt.sbprintf(
					b,
					"// Census for %s: %s_of(id), my_%s(), %s_owned_by(player), %s_ids() —\n// no game-side maps for the common shape.\n",
					e.target, tsnake, tsnake, tsnake, tsnake,
				)
			}
			if e.gen_of {
				fmt.sbprintf(
					b,
					"%s_of :: proc(b: ^kboot.Boot, id: knet.Net_Id) -> (^%s, bool) {{\n\te, ok := kboot.boot_entity(b, id, %s_TYPE)\n\treturn cast(^%s)e, ok\n}}\n\n",
					tsnake, e.target, strings.to_upper(tsnake), e.target,
				)
			}
			if e.gen_owned {
				fmt.sbprintf(
					b,
					"%s_owned_by :: proc(b: ^kboot.Boot, owner: knet.Player_Id) -> (^%s, bool) {{\n\te, _, ok := kboot.boot_owned_entity(b, %s_TYPE, owner)\n\treturn cast(^%s)e, ok\n}}\n\n",
					tsnake, e.target, strings.to_upper(tsnake), e.target,
				)
			}
			if e.gen_my {
				my_body :=
					e.gen_owned \
					? fmt.tprintf("return %s_owned_by(b, b.ses.me)", tsnake) \
					: fmt.tprintf("e, _, ok := kboot.boot_owned_entity(b, %s_TYPE, b.ses.me)\n\treturn cast(^%s)e, ok", strings.to_upper(tsnake), e.target)
				fmt.sbprintf(
					b,
					"my_%s :: proc(b: ^kboot.Boot) -> (^%s, bool) {{\n\t%s\n}}\n\n",
					tsnake, e.target, my_body,
				)
			}
			if e.gen_ids {
				fmt.sbprintf(
					b,
					"%s_ids :: proc(b: ^kboot.Boot, allocator := context.temp_allocator) -> []knet.Net_Id {{\n\treturn kboot.boot_entity_ids(b, %s_TYPE, allocator)\n}}\n\n",
					tsnake, strings.to_upper(tsnake),
				)
			}
			if e.gen_spawn {
				// The typed spawn — the tag already knows the struct, so the
				// TYPE const and the rawptr cast stop existing at spawn sites.
				// Set the returned entity's fields, then boot_spawn_send(b, id).
				if e.has_tick {
					fmt.sbprintf(
						b,
						"// Typed spawn for %s (ticking: role-routed) — the host mints the real\n"+
						"// entity, a client a PREDICTED one flying this instant (a fired\n"+
						"// projectile; the authority's spawn rekeys it). Set the spawn fields,\n"+
						"// then kboot.boot_spawn_send(b, id).\n"+
						"%s_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID) -> (^%s, knet.Net_Id) {{\n"+
						"\te, id := kboot.boot_fire_spawn(b, %s_TYPE, owner)\n"+
						"\treturn cast(^%s)e, id\n"+
						"}}\n\n",
						e.target, tsnake, e.target, strings.to_upper(tsnake), e.target,
					)
				} else {
					fmt.sbprintf(
						b,
						"// Typed spawn for %s — authority code (clients hear the result as\n"+
						"// Ev_Spawned). Set the spawn fields, then kboot.boot_spawn_send(b, id).\n"+
						"%s_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID) -> (^%s, knet.Net_Id) {{\n"+
						"\tassert(b.ses != nil && b.ses.is_host, \"%s_spawn mints a REAL entity — only the authority spawns\")\n"+
						"\te, id := ksess.session_spawn_make(b.ses, %s_TYPE, owner)\n"+
						"\treturn cast(^%s)e, id\n"+
						"}}\n\n",
						e.target, tsnake, e.target, tsnake, strings.to_upper(tsnake), e.target,
					)
				}
			}
		}
	}

	// Generated acid probes — the driver's window into replicated state
	// (resolve_probes): probe_<kind>_<field>(id) with 0 = mine, plus
	// probe_<kind>_count() / probe_my_<kind>(). Registered @(gd_method)s, so
	// driver.gd reads what this peer SEES with no hand-written queries file;
	// a hand-written proc wearing a probe's name suppressed it upstream.
	if len(s.probes) > 0 {
		w(b, "// ---- generated acid probes (the test driver's replicated-state window) ----\n\n")
		for p in s.probes {
			upper_t := strings.to_upper(p.tsnake)
			switch p.form {
			case .Count:
				fmt.sbprintf(
					b,
					"@(private = \"file\")\n_%s_%s :: proc(self: ^%s) -> gd.Int {{\n\treturn gd.Int(len(kboot.boot_entity_ids(&self.%s, %s_TYPE)))\n}}\n\n",
					snake, p.name, cls, s.boot_field, upper_t,
				)
			case .My:
				fmt.sbprintf(
					b,
					"@(private = \"file\")\n_%s_%s :: proc(self: ^%s) -> gd.Int {{\n\tif self.%s.ses == nil {{return 0}}\n\t_, id, ok := kboot.boot_owned_entity(&self.%s, %s_TYPE, self.%s.ses.me)\n\treturn ok ? gd.Int(id) : 0\n}}\n\n",
					snake, p.name, cls, s.boot_field, s.boot_field, upper_t, s.boot_field,
				)
			case .Field:
				ret := p.float ? "gd.Float" : "gd.Int"
				value := fmt.tprintf("%s(e.%s)", ret, p.access)
				if p.boolish {
					value = fmt.tprintf("e.%s ? gd.Int(1) : gd.Int(0)", p.access)
				}
				fmt.sbprintf(
					b,
					"@(private = \"file\")\n_%s_%s :: proc(self: ^%s, id: gd.Int) -> %s {{\n"+
					"\tif self.%s.ses == nil {{return 0}}\n"+
					"\tnid := knet.Net_Id(id)\n"+
					"\tif id == 0 {{\n"+
					"\t\t_, mid, mok := kboot.boot_owned_entity(&self.%s, %s_TYPE, self.%s.ses.me)\n"+
					"\t\tif !mok {{return 0}}\n"+
					"\t\tnid = mid\n"+
					"\t}}\n"+
					"\traw, ok := kboot.boot_entity(&self.%s, nid, %s_TYPE)\n"+
					"\tif !ok {{return 0}}\n"+
					"\te := cast(^%s)raw\n"+
					"\treturn %s\n"+
					"}}\n\n",
					snake, p.name, cls, ret,
					s.boot_field,
					s.boot_field, upper_t, s.boot_field,
					s.boot_field, upper_t,
					p.target,
					value,
				)
			}
		}
	}

	// gd:"backup" host-local migration/save codec (version-hashed write/read).
	emit_backup(b, s)

	// lifecycle literal
	lc_lit := strings.builder_make()
	defer strings.builder_destroy(&lc_lit)
	if len(s.lifecycles) > 0 {
		strings.write_string(&lc_lit, "rt.Lifecycle{")
		for lc, i in s.lifecycles {
			if i > 0 {strings.write_string(&lc_lit, ", ")}
			fmt.sbprintf(&lc_lit, "%s = _%s_lc_%s", lc.keyword, snake, lc.keyword)
		}
		strings.write_string(&lc_lit, "}")
	}

	// @(init) registration. rt.register_class walks the struct's TYPE INFO (field
	// offsets/sizes/types + the gd:"..." tags) to build the Export/Onready tables at
	// startup; Class_Info carries only what reflection cannot see.
	fmt.sbprintf(b, "@(init)\n_register_%s :: proc \"contextless\" () {{\n", snake)
	fmt.sbprintf(b, "\trt.register_class(\n\t\t%s,\n", cls)
	w(b, "\t\trt.Class_Info {\n")
	fmt.sbprintf(b, "\t\t\tname = %q,\n", s.class_name)
	fmt.sbprintf(b, "\t\t\tbase = %q,\n", s.base)
	if len(s.lifecycles) > 0 {
		fmt.sbprintf(b, "\t\t\tlifecycle = %s,\n", strings.to_string(lc_lit))
	}
	// C-shaped member tables: pointer + count into the static backing arrays above.
	// An absent table stays at the Class_Info zero value (nil + 0).
	if len(s.methods) > 0 {
		fmt.sbprintf(b, "\t\t\tmethods = raw_data(_%s_methods[:]),\n", snake)
		fmt.sbprintf(b, "\t\t\tmethods_count = %d,\n", len(s.methods))
	}
	if len(s.connections) > 0 {
		fmt.sbprintf(b, "\t\t\tconnections = raw_data(_%s_connections[:]),\n", snake)
		fmt.sbprintf(b, "\t\t\tconnections_count = %d,\n", len(s.connections))
	}
	if len(s.groups) > 0 {
		fmt.sbprintf(b, "\t\t\tgroups = raw_data(_%s_groups[:]),\n", snake)
		fmt.sbprintf(b, "\t\t\tgroups_count = %d,\n", len(s.groups))
	}
	if len(s.rpcs) > 0 {
		fmt.sbprintf(b, "\t\t\trpcs = raw_data(_%s_rpcs[:]),\n", snake)
		fmt.sbprintf(b, "\t\t\trpcs_count = %d,\n", len(s.rpcs))
	}
	if len(s.exports) > 0 {
		fmt.sbprintf(b, "\t\t\tfields = raw_data(_%s_fields[:]),\n", snake)
		fmt.sbprintf(b, "\t\t\tfields_count = %d,\n", len(s.exports))
	}
	if s.tool {
		w(b, "\t\t\ttool = true,\n")
	}
	if s.icon != "" {
		fmt.sbprintf(b, "\t\t\ticon = %q,\n", s.icon)
	}
	if s.doc != "" {
		fmt.sbprintf(b, "\t\t\tdoc = %q,\n", s.doc)
	}
	w(b, "\t\t},\n")
	w(b, "\t)\n}\n")
}
