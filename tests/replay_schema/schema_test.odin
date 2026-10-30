package replay_schema_test

import "core:mem"
import "core:reflect"
import "core:testing"
import sc "godot:replay/schema"
import game "../../examples/replay_hello/shared/hello"

Mode :: enum u8 {Idle = 0, Attack = 7}

@(test)
bulk_canonical_copy_skips_private_middle_and_validates_before_commit :: proc(t:^testing.T) {
	Bulk :: struct {first:[512]u8,secret:[17]u8 `replay:"authority"`,aligned:u64be,last:[512]u8,mode:Mode}
	s:sc.Schema;options:=sc.DEFAULT_OPTIONS;options.projection=.Public
	testing.expect_value(t,sc.init(&s,Bulk,options).error,sc.Error.None);defer sc.destroy(&s)
	value:Bulk
	for &b,i in value.first {b=u8(i%251)}
	for &b in value.secret {b=0xee}
	value.aligned=u64be(0x0102030405060708)
	for &b,i in value.last {b=u8((i+7)%251)}
	value.mode=.Attack
	encoded:[1033]u8
	testing.expect_value(t,sc.encode(&s,value,encoded[:]).error,sc.Error.None)
	for b,i in encoded[:512] {testing.expect_value(t,b,u8(i%251))}
	for b,i in encoded[512:520] {testing.expect_value(t,b,u8(8-i))}
	for b,i in encoded[520:1032] {testing.expect_value(t,b,u8((i+7)%251))}
	testing.expect_value(t,encoded[1032],u8(7))
	decoded:Bulk;for &b in decoded.secret {b=0x55}
	testing.expect_value(t,sc.decode(&s,&decoded,encoded[:]).error,sc.Error.None)
	for b in decoded.secret {testing.expect_value(t,b,u8(0x55))}
	testing.expect_value(t,decoded.aligned,value.aligned)
	before:=decoded;encoded[1032]=6
	testing.expect_value(t,sc.decode(&s,&decoded,encoded[:]).error,sc.Error.Invalid_Value)
	testing.expect(t,reflect.equal(before,decoded))
	prior_bytes:=encoded;value.mode=Mode(6)
	testing.expect_value(t,sc.encode(&s,value,encoded[:]).error,sc.Error.Invalid_Value)
	testing.expect_value(t,encoded,prior_bytes)
}
Value :: struct {
	flag: bool,
	number: u32,
	aim: f32,
	mode: Mode,
	signed: i16,
	bytes: [2]u8,
	secret: u64 `replay:"authority"`,
}
Packed :: struct #packed {
	flag: bool,
	number: u32,
	aim: f32,
	mode: Mode,
	signed: i16,
	bytes: [2]u8,
	secret: u64 `replay:"authority"`,
}

value :: proc() -> Value {return {true, 0x12345678, 1.5, .Attack, -2, {9, 10}, 0x0102030405060708}}

@(test)
canonical_bytes_ignore_padding_and_roundtrip :: proc(t: ^testing.T) {
	a, b: sc.Schema
	testing.expect_value(t, sc.init(&a, Value).error, sc.Error.None)
	testing.expect_value(t, sc.init(&b, Packed).error, sc.Error.None)
	defer sc.destroy(&a)
	defer sc.destroy(&b)
	testing.expect_value(t, a.fingerprint, b.fingerprint)
	testing.expect_value(t, a.wire_size, 22)
	x := value()
	y := Packed{x.flag, x.number, x.aim, x.mode, x.signed, x.bytes, x.secret}
	encoded, packed: [22]u8
	testing.expect_value(t, sc.encode(&a, x, encoded[:]).error, sc.Error.None)
	testing.expect_value(t, sc.encode(&b, y, packed[:]).error, sc.Error.None)
	want := [22]u8{1, 0x78, 0x56, 0x34, 0x12, 0, 0, 0xc0, 0x3f, 7, 0xfe, 0xff, 9, 10, 8, 7, 6, 5, 4, 3, 2, 1}
	testing.expect_value(t, encoded, want)
	testing.expect_value(t, packed, want)
	restored: Value
	testing.expect_value(t, sc.decode(&a, &restored, encoded[:]).error, sc.Error.None)
	testing.expect(t, reflect.equal(restored, x))
}

