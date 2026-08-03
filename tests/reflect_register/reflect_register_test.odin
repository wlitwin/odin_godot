package reflect_register_test

// Standalone tests for the runtime-reflection registration walk
// (runtime/register_class.odin) — no Godot process needed.
//
//   odin test tests/reflect_register -collection:godot=$PWD -define:ODIN_TEST_THREADS=1
//
// Single-threaded (see run.sh): the walk appends into the runtime package's shared
// static pools, so concurrent test procs would race them.
//
// These tests are ALSO the byte-level parity check for the scriptgen migration: the
// asserted hint ints / hint_strings / offsets / sizes / defaults are exactly the
// values the old text-generated rt.Export tables carried.

import "base:runtime"
import "core:reflect"
import "core:strings"
import "core:testing"
import decl "godot:decl"
import "godot:gdext"
import gd "godot:godot"
import rt "godot:runtime"

// ---- fixtures ------------------------------------------------------------------

Basics :: struct {
	owner:    gd.Node,
	health:   i32 `gd:"export"`,
	x, y:     f32 `gd:"export"`,
	sprite:   gd.Node2d `gd:"onready=Sprite"`,
	label:    gd.Node `gd:"onready=HUD/Label"`,
	internal: bool, // untagged -> never a member
	value:    gd.Int `gd:"export"`,
}

// The owner slot is skipped by POSITION (field 0), even if someone tags it.
Tagged_Owner :: struct {
	owner: gd.Node `gd:"export"`,
	hp:    i32 `gd:"export"`,
}

Hints :: struct {
	owner:     gd.Node,
	health:    i32 `gd:"export,range=0:100:5"`,
	span:      f32 `gd:"export,range=0:1"`,
	mode:      i32 `gd:"export,enum=Idle:Walk:Run"`,
	bio:       gd.String `gd:"export,multiline"`,
	any_file:  gd.String `gd:"export,file"`,
	img_file:  gd.String `gd:"export,file=*.png:*.jpg"`,
	folder:    gd.String `gd:"export,dir"`,
	gfile:     gd.String `gd:"export,global_file"`,
	gdir:      gd.String `gd:"export,global_dir"`,
	texture:   gd.Object `gd:"export,resource=Texture2D"`,
	tags:      gd.Array `gd:"export,array=int"`,
	resources: gd.Array `gd:"export,array=Texture2D"`,
	rewards:   gd.Dictionary `gd:"export,dict=String;int"`,
	loot:      gd.Dictionary `gd:"export,dict=String;PackedScene"`,
	levels:    gd.Typed_Array(i64) `gd:"export"`,
	prices:    gd.Typed_Dictionary(gd.String, i64) `gd:"export"`,
}

Rich :: struct {
	owner: gd.Node2d,
	speed: f32 `gd:"export,group=Movement,default=200"`,
	jump:  f32 `gd:"export,default=12.5"`,
	title: gd.String `gd:"export,default=hero"`,
	alive: bool `gd:"export,default=true"`,
	count: i64 `gd:"export,subgroup=Stats,default=42"`,
	hp:    i32 `gd:"export,group=Combat,get=get_hp,set=set_hp"`,
}

Bad :: struct {
	owner:     gd.Node,
	mapping:   map[string]int `gd:"export"`,
	bogus:     i32 `gd:"export,sparkle=1"`,
	misspelt:  i32 `gd:"exprot"`,
	wired:     i32 `gd:"onready=Nope"`,
	bad_num:   i32 `gd:"export,default=abc"`,
	tex_arr:   gd.Typed_Array(gd.Texture2d) `gd:"export"`,
	two_hints: gd.Array `gd:"export,array=int,enum=A:B"`,
	orphan_get: i32 `gd:"export,get=get_orphan"`,
	fine:      i32 `gd:"export"`, // sanity: a good export among the bad ones survives
	synced:    i32 `gd:"replicate,interp"`, // kit/net tag: scriptgen's, NOT an error, NOT an export
}

// ---- script-resolving onready fixtures (`buddy: ^Ally `gd:"onready=..."``) -------

// The TARGET script struct — registered as a class in the fixup test.
Ally :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export"`,
}

// NOT a script class: a `^Not_A_Script` onready target must be refused at fixup.
Not_A_Script :: struct {
	x: int,
}

Script_Refs :: struct {
	owner:    gd.Node,
	buddy:    ^Ally `gd:"onready=Allies/Buddy"`,
	node_ref: gd.Node2d `gd:"onready=Sprite"`, // control: a plain handle beside it
}

Bad_Script_Ref :: struct {
	owner: gd.Node,
	oops:  ^Not_A_Script `gd:"onready=Nope"`,
}

// Array onready: fixed arrays of handles / script pointers with a `%d` path template.
Squadron :: struct {
	owner:  gd.Node,
	cards:  [4]gd.Node2d `gd:"onready=Deck/Card%d"`,
	allies: [2]^Ally `gd:"onready=Squad/Ally%d"`,
}

Bad_Arrays :: struct {
	owner:       gd.Node,
	no_tmpl:     [3]gd.Node2d `gd:"onready=Deck/Card"`, // array without a %d template
	tmpl_scalar: gd.Node2d `gd:"onready=Deck/Card%d"`,  // %d on a scalar field
}

// Scene-unique-name paths (`%Hud`): engine NodePath syntax, passed through verbatim.
// The trap case is a unique name starting with 'd' — `%dock` contains the bytes "%d"
// and must NOT read as an array template (segment-start '%' is always the marker).
Unique_Refs :: struct {
	owner: gd.Node,
	hud:   gd.Node2d `gd:"onready=%Hud"`,
	dock:  gd.Node2d `gd:"onready=%dock"`,            // unique name starting with 'd'
	deep:  gd.Node `gd:"onready=%dock/Label"`,        // unique segment, then a normal path
	slots: [3]gd.Node2d `gd:"onready=%dock/Slot%d"`,  // unique prefix + mid-name template
}

Bad_Unique :: struct {
	owner: gd.Node,
	mid:   gd.Node2d `gd:"onready=Deck/Ca%rd"`, // stray '%' inside a node name
	arr:   [2]gd.Node2d `gd:"onready=%dock"`,   // array whose only "%d" bytes are a unique marker
}

// `gd:"entity=Name:id"` — the one tag BOTH halves of the toolchain act on, and the
// only one that SYNTHESIZES its own leading tokens. It leads the tag because it is a
// wire declaration (a permanent public type id, a NET_FINGERPRINT input, a row in the
// generated factory table); it used to ride as a trailing spec of `export`, which
// meant every entity field in every game spelled out `export,resource=PackedScene`
// before getting to say the one thing the tag was for. An entity field is NECESSARILY
// an exported PackedScene — the scene IS what the factory instantiates — so the
// registrar puts both back. `deco` proves trailing export specs still ride behind, and
// `plain` is the control: the same hint, spelled the ordinary way, must be identical.
Entities :: struct {
	owner:     gd.Node,
	mob_scene: gd.Object `gd:"entity=Mob:3"`,
	deco:      gd.Object `gd:"entity=Chest:4,group=Spawns"`,
	plain:     gd.Object `gd:"export,resource=PackedScene"`,
}

