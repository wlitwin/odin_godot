package host

// Stand-in for the stable CORE dll. Loads a "scripts" dll, calls into it, unloads it, then
// loads a DIFFERENT (rebuilt) scripts dll — all in one process — to prove in-process hot reload.
// Reports whether @(init) auto-ran on dlopen, whether per-load state is fresh after reload, and
// whether the rebuilt behavior is picked up.

import "core:dynlib"
import "core:fmt"
import "core:os"

Script :: struct {
	__handle:         dynlib.Library,
	get_init_marker:  proc "c" () -> int,
	bump:             proc "c" () -> int,
	behavior_version: proc "c" () -> int,
	script_boot:      proc "c" (),
}

load :: proc(path: string) -> (s: Script, ok: bool) {
	count, _ := dynlib.initialize_symbols(&s, path, "", "__handle")
	ok = count > 0 && s.__handle != nil
	return
}

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("usage: host <script_v1.dylib> <script_v2.dylib>")
		os.exit(2)
	}
	fail :: proc(msg: string) { fmt.printfln("RELOAD_FAIL: %s", msg); os.exit(1) }

	// --- load v1 ---
	v1, ok1 := load(os.args[1])
	if !ok1 { fail("could not load v1") }
	auto_ran := v1.get_init_marker() == 0xBEEF
	if !auto_ran {
		// design still works: core calls an explicit boot export after dlopen
		v1.script_boot()
		if v1.get_init_marker() != 0xBEEF { fail("explicit script_boot did not init globals") }
	}
	b1a := v1.bump()           // expect 101
	b1b := v1.bump()           // expect 102
	ver1 := v1.behavior_version()
	if !dynlib.unload_library(v1.__handle) { fail("could not unload v1") }

	// --- load v2 (a separately rebuilt dll) ---
	v2, ok2 := load(os.args[2])
	if !ok2 { fail("could not load v2 after unloading v1") }
	if v2.get_init_marker() != 0xBEEF {
		v2.script_boot()
		if v2.get_init_marker() != 0xBEEF { fail("v2 explicit boot did not init") }
	}
	b2a := v2.bump()           // expect 101 again — FRESH state, not 103
	ver2 := v2.behavior_version()
	dynlib.unload_library(v2.__handle)

	fmt.printfln("auto_init_on_dlopen=%v", auto_ran)
	fmt.printfln("v1: marker=0xBEEF bump=%d,%d behavior=%d", b1a, b1b, ver1)
	fmt.printfln("v2: bump=%d behavior=%d", b2a, ver2)

	// Verdict checks: fresh state after reload + new behavior picked up.
	if b2a != 101 { fail("v2 state not fresh after reload (got bump=%d, want 101)") }
	if ver1 == ver2 { fail("rebuilt behavior NOT picked up (both versions equal)") }
	fmt.println("RELOAD_OK")
}
