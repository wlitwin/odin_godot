// Throwaway GDExtension proving Bug G: VARARG engine methods now work (they go
// through object_method_bind_call instead of ptrcall, which Godot aborts on).
// On Scene-level init it exercises object_call (round-trips set_meta/get_meta
// through the vararg wrapper) and object_emit_signal (which previously ABORTED),
// printing a "VERIFY:" line per check.
package verify

import "base:runtime"
import "core:fmt"

import gd "godot:gdext"
import godot "godot:godot"

@(export, link_name = "odin_godot_init")
odin_godot_init :: proc "c" (
	get_proc_address: gd.ExtensionInterfaceGetProcAddress,
	library: gd.ExtensionClassLibraryPtr,
	initialization: ^gd.Initialization,
) -> bool {
	initialization.minimum_initialization_level = .Scene
	initialization.initialize = init_cb
	initialization.deinitialize = deinit_cb
	gd.init(library, get_proc_address)
	return true
}

deinit_cb :: proc "c" (user_data: rawptr, level: gd.InitializationLevel) {}

init_cb :: proc "c" (user_data: rawptr, level: gd.InitializationLevel) {
	if level != .Scene {
		return
	}
	context = runtime.default_context()
	godot.init()

	pass := true
	pass &= check_call()
	pass &= check_emit_signal()
	fmt.println(pass ? "VERIFY: ALL PASS" : "VERIFY: FAIL")
}

// Bug G: a VARARG method with a real payload. `object_call` is vararg; we use it
// to round-trip metadata: call obj.set_meta("vtest", 4242) then obj.get_meta(...)
// and confirm we get 4242 back. Exercises fixed-arg marshalling, variadic
// payload args, and Variant-return conversion.
check_call :: proc() -> bool {
	obj := godot.new_object()

	key := godot.new_string_name_cstring("vtest", true)
	val := godot.Int(4242)
	key_v := godot.variant_from_string_name(&key)
	val_v := godot.variant_from_int(&val)

	set_meta := godot.new_string_name_cstring("set_meta", true)
	godot.object_call(obj, set_meta, key_v, val_v)

	get_meta := godot.new_string_name_cstring("get_meta", true)
	ret := godot.object_call(obj, get_meta, key_v)
	got := godot.variant_to_int(&ret)

	ok := got == 4242
	fmt.printfln("VERIFY: G object_call set_meta/get_meta round-trip -> %v  %v", got, ok ? "PASS" : "FAIL")
	return ok
}

// Bug G: object_emit_signal previously ABORTED ("ptrcall can't be used with
// vararg methods") even for a built-in signal with zero payload. Now it must
// return without aborting (Error.Ok for a valid built-in Object signal).
check_emit_signal :: proc() -> bool {
	obj := godot.new_object()

	// Register a user signal so there's a real signal to emit.
	sig_str := godot.new_string_cstring("vsig")
	empty := godot.new_array()
	godot.object_add_user_signal(obj, sig_str, empty)

	sig := godot.new_string_name_cstring("vsig", true)
	err := godot.object_emit_signal(obj, sig)
	ok := err == .Ok
	fmt.printfln("VERIFY: G object_emit_signal -> err=%v  %v (previously ABORTED)", err, ok ? "PASS" : "FAIL")
	return ok
}