@(test)
entity_first_synthesizes_its_export :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Entities, info("Entities"))
	// No "unknown gd tag" — a first token the registrar didn't know would land here.
	testing.expect_value(t, len(new_errors_since(before)), 0)
	// Three exports: the tag registers the property the author no longer writes.
	testing.expect_value(t, int(desc.exports_count), 3)

	ctl, ctl_ok := find_export(desc, "plain")
	testing.expectf(t, ctl_ok, "the control export is missing")
	if !ctl_ok {return}
	for name in ([]string{"mob_scene", "deco"}) {
		ex, ok := find_export(desc, name)
		testing.expectf(t, ok, "entity export %s missing — the synthesis dropped the field", name)
		if !ok {continue}
		// Byte-for-byte the hint `resource=PackedScene` produces: 17 is
		// Property_Hint.Resource_Type, and a drift here is an Inspector slot that
		// silently accepts the wrong resource.
		testing.expect_value(t, ex.hint, ctl.hint)
		testing.expect_value(t, string(ex.hint_string), string(ctl.hint_string))
		testing.expect_value(t, ex.type, ctl.type)
	}
	// Trailing export specs still ride behind the declaration.
	deco, _ := find_export(desc, "deco")
	testing.expect_value(t, string(deco.group), "Spawns")
}

// A hint-less OBJECT export is refused at registration: the Resource_Type hint is
// what switches on inst_set's refcount hold, so without one the field stores an
// unreferenced pointer that dangles once the loader's transient ref drops — a
// delayed SIGSEGV far from the declaration (the desert-shooter bullet_scene crash).
Dangling :: struct {
	owner: gd.Node,
	scene: gd.Object `gd:"export"`, // type-erased AND hint-less: refused, dropped
	fine:  i32 `gd:"export"`, // an innocent sibling must survive the refusal
}

@(test)
hintless_object_export_is_refused :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Dangling, info("Dangling"))
	errs := new_errors_since(before)
	testing.expectf(t, len(errs) == 1, "expected exactly one refusal, got %d", len(errs))
	_, registered := find_export(desc, "scene")
	testing.expect(t, !registered, "the dangling-prone export must be dropped, not registered hint-less")
	_, kept := find_export(desc, "fine")
	testing.expect(t, kept, "the refusal must not take the sibling export down with it")
}

// The other half: scriptgen derives the class from a TYPED handle
// (`gd.Texture2d` -> "Texture2D") and ships it in Field_Meta.resource_class; the
// walk synthesizes the same hint `resource=Texture2D` would have produced —
// byte-for-byte, proven against an explicitly-spelled control.
Derived :: struct {
	owner:   gd.Node,
	skin:    gd.Texture2d `gd:"export"`, // typed handle + meta -> synthesized hint
	control: gd.Object `gd:"export,resource=Texture2D"`,
}

@(test)
field_meta_resource_class_synthesizes_the_hint :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	fields := []rt.Field_Meta{{field = "skin", line = 1, resource_class = "Texture2D"}}
	desc := rt.reflect_class_desc(Derived, info("Derived", fields))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	skin, sok := find_export(desc, "skin")
	ctl, cok := find_export(desc, "control")
	testing.expect(t, sok && cok, "both exports must register")
	if !sok || !cok {return}
	testing.expect_value(t, skin.hint, ctl.hint)
	testing.expect_value(t, string(skin.hint_string), string(ctl.hint_string))
	testing.expect_value(t, skin.type, ctl.type)
}

// Signal fields (gd.Signal0 … Signal4): detected by TYPE (tag optional), the field name
// is the signal name, `args=` names the payload (else arg0…). `score` checks routing —
// signal fields and tagged exports coexist in one struct.
Signals :: struct {
	owner:     gd.Node,
	died:      gd.Signal0,
	collected: gd.Signal1(int) `gd:"args=value"`,
	hit:       gd.Signal2(i64, ^gd.Node2d) `gd:"args=amount,who"`,
	multi:     gd.Signal3(f32, gd.String, bool), // no tag -> synthesized arg0/arg1/arg2
	full:      gd.Signal4(int, int, int, int) `gd:"args=a,b,c,d"`,
	score:     i32 `gd:"export"`,
}

// SignalN — the struct-payload general form: the parameter is the argument LIST as a
// struct, its FIELD NAMES are the arg names (no tag). The escape past arity 4 (`blast`),
// the self-naming single-arg wrap (`moved`), and coexistence with the arity family on
// one class (`classic`).
Signals_N :: struct {
	owner:   gd.Node,
	blast:   gd.SignalN(struct {
		amount: int,
		who:    ^gd.Node2d,
		pos:    gd.Vector2,
		crit:   bool,
		tag:    gd.String,
	}), // 5 args — past the arity family's cap
	moved:   gd.SignalN(struct {
		pos: gd.Vector2,
	}), // single-field wrap: one .Vector2 arg named pos
	classic: gd.Signal1(int) `gd:"args=value"`,
	score:   i32 `gd:"export"`,
}

Bad_Signals_N :: struct {
	owner:     gd.Node,
	unwrapped: gd.SignalN(gd.Vector2), // $P itself Variant-mappable -> rejected with the two escapes
	unstruct:  gd.SignalN(int), // non-struct $P that is ALSO mappable -> same pointed rejection
	unmapped:  gd.SignalN(map[string]int), // non-struct, non-mappable $P -> plain-struct rule
	tagged:    gd.SignalN(struct {
		hp: int,
	}) `gd:"args=hp"`, // SignalN takes NO tag (field names are authoritative) — registers anyway, loudly
	bad_arg:   gd.SignalN(struct {
		m: map[string]int,
	}), // unmappable payload FIELD -> signal dropped, loudly
	fine:      gd.SignalN(struct {
		v: int,
	}), // sanity: a good SignalN among the bad ones survives
}

Bad_Signals :: struct {
	owner:    gd.Node,
	bad_arg:  gd.Signal1(map[string]int), // unsupported payload -> signal dropped, loudly
	bad_tag:  gd.Signal0 `gd:"export"`, // signals register by TYPE; only `args=` is legal
	miscount: gd.Signal1(int) `gd:"args=a,b"`, // 2 names, 1 parameter -> synthesized names kept
	stray:    i32 `gd:"args=x"`, // `args=` on a NON-signal field
	fine:     gd.Signal0, // sanity: a good signal among the bad ones survives
}

Exhaust :: struct {
	owner: gd.Node,
	e00:   i32 `gd:"export"`, e01: i32 `gd:"export"`, e02: i32 `gd:"export"`, e03: i32 `gd:"export"`,
	e04:   i32 `gd:"export"`, e05: i32 `gd:"export"`, e06: i32 `gd:"export"`, e07: i32 `gd:"export"`,
	e08:   i32 `gd:"export"`, e09: i32 `gd:"export"`, e10: i32 `gd:"export"`, e11: i32 `gd:"export"`,
	e12:   i32 `gd:"export"`, e13: i32 `gd:"export"`, e14: i32 `gd:"export"`, e15: i32 `gd:"export"`,
	e16:   i32 `gd:"export"`, e17: i32 `gd:"export"`, e18: i32 `gd:"export"`, e19: i32 `gd:"export"`,
	e20:   i32 `gd:"export"`, e21: i32 `gd:"export"`, e22: i32 `gd:"export"`, e23: i32 `gd:"export"`,
	e24:   i32 `gd:"export"`, e25: i32 `gd:"export"`, e26: i32 `gd:"export"`, e27: i32 `gd:"export"`,
	e28:   i32 `gd:"export"`, e29: i32 `gd:"export"`, e30: i32 `gd:"export"`, e31: i32 `gd:"export"`,
}

