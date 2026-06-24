//gd:extends Node
//gd:class Ping
package showcase

// ----------------------------------------------------------------------------
// Ping — the Phase 3 showcase script. Exercises the full GDScript-parity surface:
//   - @export vars (`speed: f32`, `count: int`) settable/gettable from GDScript
//   - custom methods (`add`, `addf`, `emit_ping`) callable from GDScript
//   - a declared signal `pinged(value: int)` emitted from Odin with a payload
//
// HAND-WRITTEN registration (codegen is Phase 3.5). The trampolines below are the
// uniform `rt.Method_Proc` convention: unpack Variant args -> typed params, run the
// logic, write the return Variant. The `@(init)` publishes name/base/exports/methods/
// signals to the runtime registry (pure data, safe pre-boot).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "godot:gdext"
import rt "godot:runtime"

// First field MUST be the owner Object pointer (core writes it at offset 0).
Ping :: struct {
	owner: gd.Node,
	speed: f32, // @export
	count: gd.Int, // @export (i64)
}

// ---- cached Variant constructors for the trampolines ----
@(private = "file")
to_int: gdext.TypeFromVariantConstructorProc
@(private = "file")
from_int: gdext.VariantFromTypeConstructorProc
@(private = "file")
to_float: gdext.TypeFromVariantConstructorProc
@(private = "file")
from_float: gdext.VariantFromTypeConstructorProc
@(private = "file")
ctors_ready: bool

@(private = "file")
ensure_ctors :: proc "contextless" () {
	if !ctors_ready {
		to_int = gdext.get_variant_to_type_constructor(.Int)
		from_int = gdext.get_variant_from_type_constructor(.Int)
		to_float = gdext.get_variant_to_type_constructor(.Float)
		from_float = gdext.get_variant_from_type_constructor(.Float)
		ctors_ready = true
	}
}

// ---- lifecycle ----
ping_ready :: proc "c" (self_raw: rawptr) {
	self := cast(^Ping)self_raw
	// Only set defaults if GDScript hasn't already written the exports.
	if self.speed == 0 {self.speed = 1.5}
}

// ---- custom methods (uniform rt.Method_Proc trampolines) ----

// add(a: int, b: int) -> int
ping_add :: proc "c" (self: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {
	ensure_ctors()
	a, b: i64
	to_int(&a, args[0])
	to_int(&b, args[1])
	r := a + b
	from_int(ret, &r)
}

// addf(a: float, b: float) -> float  (exercises the float marshalling path)
ping_addf :: proc "c" (self: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {
	ensure_ctors()
	a, b: f64
	to_float(&a, args[0])
	to_float(&b, args[1])
	r := a + b
	from_float(ret, &r)
}

// get_speed() -> float  (proves the Odin side sees the GDScript-written @export)
ping_get_speed :: proc "c" (self_raw: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {
	ensure_ctors()
	self := cast(^Ping)self_raw
	r := f64(self.speed)
	from_float(ret, &r)
}

// emit_ping(value: int) -> void  (emits the `pinged` signal with a payload)
ping_emit_ping :: proc "c" (self_raw: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {
	ensure_ctors()
	self := cast(^Ping)self_raw
	v: i64
	to_int(&v, args[0])
	self.count += v
	emit_pinged(self, v)
}

// ---- signal emission via the Object::emit_signal method bind ----
@(private = "file")
pinged_name: gd.String_Name
@(private = "file")
emit_signal_name: gd.String_Name
@(private = "file")
emit_bind: gdext.MethodBindPtr
@(private = "file")
emit_ready: bool

emit_pinged :: proc "c" (self: ^Ping, value: i64) {
	if !emit_ready {
		pinged_name = gd.new_string_name_cstring("pinged", true)
		emit_signal_name = gd.new_string_name_cstring("emit_signal", true)
		emit_bind = gdext.classdb_get_method_bind(gd.object_name_ref(), &emit_signal_name, 4047867050)
		emit_ready = true
	}
	if emit_bind == nil {return}

	value := value
	sig_arg := gd.variant_from(&pinged_name)
	val_arg := gd.variant_from(&value)
	call_args := [2]gdext.VariantPtr{&sig_arg, &val_arg}
	r := gd.Variant{}
	gdext.object_method_bind_call(emit_bind, self.owner, &call_args[0], len(call_args), &r, nil)
	gdext.variant_destroy(&r)
	gdext.variant_destroy(&sig_arg)
	gdext.variant_destroy(&val_arg)
}

// ---- registration (static backing arrays referenced by the Class_Desc slices) ----
@(private = "file")
ping_exports := [?]rt.Export {
	{name = "speed", type = .Float, offset = offset_of(Ping, speed), size = size_of(f32)},
	{name = "count", type = .Int, offset = offset_of(Ping, count), size = size_of(gd.Int)},
}

@(private = "file")
add_arg_types := [?]gdext.Variant_Type{.Int, .Int}
@(private = "file")
addf_arg_types := [?]gdext.Variant_Type{.Float, .Float}
@(private = "file")
emit_arg_types := [?]gdext.Variant_Type{.Int}

@(private = "file")
ping_methods := [?]rt.Method {
	{name = "add", trampoline = ping_add, arg_types = add_arg_types[:], return_type = .Int},
	{name = "addf", trampoline = ping_addf, arg_types = addf_arg_types[:], return_type = .Float},
	{name = "get_speed", trampoline = ping_get_speed, arg_types = {}, return_type = .Float},
	{name = "emit_ping", trampoline = ping_emit_ping, arg_types = emit_arg_types[:], return_type = .Nil},
}

@(private = "file")
pinged_arg_names := [?]cstring{"value"}
@(private = "file")
pinged_arg_types := [?]gdext.Variant_Type{.Int}

@(private = "file")
ping_signals := [?]rt.Signal {
	{name = "pinged", arg_names = pinged_arg_names[:], arg_types = pinged_arg_types[:]},
}

@(init)
_register_ping :: proc "contextless" () {
	rt.register(
		rt.Class_Desc {
			name = "Ping",
			base = "Node",
			size = size_of(Ping),
			align = align_of(Ping),
			lifecycle = rt.Lifecycle{ready = ping_ready},
			exports = ping_exports[:],
			methods = ping_methods[:],
			signals = ping_signals[:],
		},
	)
}
