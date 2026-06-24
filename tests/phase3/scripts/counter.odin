//gd:extends RefCounted
//gd:class Counter
package showcase

// ----------------------------------------------------------------------------
// Counter — proves `extends` works for a base OTHER than Node2D (here RefCounted,
// so GDScript owns the lifetime and no scene tree is needed). Has one @export
// (`count: int`) and one custom method (`increment() -> int`).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import "godot:gdext"
import rt "godot:runtime"

Counter :: struct {
	owner: gd.Object,
	count: gd.Int, // @export
}

@(private = "file")
from_int: gdext.VariantFromTypeConstructorProc
@(private = "file")
from_int_ready: bool

// increment() -> int : bumps the exported count and returns the new value.
counter_increment :: proc "c" (self_raw: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {
	if !from_int_ready {
		from_int = gdext.get_variant_from_type_constructor(.Int)
		from_int_ready = true
	}
	self := cast(^Counter)self_raw
	self.count += 1
	r := self.count
	from_int(ret, &r)
}

@(private = "file")
counter_exports := [?]rt.Export {
	{name = "count", type = .Int, offset = offset_of(Counter, count), size = size_of(gd.Int)},
}

@(private = "file")
counter_methods := [?]rt.Method {
	{name = "increment", trampoline = counter_increment, arg_types = {}, return_type = .Int},
}

@(init)
_register_counter :: proc "contextless" () {
	rt.register(
		rt.Class_Desc {
			name = "Counter",
			base = "RefCounted",
			size = size_of(Counter),
			align = align_of(Counter),
			exports = counter_exports[:],
			methods = counter_methods[:],
		},
	)
}