@(test)
public_projection_excludes_authority_values_and_preserves_local_fields :: proc(t: ^testing.T) {
	options := sc.DEFAULT_OPTIONS
	options.projection = .Public
	s: sc.Schema
	testing.expect_value(t, sc.init(&s, Value, options).error, sc.Error.None)
	defer sc.destroy(&s)
	testing.expect_value(t, s.wire_size, 14)
	testing.expect_value(t, s.excluded_fields, 1)
	bytes: [14]u8
	sc.encode(&s, value(), bytes[:])
	restored := Value{secret = 99}
	sc.decode(&s, &restored, bytes[:])
	testing.expect_value(t, restored.secret, u64(99))
	testing.expect_value(t, restored.number, u32(0x12345678))
	other := value()
	other.secret = 0
	second: [14]u8
	sc.encode(&s, other, second[:])
	testing.expect_value(t, bytes, second)
}

@(test)
malformed_decode_and_invalid_encode_are_atomic :: proc(t: ^testing.T) {
	s: sc.Schema
	sc.init(&s, Value)
	defer sc.destroy(&s)
	bytes: [23]u8
	sc.encode(&s, value(), bytes[:22])
	baseline := Value{number = 99, secret = 13}
	for cut in 0 ..< 22 {
		output := baseline
		testing.expect_value(t, sc.decode(&s, &output, bytes[:cut]).error, sc.Error.Wrong_Size)
		testing.expect(t, reflect.equal(output, baseline))
	}
	output := baseline
	testing.expect_value(t, sc.decode(&s, &output, bytes[:]).error, sc.Error.Wrong_Size)
	indices := [3]int{0, 9, 8}
	for index in indices {
		mutated := bytes
		if index == 0 {mutated[0] = 2}
		if index == 9 {mutated[9] = 99}
		if index == 8 {mutated[5] = 0; mutated[6] = 0; mutated[7] = 0x80; mutated[8] = 0x7f}
		report := sc.decode(&s, &output, mutated[:22])
		testing.expect_value(t, report.error, sc.Error.Invalid_Value)
		testing.expect(t, len(report.path) > 0)
		testing.expect(t, reflect.equal(output, baseline))
	}
	bad := value()
	bad.mode = Mode(99)
	before := bytes
	testing.expect_value(t, sc.encode(&s, bad, bytes[:22]).error, sc.Error.Invalid_Value)
	testing.expect_value(t, bytes, before)
}

@(test)
endian_qualified_scalars_have_the_same_wire_meaning :: proc(t: ^testing.T) {
	Big :: struct {a: u16be, b: f32be, c: i32be}
	Native :: struct {a: u16, b: f32, c: i32}
	a, b: sc.Schema
	sc.init(&a, Big)
	sc.init(&b, Native)
	defer sc.destroy(&a)
	defer sc.destroy(&b)
	testing.expect_value(t, a.fingerprint, b.fingerprint)
	first, second: [10]u8
	x := Big{0x1234, 2.5, -3}
	sc.encode(&a, x, first[:])
	sc.encode(&b, Native{0x1234, 2.5, -3}, second[:])
	testing.expect_value(t, first, second)
	restored: Big
	sc.decode(&a, &restored, first[:])
	testing.expect(t, reflect.equal(x, restored))
}

@(test)
unsafe_or_ambiguous_types_report_the_field_path :: proc(t: ^testing.T) {
	Bad_Int :: distinct int
	types := [6]typeid{struct {value: Bad_Int}, struct {value: ^i32}, struct {value: []u8}, struct {value: string}, struct {value: proc()}, struct {value: map[u32]u32}}
	for kind, i in types {
		s: sc.Schema
		report := sc.init(&s, kind)
		testing.expect_value(t, report.error, i == 0 ? sc.Error.Platform_Integer : sc.Error.Unsupported_Type)
		testing.expect_value(t, report.path, "$.value")
		sc.destroy(&s)
	}
	s: sc.Schema
	bad := sc.init(&s, struct {field: u32 `replay:"typo"`})
	testing.expect_value(t, bad.error, sc.Error.Invalid_Tag)
	sc.destroy(&s)
	options := sc.DEFAULT_OPTIONS
	options.max_fields = 2
	testing.expect_value(t, sc.init(&s, [3]u8, options).error, sc.Error.Limit)
	sc.destroy(&s)
}