@(private)
dummy_get :: proc "c" (self: rawptr, ret: gdext.VariantPtr) {}
@(private)
dummy_set :: proc "c" (self: rawptr, value: gdext.VariantPtr) {}

@(private)
info :: proc(name: cstring, fields: []rt.Field_Meta = nil) -> rt.Class_Info {
	i := rt.Class_Info {
		name = name,
		base = "Node",
	}
	if len(fields) > 0 {
		i.fields = raw_data(fields)
		i.fields_count = i32(len(fields))
	}
	return i
}

@(private)
find_export :: proc(desc: rt.Class_Desc, name: string) -> (rt.Export, bool) {
	for ex in rt.desc_exports(desc) {
		if string(ex.name) == name {
			return ex, true
		}
	}
	return {}, false
}

@(private)
new_errors_since :: proc(n: int) -> []rt.Registration_Error {
	return rt.registration_errors()[n:]
}

// ---- tests -----------------------------------------------------------------------

@(test)
walk_basics :: proc(t: ^testing.T) {
	desc := rt.reflect_class_desc(Basics, info("Basics"))
	testing.expect_value(t, desc.size, size_of(Basics))
	testing.expect_value(t, desc.align, align_of(Basics))
	testing.expect_value(t, string(desc.name), "Basics")

	// exports: health, x, y (multi-name field expands), value — untagged/onready/owner skipped.
	testing.expect_value(t, int(desc.exports_count), 4)
	exs := rt.desc_exports(desc)
	testing.expect_value(t, string(exs[0].name), "health")
	testing.expect_value(t, exs[0].type, gdext.Variant_Type.Int)
	testing.expect_value(t, exs[0].offset, offset_of(Basics, health))
	testing.expect_value(t, exs[0].size, size_of(i32))
	testing.expect_value(t, exs[0].hint, 0)
	testing.expect_value(t, string(exs[0].hint_string), "")
	testing.expect_value(t, string(exs[1].name), "x")
	testing.expect_value(t, exs[1].type, gdext.Variant_Type.Float)
	testing.expect_value(t, exs[1].offset, offset_of(Basics, x))
	testing.expect_value(t, exs[1].size, size_of(f32))
	testing.expect_value(t, string(exs[2].name), "y")
	testing.expect_value(t, exs[2].offset, offset_of(Basics, y))
	testing.expect_value(t, string(exs[3].name), "value")
	testing.expect_value(t, exs[3].type, gdext.Variant_Type.Int)
	testing.expect_value(t, exs[3].size, size_of(gd.Int))

	// onready refs, in field order.
	testing.expect_value(t, int(desc.onready_count), 2)
	ors := rt.desc_onready(desc)
	testing.expect_value(t, ors[0].offset, offset_of(Basics, sprite))
	testing.expect_value(t, string(ors[0].path), "Sprite")
	testing.expect_value(t, ors[1].offset, offset_of(Basics, label))
	testing.expect_value(t, string(ors[1].path), "HUD/Label")
}

@(test)
owner_skipped_by_position :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Tagged_Owner, info("TaggedOwner"))
	testing.expect_value(t, int(desc.exports_count), 1)
	ex, ok := find_export(desc, "hp")
	testing.expect(t, ok, "hp must be exported")
	testing.expect_value(t, ex.offset, offset_of(Tagged_Owner, hp))
	testing.expect_value(t, len(new_errors_since(before)), 0)
}

@(test)
hint_matrix :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Hints, info("Hints"))
	testing.expect_value(t, len(new_errors_since(before)), 0)
	testing.expect_value(t, int(desc.exports_count), 16)

	// (field, Property_Hint int, hint_string) — the exact values scriptgen used to emit.
	check :: proc(t: ^testing.T, desc: rt.Class_Desc, name: string, hint: i64, hs: string) {
		ex, ok := find_export(desc, name)
		testing.expectf(t, ok, "export %s missing", name)
		if !ok {return}
		testing.expect_value(t, ex.hint, hint)
		testing.expect_value(t, string(ex.hint_string), hs)
	}
	check(t, desc, "health", 1, "0,100,5") // Range
	check(t, desc, "span", 1, "0,1")
	check(t, desc, "mode", 2, "Idle,Walk,Run") // Enum
	check(t, desc, "bio", 18, "") // Multiline_Text
	check(t, desc, "any_file", 13, "") // File
	check(t, desc, "img_file", 13, "*.png,*.jpg")
	check(t, desc, "folder", 14, "") // Dir
	check(t, desc, "gfile", 15, "") // Global_File
	check(t, desc, "gdir", 16, "") // Global_Dir
	check(t, desc, "texture", 17, "Texture2D") // Resource_Type
	check(t, desc, "tags", 23, "2:") // Type_String, Array[int]
	check(t, desc, "resources", 23, "24/17:Texture2D") // Array[Texture2D]
	check(t, desc, "rewards", 23, "4:;2:") // Dictionary[String,int]
	check(t, desc, "loot", 23, "4:;24/17:PackedScene")
	check(t, desc, "levels", 23, "2:") // Typed_Array(i64), type-driven
	check(t, desc, "prices", 23, "4:;2:") // Typed_Dictionary(String,i64), type-driven

	// typed-collection fields present as plain Array/Dictionary Variants.
	lv, _ := find_export(desc, "levels")
	testing.expect_value(t, lv.type, gdext.Variant_Type.Array)
	pr, _ := find_export(desc, "prices")
	testing.expect_value(t, pr.type, gdext.Variant_Type.Dictionary)
}

@(test)
groups_defaults_accessors :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	fields := []rt.Field_Meta{
		{field = "speed", line = 26},
		{field = "jump", line = 27, doc = "jump impulse"},
		{field = "hp", line = 30, getter = dummy_get, setter = dummy_set},
	}
	desc := rt.reflect_class_desc(Rich, info("Rich", fields))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	speed, _ := find_export(desc, "speed")
	testing.expect_value(t, string(speed.group), "Movement")
	testing.expect(t, speed.subgroup == nil, "speed has no subgroup")
	testing.expect_value(t, speed.has_default, true)
	testing.expect_value(t, speed.default_num, 200)
	testing.expect(t, speed.default_str == nil, "numeric default has no default_str")
	testing.expect_value(t, speed.line, 26)

	jump, _ := find_export(desc, "jump")
	testing.expect(t, jump.group == nil, "group markers do not repeat")
	testing.expect_value(t, jump.has_default, true)
	testing.expect_value(t, jump.default_num, 12.5)
	testing.expect_value(t, string(jump.doc), "jump impulse")

	title, _ := find_export(desc, "title")
	testing.expect_value(t, title.has_default, true)
	testing.expect_value(t, string(title.default_str), "hero")

	alive, _ := find_export(desc, "alive")
	testing.expect_value(t, alive.has_default, true)
	testing.expect_value(t, alive.default_num, 1)

	count, _ := find_export(desc, "count")
	testing.expect_value(t, string(count.subgroup), "Stats")
	testing.expect_value(t, count.default_num, 42)

	hp, _ := find_export(desc, "hp")
	testing.expect_value(t, string(hp.group), "Combat")
	testing.expect(t, hp.getter == dummy_get, "getter wired from Field_Meta")
	testing.expect(t, hp.setter == dummy_set, "setter wired from Field_Meta")
	testing.expect_value(t, hp.line, 30)
}

