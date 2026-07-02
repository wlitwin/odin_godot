//gd:extends Node
//gd:class CrashTarget
package crash_scripts

// ----------------------------------------------------------------------------
// CrashTarget — deliberately dies, two ways, so tests/crash/run.sh can assert the
// crash/panic REPORTING (not the crash itself):
//
//   do_panic — an Odin `panic("...")` inside a @(gd_method). Routes through the native
//     script context's assertion_failure_proc (runtime/panic_native.odin): the test
//     asserts the ODIN_SCRIPT_PANIC stderr line (message + file:line) AND the
//     push_error copy of it (headless prints push_error to the captured output).
//
//   do_segv — a nil dereference inside a @(gd_method). A raw SIGSEGV with zero Odin
//     involvement: the test asserts the core's fatal-signal reporter (core/crash.odin)
//     printed ODIN_GODOT_CRASH + a symbolized faulting frame naming this proc, and
//     that Godot's own chained crash handler still ran.
//
//   do_overflow — unbounded recursion (non-tail, fat frames): a stack-overflow SIGSEGV,
//     which can only report at all because the handler runs on a sigaltstack.
//
// EXPORTED-game hook: this node is an AUTOLOAD, so the exported app instantiates it at
// startup — crash_target_ready reads ODIN_CRASH_TEST and self-crashes accordingly, which
// is how run.sh's export phase asserts the user://odin_crash.log post-mortem artifact.
// Unset (every editor/headless-driver run), _ready is a no-op.
// ----------------------------------------------------------------------------

import "base:intrinsics"
import "core:os"
import gd "godot:godot"

CrashTarget :: struct {
	owner: gd.Node,
}

// The known message run.sh greps for (alongside the file:line of the panic call).
CRASH_TEST_PANIC_MESSAGE :: "CRASH_TEST_PANIC boom from odin script"

@(gd_method)
crash_target_do_panic :: proc(self: ^CrashTarget) {
	panic(CRASH_TEST_PANIC_MESSAGE)
}

@(gd_method)
crash_target_do_segv :: proc(self: ^CrashTarget) {
	// volatile_load so the nil deref cannot be folded away; classic "engine handle was
	// nil" crash shape.
	p := cast(^i64)rawptr(uintptr(0))
	x := intrinsics.volatile_load(p)
	gd.print_int(x) // never reached
}

@(gd_method)
crash_target_do_overflow :: proc(self: ^CrashTarget) {
	gd.print_int(overflow_rec(1))
}

// Unbounded NON-TAIL recursion (the add after the call keeps it off the tail-call path
// even if optimization settings ever change) with a fat frame, so the stack dies fast.
@(private = "file")
overflow_rec :: proc(n: i64) -> i64 {
	pad: [512]i64
	pad[int(n) & 511] = n
	return overflow_rec(n + 1) + pad[int(n) & 511]
}

crash_target_ready :: proc(self: ^CrashTarget) {
	switch os.get_env("ODIN_CRASH_TEST", context.temp_allocator) {
	case "panic":
		crash_target_do_panic(self)
	case "segv":
		crash_target_do_segv(self)
	case "overflow":
		crash_target_do_overflow(self)
	}
}