@(test)
schema_detects_enum_and_field_shape_changes :: proc(t: ^testing.T) {
	One :: enum u8 {None = 0, Fire = 1}
	Two :: enum u8 {None = 0, Fire = 2}
	a, b, c: sc.Schema
	sc.init(&a, struct {kind: One})
	sc.init(&b, struct {kind: Two})
	sc.init(&c, struct {renamed: One})
	defer sc.destroy(&a)
	defer sc.destroy(&b)
	defer sc.destroy(&c)
	testing.expect(t, a.fingerprint != b.fingerprint && a.fingerprint != c.fingerprint)
}

@(test)
game_world_roundtrip_and_custom_allocator_cleanup :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	s: sc.Schema
	testing.expect_value(t, sc.init(&s, game.World, allocator = mem.tracking_allocator(&track)).error, sc.Error.None)
	bytes := make([]u8, s.wire_size)
	defer delete(bytes)
	initial := game.initial()
	count := track.total_allocation_count
	testing.expect_value(t, sc.encode(&s, initial, bytes).error, sc.Error.None)
	got: game.World
	testing.expect_value(t, sc.decode(&s, &got, bytes).error, sc.Error.None)
	testing.expect(t, reflect.equal(initial, got))
	testing.expect_value(t, track.total_allocation_count, count)
	sc.destroy(&s)
	testing.expect_value(t, track.current_memory_allocated, i64(0))
}

@(test)
bit_sets_and_enumerated_arrays_have_canonical_meaning :: proc(t: ^testing.T) {
	Flag :: enum {A = 0, C = 2}
	Signed :: enum i16 {None = -1, Some = 2}
	Data :: struct {signed: Signed, flags: bit_set[Flag; u16], values: #sparse [Flag]u8}
	s: sc.Schema
	testing.expect_value(t, sc.init(&s, Data).error, sc.Error.None)
	defer sc.destroy(&s)
	x := Data{signed = .None, flags = {.A, .C}}
	x.values[.A], x.values[.C] = 7, 9
	bytes := make([]u8, s.wire_size)
	defer delete(bytes)
	testing.expect_value(t, sc.encode(&s, x, bytes).error, sc.Error.None)
	testing.expect_value(t, bytes[0], u8(0xff))
	testing.expect_value(t, bytes[2], u8(5))
	got: Data
	testing.expect_value(t, sc.decode(&s, &got, bytes).error, sc.Error.None)
	testing.expect(t, reflect.equal(got, x))
	bytes[2] = 2 // unnamed gap in the flag enum
	testing.expect_value(t, sc.decode(&s, &got, bytes).error, sc.Error.Invalid_Value)
	testing.expect(t, reflect.equal(got, x))
}

@(test)
envelope_checks_schema_context_and_corruption_before_commit :: proc(t: ^testing.T) {
	s: sc.Schema
	sc.init(&s, Value)
	defer sc.destroy(&s)
	bytes := make([]u8, sc.HEADER_BYTES + s.wire_size)
	defer delete(bytes)
	meta := sc.Envelope_Meta{kind = 4, epoch = 3, tick = 42, content = 55}
	testing.expect_value(t, sc.pack(&s, value(), meta, bytes).error, sc.Error.None)
	got := Value{number = 99}
	decoded, report := sc.unpack(&s, &got, bytes, meta)
	testing.expect_value(t, report.error, sc.Error.None)
	testing.expect_value(t, decoded.tick, u64(42))
	testing.expect(t, reflect.equal(got, value()))
	baseline := got
	wrong := meta
	wrong.epoch += 1
	_, report = sc.unpack(&s, &got, bytes, wrong)
	testing.expect_value(t, report.error, sc.Error.Context_Mismatch)
	for cut in 0 ..< len(bytes) {
		_, report = sc.unpack(&s, &got, bytes[:cut], meta)
		testing.expect(t, report.error != .None)
		testing.expect(t, reflect.equal(got, baseline))
	}
	for at in 0 ..< len(bytes) {
		bytes[at] ~= 1
		_, report = sc.unpack(&s, &got, bytes, meta)
		testing.expect(t, report.error != .None)
		testing.expect(t, reflect.equal(got, baseline))
		bytes[at] ~= 1
	}
}