@(test)
signal_fields :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Signals, info("Signals"))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	// Signal fields never become exports; the tagged export still routes correctly.
	testing.expect_value(t, int(desc.exports_count), 1)
	_, sok := find_export(desc, "score")
	testing.expect(t, sok, "score must be exported")

	testing.expect_value(t, int(desc.signals_count), 5)
	sigs := rt.desc_signals(desc)

	// died: zero payload — empty (nil + 0) arg tables.
	testing.expect_value(t, string(sigs[0].name), "died")
	testing.expect_value(t, int(sigs[0].arg_types_count), 0)
	testing.expect_value(t, int(sigs[0].arg_names_count), 0)

	// collected(value: int) — `args=` names the payload.
	testing.expect_value(t, string(sigs[1].name), "collected")
	testing.expect_value(t, int(sigs[1].arg_types_count), 1)
	testing.expect_value(t, rt.signal_arg_types(sigs[1])[0], gdext.Variant_Type.Int)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[1])[0]), "value")

	// hit(amount: i64, who: ^Node2d) — an object-handle payload presents as .Object.
	testing.expect_value(t, string(sigs[2].name), "hit")
	testing.expect_value(t, int(sigs[2].arg_types_count), 2)
	testing.expect_value(t, rt.signal_arg_types(sigs[2])[0], gdext.Variant_Type.Int)
	testing.expect_value(t, rt.signal_arg_types(sigs[2])[1], gdext.Variant_Type.Object)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[2])[0]), "amount")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[2])[1]), "who")

	// multi — no tag, names synthesize as argN.
	testing.expect_value(t, string(sigs[3].name), "multi")
	testing.expect_value(t, int(sigs[3].arg_types_count), 3)
	testing.expect_value(t, rt.signal_arg_types(sigs[3])[0], gdext.Variant_Type.Float)
	testing.expect_value(t, rt.signal_arg_types(sigs[3])[1], gdext.Variant_Type.String)
	testing.expect_value(t, rt.signal_arg_types(sigs[3])[2], gdext.Variant_Type.Bool)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[3])[0]), "arg0")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[3])[1]), "arg1")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[3])[2]), "arg2")

	// full — max arity, all four names from the tag.
	testing.expect_value(t, string(sigs[4].name), "full")
	testing.expect_value(t, int(sigs[4].arg_types_count), 4)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[4])[3]), "d")
}

@(test)
signal_n_fields :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Signals_N, info("SignalsN"))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	// SignalN fields never become exports; the tagged export still routes correctly.
	testing.expect_value(t, int(desc.exports_count), 1)
	_, sok := find_export(desc, "score")
	testing.expect(t, sok, "score must be exported")

	testing.expect_value(t, int(desc.signals_count), 3)
	sigs := rt.desc_signals(desc)

	// blast — 5 args (past the arity family's cap); the payload struct's FIELD NAMES
	// are the arg names.
	testing.expect_value(t, string(sigs[0].name), "blast")
	testing.expect_value(t, int(sigs[0].arg_types_count), 5)
	testing.expect_value(t, rt.signal_arg_types(sigs[0])[0], gdext.Variant_Type.Int)
	testing.expect_value(t, rt.signal_arg_types(sigs[0])[1], gdext.Variant_Type.Object)
	testing.expect_value(t, rt.signal_arg_types(sigs[0])[2], gdext.Variant_Type.Vector2)
	testing.expect_value(t, rt.signal_arg_types(sigs[0])[3], gdext.Variant_Type.Bool)
	testing.expect_value(t, rt.signal_arg_types(sigs[0])[4], gdext.Variant_Type.String)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[0]), "amount")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[1]), "who")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[2]), "pos")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[3]), "crit")
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[4]), "tag")

	// moved — the single-field wrap: struct{pos: Vector2} -> one .Vector2 arg named pos.
	testing.expect_value(t, string(sigs[1].name), "moved")
	testing.expect_value(t, int(sigs[1].arg_types_count), 1)
	testing.expect_value(t, rt.signal_arg_types(sigs[1])[0], gdext.Variant_Type.Vector2)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[1])[0]), "pos")

	// classic — the arity family coexists with SignalN on one class, tags intact.
	testing.expect_value(t, string(sigs[2].name), "classic")
	testing.expect_value(t, int(sigs[2].arg_types_count), 1)
	testing.expect_value(t, rt.signal_arg_types(sigs[2])[0], gdext.Variant_Type.Int)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[2])[0]), "value")
}

@(test)
signal_n_error_paths :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Bad_Signals_N, info("BadSignalsN"))

	errs := new_errors_since(before)
	testing.expect_value(t, len(errs), 5)
	find :: proc(errs: []rt.Registration_Error, field: string) -> (rt.Registration_Error, bool) {
		for e in errs {
			if e.field != nil && string(e.field) == field {return e, true}
		}
		return {}, false
	}
	// Rule (b): a Variant-mappable $P is the one-arg-vs-arg-list ambiguity — rejected
	// with BOTH escapes spelled out.
	unwrapped, uok := find(errs, "unwrapped")
	testing.expect(t, uok, "mappable $P recorded")
	if uok {
		testing.expect_value(t, string(unwrapped.msg), "SignalN's parameter is the argument LIST as a struct, not a single payload type — use Signal1(Vector2) or SignalN(struct { pos: Vector2 })")
	}
	_, sok := find(errs, "unstruct")
	testing.expect(t, sok, "non-struct mappable $P recorded")
	// Rule (a): a non-struct, non-mappable $P gets the plain-struct rule.
	unmapped, mok := find(errs, "unmapped")
	testing.expect(t, mok, "non-struct $P recorded")
	if mok {
		testing.expect_value(t, string(unmapped.msg), "SignalN's parameter must be a plain struct — its field names/types are the signal's payload")
	}
	// Rule (c): SignalN takes no tag — field names are authoritative.
	_, tok := find(errs, "tagged")
	testing.expect(t, tok, "tag on a SignalN field recorded")
	// Rule (d): an unmappable payload FIELD drops the signal, loudly (existing path).
	_, bok := find(errs, "bad_arg")
	testing.expect(t, bok, "unsupported SignalN payload field recorded")

	// unwrapped/unstruct/unmapped/bad_arg are DROPPED; tagged registers anyway (loudly).
	testing.expect_value(t, int(desc.signals_count), 2)
	sigs := rt.desc_signals(desc)
	testing.expect_value(t, string(sigs[0].name), "tagged")
	testing.expect_value(t, int(sigs[0].arg_types_count), 1)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[0]), "hp")
	testing.expect_value(t, string(sigs[1].name), "fine")
	testing.expect_value(t, int(sigs[1].arg_types_count), 1)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[1])[0]), "v")
	testing.expect_value(t, int(desc.exports_count), 0)
}

