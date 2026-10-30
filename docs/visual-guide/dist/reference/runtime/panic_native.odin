#+build darwin, linux, windows
package script_runtime

import "base:runtime"
import "core:fmt"
import "core:os"

// ----------------------------------------------------------------------------
// NATIVE panic/assert surfacing for compiled scripts — parity with the WEB build.
//
// A script `panic`, failed `assert`, or failed type assertion routes through
// `context.assertion_failure_proc`. The stock native default DOES print to stderr —
// but a game launched from the EDITOR shows the child's output through Godot's
// debugger channel (push_error/print over TCP), NOT piped stderr, so the editor's
// Output dock stayed completely silent while the game died. (A Finder-launched
// editor's stderr goes nowhere at all.)
//
// So the native script context (rt.script_context in context.odin) installs
// `native_script_assertion_failure`, which:
//   1. writes a grep-able "ODIN_SCRIPT_PANIC <prefix>: <msg> (file:line:col)" line to
//      STDERR (always works, even pre-boot / headless), then
//   2. best-effort routes the SAME line through the CORE's push_error hook — installed
//      post-boot via `odin_scripts_set_panic_report` below — so the editor Output shows
//      it red, then
//   3. traps, exactly like the default assertion proc would.
//
// HOOK ARCHITECTURE — mirror of `odin_scripts_set_core_api` (cross.odin): the runtime
// package is compiled INTO the scripts dll (its own copy of these globals), so the core
// cannot assign `panic_report_hook` directly. Instead the core dlsym's the exported
// setter right after `odin_scripts_boot` and hands over a core-side `proc "c"` that
// calls push_error with the CORE's live godot globals. On WEB the whole file is
// excluded: the web script context installs its own web_assertion_failure_proc from
// core/scripts_web.odin (unchanged).
//
// KNOWN GAP (same as web): Odin BOUNDS-CHECK failures take a separate contextless
// runtime path that never consults context.assertion_failure_proc — they still print
// to stderr only, then trap. The fatal-signal crash reporter (core/crash.odin) is the
// net under everything else.
// ----------------------------------------------------------------------------

// The core's "surface this panic message in the editor" reporter (push_error). C-shaped
// so it crosses the core<->scripts dll boundary like every other handshake proc.
Panic_Report_Proc :: proc "c" (msg: cstring)

@(private)
panic_report_hook: Panic_Report_Proc

// Called by the core (dlsym by name, right after boot — see core/scripts_native.odin)
// to hand the scripts dll its push_error reporter. Pre-boot the hook is nil and panics
// are stderr-only, which is the safe floor.
@(export)
odin_scripts_set_panic_report :: proc "c" (report: Panic_Report_Proc) {
	panic_report_hook = report
}

// context.assertion_failure_proc for compiled scripts on native. Formats into a stack
// buffer (allocation-free — the context may be mid-failure), stderr FIRST, then the
// best-effort editor route, then trap like the default. `loc` is the script-relevant
// source location Odin hands every assertion proc (the panic/assert call site).
native_script_assertion_failure :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
	buf: [1024]byte
	// Reserve one byte so the NUL for the cstring view below always fits.
	msg := fmt.bprintf(
		buf[:len(buf) - 1],
		"ODIN_SCRIPT_PANIC %s: %s (%s:%d:%d)",
		prefix,
		message,
		loc.file_path,
		loc.line,
		loc.column,
	)
	os.write_string(os.stderr, msg)
	os.write_string(os.stderr, "\n")
	if panic_report_hook != nil {
		buf[len(msg)] = 0 // msg starts at buf[0]
		panic_report_hook(cstring(raw_data(buf[:])))
	}
	runtime.trap()
}
