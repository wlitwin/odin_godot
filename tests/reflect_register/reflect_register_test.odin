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

import "core:testing"
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