@(test)
signal_error_paths :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Bad_Signals, info("BadSignals"))

	errs := new_errors_since(before)
	testing.expect_value(t, len(errs), 4)
	has :: proc(errs: []rt.Registration_Error, field: string) -> bool {
		for e in errs {
			if e.field != nil && string(e.field) == field {return true}
		}
		return false
	}
	testing.expect(t, has(errs, "bad_arg"), "unsupported signal payload recorded")
	testing.expect(t, has(errs, "bad_tag"), "non-args tag on a signal field recorded")
	testing.expect(t, has(errs, "miscount"), "args= count mismatch recorded")
	testing.expect(t, has(errs, "stray"), "args= on a non-signal field recorded")

	// bad_arg is DROPPED; bad_tag/miscount register anyway (loudly); stray never exports.
	testing.expect_value(t, int(desc.signals_count), 3)
	sigs := rt.desc_signals(desc)
	testing.expect_value(t, string(sigs[0].name), "bad_tag")
	testing.expect_value(t, string(sigs[1].name), "miscount")
	testing.expect_value(t, int(sigs[1].arg_types_count), 1)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[1])[0]), "arg0") // synth fallback
	testing.expect_value(t, string(sigs[2].name), "fine")
	testing.expect_value(t, int(desc.exports_count), 0)
}

@(test)
signal_fields_merge_with_info_table :: proc(t: ^testing.T) {
	// A hand-written Class_Info signal table (the raw escape hatch) folds into the same
	// contiguous run AFTER the walked signal fields.
	before := len(rt.registration_errors())
	extra := []rt.Signal{{name = "handwritten"}}
	inf := info("Signals")
	inf.signals = raw_data(extra)
	inf.signals_count = 1
	desc := rt.reflect_class_desc(Signals, inf)
	testing.expect_value(t, len(new_errors_since(before)), 0)
	testing.expect_value(t, int(desc.signals_count), 6)
	sigs := rt.desc_signals(desc)
	testing.expect_value(t, string(sigs[0].name), "died")
	testing.expect_value(t, string(sigs[5].name), "handwritten")
}

@(test)
variant_type_matrix :: proc(t: ^testing.T) {
	check :: proc(t: ^testing.T, id: typeid, want: gdext.Variant_Type) {
		got, ok := rt.variant_type_for(id)
		testing.expectf(t, ok, "type %v must map", id)
		testing.expect_value(t, got, want)
	}
	// scalar atoms
	check(t, i8, .Int)
	check(t, i16, .Int)
	check(t, i32, .Int)
	check(t, i64, .Int)
	check(t, int, .Int)
	check(t, u8, .Int)
	check(t, u16, .Int)
	check(t, u32, .Int)
	check(t, u64, .Int)
	check(t, uint, .Int)
	check(t, uintptr, .Int)
	check(t, gd.Int, .Int)
	check(t, f32, .Float)
	check(t, f64, .Float)
	check(t, gd.Float, .Float)
	check(t, gd.Real, .Float)
	check(t, bool, .Bool)
	check(t, gd.Bool, .Bool)
	// string family
	check(t, string, .String)
	check(t, gd.String, .String)
	check(t, gd.String_Name, .String_Name)
	check(t, gd.Node_Path, .Node_Path)
	// math structs
	check(t, gd.Vector2, .Vector2)
	check(t, gd.Vector2i, .Vector2i)
	check(t, gd.Rect2, .Rect2)
	check(t, gd.Rect2i, .Rect2i)
	check(t, gd.Vector3, .Vector3)
	check(t, gd.Vector3i, .Vector3i)
	check(t, gd.Transform2d, .Transform2d)
	check(t, gd.Vector4, .Vector4)
	check(t, gd.Vector4i, .Vector4i)
	check(t, gd.Plane, .Plane)
	check(t, gd.Quaternion, .Quaternion)
	check(t, gd.Aabb, .Aabb)
	check(t, gd.Basis, .Basis)
	check(t, gd.Transform3d, .Transform3d)
	check(t, gd.Projection, .Projection)
	check(t, gd.Color, .Color)
	// misc handles
	check(t, gd.Rid, .Rid)
	check(t, gd.Object, .Object) // rawptr alias — every class handle
	check(t, gd.Node2d, .Object)
	check(t, ^gd.Node2d, .Object) // pointer-to-handle
	check(t, gd.Texture2d, .Object) // Ref_Counted = ^rawptr
	check(t, gd.Callable, .Callable)
	check(t, gd.Signal, .Signal)
	check(t, gd.Dictionary, .Dictionary)
	check(t, gd.Array, .Array)
	check(t, gd.Typed_Array(i64), .Array)
	check(t, gd.Typed_Dictionary(gd.String, i64), .Dictionary)
	// packed arrays
	check(t, gd.Packed_Byte_Array, .Packed_Byte_Array)
	check(t, gd.Packed_Int32_Array, .Packed_Int32_Array)
	check(t, gd.Packed_Int64_Array, .Packed_Int64_Array)
	check(t, gd.Packed_Float32_Array, .Packed_Float32_Array)
	check(t, gd.Packed_Float64_Array, .Packed_Float64_Array)
	check(t, gd.Packed_String_Array, .Packed_String_Array)
	check(t, gd.Packed_Vector2_Array, .Packed_Vector2_Array)
	check(t, gd.Packed_Vector3_Array, .Packed_Vector3_Array)
	check(t, gd.Packed_Color_Array, .Packed_Color_Array)
	check(t, gd.Packed_Vector4_Array, .Packed_Vector4_Array)
	// not exportable
	_, ok := rt.variant_type_for(map[string]int)
	testing.expect(t, !ok, "map is not exportable")
	_, ok2 := rt.variant_type_for(complex64)
	testing.expect(t, !ok2, "complex64 is not exportable")
}

@(test)
error_paths :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Bad, info("Bad"))

	errs := new_errors_since(before)
	testing.expect_value(t, len(errs), 8)
	has :: proc(errs: []rt.Registration_Error, field: string) -> bool {
		for e in errs {
			if e.field != nil && string(e.field) == field {return true}
		}
		return false
	}
	testing.expect(t, has(errs, "mapping"), "unsupported export type recorded")
	testing.expect(t, has(errs, "bogus"), "unknown hint recorded")
	testing.expect(t, has(errs, "misspelt"), "unknown gd tag kind recorded")
	testing.expect(t, has(errs, "wired"), "onready on a non-object field recorded")
	testing.expect(t, has(errs, "bad_num"), "bad default literal recorded")
	testing.expect(t, has(errs, "tex_arr"), "typed-collection resource element recorded")
	testing.expect(t, has(errs, "two_hints"), "duplicate hint recorded")
	testing.expect(t, has(errs, "orphan_get"), "get= without a wrapper recorded")
	testing.expect(t, !has(errs, "synced"), "gd:\"replicate\" is a known (scriptgen-owned) tag — no error")
	for e in errs {
		testing.expect_value(t, string(e.class), "Bad")
		testing.expect(t, e.msg != nil, "every error carries a message")
	}

	// An unusable FIELD is dropped (mapping/misspelt/wired); a field whose SPEC failed
	// keeps its export minus the failed part (no default / no hint / no accessor) — the
	// error above is what keeps that from being silent.
	testing.expect_value(t, int(desc.exports_count), 6)
	testing.expect_value(t, int(desc.onready_count), 0)
	fine, fok := find_export(desc, "fine")
	testing.expect(t, fok, "good export among bad ones must survive")
	testing.expect_value(t, fine.offset, offset_of(Bad, fine))
	_, rok := find_export(desc, "synced")
	testing.expect(t, !rok, "replicate field is not an export (it belongs to kit/net)")
	_, mok := find_export(desc, "mapping")
	testing.expect(t, !mok, "unsupported-type export is dropped")
	_, sok := find_export(desc, "misspelt")
	testing.expect(t, !sok, "unknown-kind field is dropped")
	bad_num, bok := find_export(desc, "bad_num")
	testing.expect(t, bok, "field with a bad default keeps its export")
	testing.expect_value(t, bad_num.has_default, false)
	two, tok := find_export(desc, "two_hints")
	testing.expect(t, tok, "field with an extra hint keeps its first hint")
	testing.expect_value(t, two.hint, 23)
	testing.expect_value(t, string(two.hint_string), "2:")
	orphan, ook := find_export(desc, "orphan_get")
	testing.expect(t, ook, "get= without a wrapper keeps plain field access")
	testing.expect(t, orphan.getter == nil, "no getter wired without a wrapper")
	tex, xok := find_export(desc, "tex_arr")
	testing.expect(t, xok, "typed collection with a resource element stays an untyped Array export")
	testing.expect_value(t, tex.type, gdext.Variant_Type.Array)
	testing.expect_value(t, tex.hint, 0)
}

// ---- the export-spec vocabulary, closed ----------------------------------------
//
// WHAT THIS REPLACES. tests/scriptgen used to extract the case labels of
// walk_field's meta switch and parse_hint_spec's hint switch with awk and assert
// them equal to decl.EXPORT_SPECS. That was an admitted stopgap — it could SEE
// the two lists drift but not stop them, it broke on any reformatting of either
// switch, and it proved only that a label was TYPED, never that the spec worked.
// walk_field now dispatches ON the table, so the name set cannot drift; what is
// left to prove is the part a table can never assert about its consumer — that
// every name it declares actually reaches the Inspector as something.
//
// So: one field per (spec, legal form) the schema declares, run through the REAL
// registration walk, and zero recorded errors is the proof. The FORMS are here
// because the bare/value columns are load-bearing too (scriptgen refuses
// `multiline=true` and bare `range` off them), and a column that no fixture
// spells is a column nothing tests. A spec added to godot:decl fails this test
// until someone spells it below, and spelling it fails until the runtime means
// something by it.
Vocabulary :: struct {
	owner:      gd.Node,
	rng:        i32 `gd:"export,range=0:10,group=Numbers,subgroup=Bounds,default=3"`,
	choice:     i32 `gd:"export,enum=Idle:Walk"`,
	prose:      gd.String `gd:"export,multiline"`,
	any_file:   gd.String `gd:"export,file"`,
	png_file:   gd.String `gd:"export,file=*.png"`,
	any_dir:    gd.String `gd:"export,dir"`,
	level_dir:  gd.String `gd:"export,dir=levels"`,
	any_gfile:  gd.String `gd:"export,global_file"`,
	txt_gfile:  gd.String `gd:"export,global_file=*.txt"`,
	any_gdir:   gd.String `gd:"export,global_dir"`,
	tmp_gdir:   gd.String `gd:"export,global_dir=/tmp"`,
	texture:    gd.Object `gd:"export,resource=Texture2D"`,
	numbers:    gd.Array `gd:"export,array=int"`,
	prices:     gd.Dictionary `gd:"export,dict=String;int"`,
	routed:     i32 `gd:"export,get=get_routed,set=set_routed"`,
}

// Does Vocabulary spell `name`, in the bare form or the `name=VALUE` form? Reads
// the fixture's own tags rather than a second list beside it — a hand-kept
// "specs I remembered to cover" array is precisely the thing this file exists to
// stop existing. Allocation-free: the test runner tracks leaks.
@(private)
vocabulary_spells :: proc(name: string, with_value: bool) -> bool {
	st := runtime.type_info_base(type_info_of(Vocabulary)).variant.(runtime.Type_Info_Struct)
	for i in 0 ..< int(st.field_count) {
		body, has := reflect.struct_tag_lookup(reflect.Struct_Tag(st.tags[i]), "gd")
		if !has {continue}
		first := true
		for len(body) > 0 {
			piece := body
			if ci := strings.index_byte(body, ','); ci >= 0 {
				piece = body[:ci]
				body = body[ci + 1:]
			} else {
				body = ""
			}
			if first {
				first = false // the leading token is the field's KIND, not a spec
				continue
			}
			piece = strings.trim_space(piece)
			pname, had_value := piece, false
			if eq := strings.index_byte(piece, '='); eq >= 0 {
				pname = strings.trim_space(piece[:eq])
				had_value = true
			}
			if pname == name && had_value == with_value {return true}
		}
	}
	return false
}

@(test)
export_spec_vocabulary_is_implemented :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	fields := []rt.Field_Meta{{field = "routed", getter = dummy_get, setter = dummy_set}}
	desc := rt.reflect_class_desc(Vocabulary, info("Vocabulary", fields))

	// THE ASSERTION THAT MATTERS: every spec godot:decl declares, in every form it
	// declares legal, walked by the real registrar with nothing to report. A spec
	// the table names and the runtime has no arm for records "declared in
	// godot:decl but walk_field/parse_hint_spec has no arm for it" and lands here.
	for e in new_errors_since(before) {
		testing.expectf(t, false, "Vocabulary must register clean: %s.%s: %s", e.class, e.field, e.msg)
	}
	testing.expect_value(t, int(desc.exports_count), 15)

	for s in decl.EXPORT_SPECS {
		if s.bare {
			testing.expectf(
				t, vocabulary_spells(s.name, false),
				"godot:decl declares `%s` legal bare and no Vocabulary field spells it — add one, or drop the `bare` column",
				s.name,
			)
		}
		if s.value {
			testing.expectf(
				t, vocabulary_spells(s.name, true),
				"godot:decl declares `%s=VALUE` legal and no Vocabulary field spells it — add one, or drop the `value` column",
				s.name,
			)
		}
	}

	// The hints still had to LAND, not merely fail to complain: two spot checks
	// across the kind boundary, so a walk that silently classified everything as
	// Meta would pass the error count and fail here.
	rngx, _ := find_export(desc, "rng")
	testing.expect_value(t, rngx.hint, 1) // Range
	testing.expect_value(t, string(rngx.hint_string), "0,10")
	testing.expect_value(t, string(rngx.group), "Numbers")
	testing.expect_value(t, rngx.default_num, 3)
	dirx, _ := find_export(desc, "level_dir")
	testing.expect_value(t, dirx.hint, 14) // Dir, with a value behind it
	testing.expect_value(t, string(dirx.hint_string), "levels")
}

// Backing bytes for a "Duped" cstring that can NEVER pointer-match the "Duped"
// literal below — the cross-module reality (each module compiles its own literals),
// so the duplicate check must compare by VALUE.
@(private)
DUP_NAME_BYTES := [6]byte{'D', 'u', 'p', 'e', 'd', 0}

@(test)
duplicate_class_names :: proc(t: ^testing.T) {
	// register() semantics: keep-first + ONE recorded error naming the class; a later
	// same-name registration is dropped, distinct names are unaffected.
	rt.reflect_register_reset_for_tests()
	before := len(rt.registration_errors())

	rt.register_class(Basics, info("Duped"))
	dup := cstring(raw_data(DUP_NAME_BYTES[:]))
	rt.register_class(Tagged_Owner, info(dup)) // same NAME, different storage -> dropped
	rt.register_class(Tagged_Owner, info("Distinct")) // distinct name -> registers fine

	errs := new_errors_since(before)
	testing.expect_value(t, len(errs), 1)
	if len(errs) == 1 {
		testing.expect_value(t, string(errs[0].class), "Duped")
		testing.expect(t, errs[0].field == nil, "duplicate is a class-level error (no field)")
		testing.expect(
			t,
			errs[0].msg != nil && strings.contains(string(errs[0].msg), "duplicate class registration"),
			"error message names the problem",
		)
	}

	// Keep-first: the registry holds the FIRST "Duped" (Basics' desc) plus "Distinct".
	n: i32
	descs := rt.odin_scripts_manifest(&n)
	testing.expect_value(t, int(n), 2)
	testing.expect_value(t, string(descs[0].name), "Duped")
	testing.expect_value(t, descs[0].size, size_of(Basics)) // the first registration won
	testing.expect_value(t, descs[0].id, typeid_of(Basics))
	testing.expect_value(t, string(descs[1].name), "Distinct")

	rt.reflect_register_reset_for_tests()
}

@(test)
test_reset_clears_class_registry :: proc(t: ^testing.T) {
	// The test-only reset must clear the class registry too — otherwise duplicate-name
	// cases would poison every later test in this shared process.
	rt.reflect_register_reset_for_tests()
	rt.register_class(Basics, info("ResetProbe"))
	n: i32
	_ = rt.odin_scripts_manifest(&n)
	testing.expect_value(t, int(n), 1)
	rt.reflect_register_reset_for_tests()
	_ = rt.odin_scripts_manifest(&n)
	testing.expect_value(t, int(n), 0)
}

// ---- script-resolving onready (`buddy: ^Ally`) -----------------------------------

@(test)
walk_classifies_script_onready :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Script_Refs, info("ScriptRefs"))
	testing.expect_value(t, len(new_errors_since(before)), 0)
	testing.expect_value(t, int(desc.onready_count), 2)
	ors := rt.desc_onready(desc)
	// The ^Ally field: structural classification records the POINTEE typeid; the class
	// name stays nil until the manifest-time fixup (Ally's own `@(init)` may not have
	// run yet mid-walk, so the name is unknowable here).
	testing.expect_value(t, ors[0].offset, offset_of(Script_Refs, buddy))
	testing.expect_value(t, string(ors[0].path), "Allies/Buddy")
	testing.expect_value(t, string(ors[0].field), "buddy")
	testing.expect_value(t, ors[0].script_id, typeid_of(Ally))
	testing.expect(t, ors[0].script_class == nil, "class name resolves at fixup, not mid-walk")
	// The plain handle rides beside it, script-free.
	testing.expect_value(t, ors[1].offset, offset_of(Script_Refs, node_ref))
	testing.expect(t, ors[1].script_id == nil, "a handle field must not classify as a script ref")
}

@(test)
walk_classifies_onready_arrays :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Squadron, info("Squadron"))
	testing.expect_value(t, len(new_errors_since(before)), 0)
	testing.expect_value(t, int(desc.onready_count), 2)
	ors := rt.desc_onready(desc)
	// [4]gd.Node2d: a handle array — count recorded, template kept verbatim.
	testing.expect_value(t, ors[0].offset, offset_of(Squadron, cards))
	testing.expect_value(t, string(ors[0].path), "Deck/Card%d")
	testing.expect_value(t, int(ors[0].count), 4)
	testing.expect(t, ors[0].script_id == nil, "handle array must not classify as script")
	// [2]^Ally: a script array — ELEMENT classification (pointee typeid), count 2.
	testing.expect_value(t, ors[1].offset, offset_of(Squadron, allies))
	testing.expect_value(t, int(ors[1].count), 2)
	testing.expect_value(t, ors[1].script_id, typeid_of(Ally))

	// The template contract is enforced both ways: array without %d, %d on a scalar.
	before2 := len(rt.registration_errors())
	bad := rt.reflect_class_desc(Bad_Arrays, info("BadArrays"))
	errs := new_errors_since(before2)
	testing.expect_value(t, len(errs), 2)
	testing.expect_value(t, int(bad.onready_count), 0)
}

@(test)
walk_accepts_unique_name_paths :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Unique_Refs, info("UniqueRefs"))
	testing.expect_value(t, len(new_errors_since(before)), 0)
	testing.expect_value(t, int(desc.onready_count), 4)
	ors := rt.desc_onready(desc)
	testing.expect_value(t, string(ors[0].path), "%Hud")
	// `%dock` contains the bytes "%d" — segment-start '%' is the unique-name marker,
	// never a template: scalar classification, path kept verbatim.
	testing.expect_value(t, string(ors[1].path), "%dock")
	testing.expect_value(t, int(ors[1].count), 0)
	testing.expect_value(t, string(ors[2].path), "%dock/Label")
	// Array behind a deceptive unique prefix: the template is found MID-NAME.
	testing.expect_value(t, string(ors[3].path), "%dock/Slot%d")
	testing.expect_value(t, int(ors[3].count), 3)
	at, n, stray := rt.scan_onready_template("%dock/Slot%d")
	testing.expect_value(t, at, 10) // the core substitutes at Slot%d, not into %dock
	testing.expect_value(t, n, 1)
	testing.expect_value(t, stray, 0)

	// Refusals: a stray '%' inside a name; an array path whose only "%d" is a marker.
	before2 := len(rt.registration_errors())
	bad := rt.reflect_class_desc(Bad_Unique, info("BadUnique"))
	testing.expect_value(t, len(new_errors_since(before2)), 2)
	testing.expect_value(t, int(bad.onready_count), 0)
}

@(test)
onready_script_fixup :: proc(t: ^testing.T) {
	rt.reflect_register_reset_for_tests()
	before := len(rt.registration_errors())

	rt.register_class(Ally, info("Ally"))
	rt.register_class(Script_Refs, info("ScriptRefs"))
	rt.register_class(Bad_Script_Ref, info("BadScriptRef"))

	// The first manifest pull runs the fixup: every `@(init)` has run by then.
	n: i32
	descs := rt.odin_scripts_manifest(&n)
	testing.expect_value(t, int(n), 3)

	// ^Ally binds to Ally's registered class name and the entry stays live...
	ors := rt.desc_onready(descs[1])
	testing.expect_value(t, string(ors[0].script_class), "Ally")
	testing.expect(t, ors[0].path != nil, "resolved entry stays live")
	testing.expect(t, ors[1].script_class == nil, "the plain handle stays a node ref")

	// ...and ^Not_A_Script is refused + NEUTRALIZED (path nil'd, so the core can
	// never write a raw node pointer into the typed field).
	bors := rt.desc_onready(descs[2])
	testing.expect(t, bors[0].script_class == nil, "unregistered target must not resolve")
	testing.expect(t, bors[0].path == nil, "refused entry is neutralized")
	errs := new_errors_since(before)
	testing.expect_value(t, len(errs), 1)
	if len(errs) == 1 {
		testing.expect_value(t, string(errs[0].class), "BadScriptRef")
		testing.expect_value(t, string(errs[0].field), "oops")
	}
	rt.reflect_register_reset_for_tests()
}

@(test)
pool_exhaustion :: proc(t: ^testing.T) {
	// Runs on drained pools and restores them: the pools are package-global statics
	// shared by every test in this process.
	rt.reflect_register_reset_for_tests()
	saw_exhaustion := false
	// 33 registrations x 31 exports = 1023 < cap; the walk records exhaustion once the
	// export pool (1024) runs out on later registrations.
	for _ in 0 ..< 40 {
		_ = rt.reflect_class_desc(Exhaust, info("Exhaust"))
		for e in rt.registration_errors() {
			if e.msg != nil && string(e.msg) == "registration export pool exhausted — field dropped" {
				saw_exhaustion = true
			}
		}
		if saw_exhaustion {break}
	}
	testing.expect(t, saw_exhaustion, "export pool exhaustion must be recorded, not silent")
	rt.reflect_register_reset_for_tests()
}

// ---- nested members through `using` embeds (nested-replicate-fields) ------------
//
// export/onready/signal reached through `using` sub-structs register with their
// promoted (flat) names and cumulative offsets. A plain (non-`using`) embed is NOT
// recursed — scriptgen keeps its tagged members a build error until a naming
// convention is chosen, so the runtime walk must leave them alone.

Nested_Members :: struct {
	max_hp: i32 `gd:"export"`,
	sprite: gd.Node2d `gd:"onready=Body/Sprite"`,
	fired:  gd.Signal1(int) `gd:"args=amount"`,
	synced: i32 `gd:"replicate"`, // scriptgen's tag — never a runtime member, even nested
}

Deeper :: struct {
	using nm: Nested_Members, // two levels of `using`
	speed:    f32 `gd:"export"`,
}

Plain_Bundle :: struct {
	ignored: i32 `gd:"export"`, // NON-using embed below -> must NOT register
}

Composed :: struct {
	owner:   gd.Node,
	hp:      i32 `gd:"export"`,
	using d: Deeper, // using -> Deeper -> using nm -> Nested_Members
	plain:   Plain_Bundle, // plain embed: its export is invisible to the runtime walk
}

@(test)
nested_using_members_register :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Composed, info("Composed"))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	// Exports, depth-first: hp (top), max_hp + speed (through `using`, promoted leaf names),
	// and plain_ignored (through the PLAIN embed, namespaced `<field>_<leaf>`). The bare leaf
	// `ignored` is absent (namespaced), and `synced` is a replicate tag, never an export.
	testing.expect_value(t, int(desc.exports_count), 4)
	hp, hok := find_export(desc, "hp")
	testing.expect(t, hok, "hp exported")
	testing.expect_value(t, hp.offset, offset_of(Composed, hp))
	mx, mok := find_export(desc, "max_hp")
	testing.expect(t, mok, "max_hp exported through using")
	testing.expect_value(t, mx.offset, offset_of(Composed, max_hp)) // promoted -> cumulative offset
	sp, spok := find_export(desc, "speed")
	testing.expect(t, spok, "speed exported through using")
	testing.expect_value(t, sp.offset, offset_of(Composed, speed))
	pi, piok := find_export(desc, "plain_ignored")
	testing.expect(t, piok, "a plain embed's export registers under `<field>_<leaf>`")
	testing.expect_value(t, pi.offset, offset_of(Composed, plain) + offset_of(Plain_Bundle, ignored))
	_, iok := find_export(desc, "ignored")
	testing.expect(t, !iok, "the bare leaf name is not used for a plain embed member")
	_, syok := find_export(desc, "synced")
	testing.expect(t, !syok, "a replicate field is never a runtime member")

	// onready through using: promoted name, cumulative offset, path intact.
	testing.expect_value(t, int(desc.onready_count), 1)
	ors := rt.desc_onready(desc)
	testing.expect_value(t, ors[0].offset, offset_of(Composed, sprite))
	testing.expect_value(t, string(ors[0].path), "Body/Sprite")

	// signal through using: registered by its promoted name.
	testing.expect_value(t, int(desc.signals_count), 1)
	sigs := rt.desc_signals(desc)
	testing.expect_value(t, string(sigs[0].name), "fired")
	testing.expect_value(t, int(sigs[0].arg_types_count), 1)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[0]), "amount")
}

// ---- members through a PLAIN embed: namespaced `<field>_<leaf>` names -----------
//
// A plain (non-`using`) embed keeps the sub-object in the access path (`self.aim.x`), so
// its exported/onready/signal members register under the underscore-joined path — nested
// replicate is unaffected (it keys by offset). Mirrors register_class walk_members.

Aim :: struct {
	sensitivity: f32 `gd:"export,range=0.1:5"`,
	reticle:     gd.Node2d `gd:"onready=UI/Reticle"`,
	fired:       gd.Signal1(i64) `gd:"args=dir"`,
}

Fighter :: struct {
	owner: gd.Node,
	hp:    i32 `gd:"export"`,
	aim:   Aim, // PLAIN embed -> aim_sensitivity / aim_reticle / aim_fired
}

@(test)
nested_plain_members_register :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	desc := rt.reflect_class_desc(Fighter, info("Fighter"))
	testing.expect_value(t, len(new_errors_since(before)), 0)

	// export: hp (top) + aim_sensitivity (namespaced), cumulative offset.
	testing.expect_value(t, int(desc.exports_count), 2)
	sens, sok := find_export(desc, "aim_sensitivity")
	testing.expect(t, sok, "plain embed export registers as aim_sensitivity")
	testing.expect_value(t, sens.offset, offset_of(Fighter, aim) + offset_of(Aim, sensitivity))
	testing.expect_value(t, sens.hint, i64(1)) // Range hint survives through the embed
	_, bare := find_export(desc, "sensitivity")
	testing.expect(t, !bare, "the bare leaf name is not registered for a plain embed")

	// onready: cumulative offset, node path intact (its NAME isn't user-facing).
	testing.expect_value(t, int(desc.onready_count), 1)
	ors := rt.desc_onready(desc)
	testing.expect_value(t, ors[0].offset, offset_of(Fighter, aim) + offset_of(Aim, reticle))
	testing.expect_value(t, string(ors[0].path), "UI/Reticle")

	// signal: namespaced name, payload intact.
	testing.expect_value(t, int(desc.signals_count), 1)
	sigs := rt.desc_signals(desc)
	testing.expect_value(t, string(sigs[0].name), "aim_fired")
	testing.expect_value(t, int(sigs[0].arg_types_count), 1)
	testing.expect_value(t, string(rt.signal_arg_names(sigs[0])[0]), "dir")
}

Clash_Inner :: struct { x: i32 `gd:"export"` }

// A top-level field literally named `a_x` AND a plain embed `a` whose member is `x` both
// resolve to the registered name "a_x" — a collision Odin can't see (distinct paths).
Clash :: struct {
	owner: gd.Node,
	a_x:   i32 `gd:"export"`,
	a:     Clash_Inner, // a.x -> "a_x" collides with the top-level a_x
}

@(test)
nested_plain_name_collision_is_loud :: proc(t: ^testing.T) {
	before := len(rt.registration_errors())
	_ = rt.reflect_class_desc(Clash, info("Clash"))
	errs := new_errors_since(before)
	dup := false
	for e in errs {
		if e.field != nil && string(e.field) == "a_x" {dup = true}
	}
	testing.expect(t, dup, "a colliding nested member name must be reported, not silently last-wins")
}
