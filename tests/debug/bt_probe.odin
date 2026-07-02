#+build darwin, linux
package bt_probe

// Standalone unit proof for the native-stack mechanism behind
// `_debug_get_current_stack_info` (core/debug.odin). It does NOT need Godot; it exercises
// the exact two primitives the real capture relies on:
//
//   1. backtrace() + dladdr() over THIS program's own call chain  -> proves that the
//      mechanism yields readable Odin `pkg::proc` frames (the procs below appear as
//      `bt_probe::sim_*`), and that the `::`-substring filter isolates them.
//   2. dlopen() the REAL tests/showcase/bin/libodinscripts.dylib and dladdr() an address
//      INSIDE `showcase_scripts::coin_collect` -> proves that, for the real script
//      symbol, dladdr reports dli_sname="showcase_scripts::coin_collect" and a dli_fname
//      containing "libodinscripts" (the production filter key). The address arrives as
//      argv[2]: the symbol's unslid file address (run.sh reads it out of `nm`), slid by
//      the module base. It can NOT come from dlsym: since -use-single-module (the flag
//      that makes debug DWARF usable, build/common.sh) script procs are INTERNALIZED —
//      local `t` symbols, absent from the export table dlsym searches. dladdr still
//      names them (it scans the full nlist, exactly what the crash reporter leans on),
//      and probing base+offset mirrors the crash path (an arbitrary faulting pc) more
//      faithfully than a dlsym'd entry address anyway.
//
// Build + run by tests/debug/run.sh; asserts BTPROBE_OK.

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

when ODIN_OS == .Darwin {
	foreign import libsys "system:System"
} else {
	foreign import libsys {"system:c", "system:dl"}
}

Dl_info :: struct {
	dli_fname: cstring,
	dli_fbase: rawptr,
	dli_sname: cstring,
	dli_saddr: rawptr,
}

// Same unwinder the production capture uses (core/debug.odin): libunwind's
// _Unwind_Backtrace, which walks DWARF/compact-unwind tables. (execinfo's backtrace()
// only returns the innermost frame here, because Odin omits frame pointers.)
Unwind_Context :: struct {}

foreign libsys {
	_Unwind_Backtrace :: proc "c" (fn: proc "c" (ctx: ^Unwind_Context, arg: rawptr) -> i32, arg: rawptr) -> i32 ---
	_Unwind_GetIP :: proc "c" (ctx: ^Unwind_Context) -> uintptr ---
	dladdr :: proc "c" (addr: rawptr, info: ^Dl_info) -> i32 ---
	dlopen :: proc "c" (path: cstring, mode: i32) -> rawptr ---
	dlsym :: proc "c" (handle: rawptr, symbol: cstring) -> rawptr ---
}

Collector :: struct {
	addrs: [128]rawptr,
	n:     int,
}

collect_cb :: proc "c" (ctx: ^Unwind_Context, arg: rawptr) -> i32 {
	c := cast(^Collector)arg
	if c.n < 128 {
		c.addrs[c.n] = rawptr(_Unwind_GetIP(ctx))
		c.n += 1
	}
	return 0
}

// The same filter the production capture uses (core/debug.odin): keep frames whose symbol
// is an Odin `pkg::proc`. Returns the list of kept symbol names.
@(optimization_mode = "none")
filter_odin_frames :: proc(allocator := context.allocator) -> [dynamic]string {
	out := make([dynamic]string, allocator)
	c: Collector
	_Unwind_Backtrace(collect_cb, &c)
	for i in 0 ..< c.n {
		info: Dl_info
		if dladdr(c.addrs[i], &info) == 0 || info.dli_sname == nil {
			continue
		}
		sym := string(info.dli_sname)
		if strings.contains(sym, "::") {
			append(&out, sym)
		}
	}
	return out
}

// A deliberate 3-deep call chain so the captured frames show real nesting. The calls go
// through proc-pointer variables so LLVM cannot inline them away — which also faithfully
// mirrors the real runtime, where scripts are dispatched through method trampolines (the
// engine calls Odin script procs indirectly, so they are always real stack frames).
sim_capture: [dynamic]string
sim_depth: int
sim_collect_fp: proc()
sim_step_fp: proc()

@(optimization_mode = "none")
sim_coin_collect :: proc() {
	sim_capture = filter_odin_frames()
	sim_depth += 1 // post-call work: keeps this off the tail-call path
}

@(optimization_mode = "none")
sim_player_step :: proc() {
	sim_collect_fp()
	sim_depth += 1
}

@(optimization_mode = "none")
sim_game_iteration :: proc() {
	sim_step_fp()
	sim_depth += 1
}

main :: proc() {
	// ---- Part 1: live backtrace of our own call chain ----
	sim_collect_fp = sim_coin_collect
	sim_step_fp = sim_player_step
	sim_game_iteration()
	if len(sim_capture) == 0 {
		fmt.println("BTPROBE_FAIL: backtrace captured no Odin frames at all")
		os.exit(1)
	}
	joined := strings.join(sim_capture[:], " | ")
	fmt.printf("BTPROBE part1 frames: %s\n", joined)
	if !strings.contains(joined, "bt_probe::sim_coin_collect") ||
	   !strings.contains(joined, "bt_probe::sim_player_step") {
		fmt.println("BTPROBE_FAIL: live backtrace did not yield bt_probe::sim_* Odin frames")
		os.exit(1)
	}

	// ---- Part 2: dladdr the REAL coin_collect symbol from the real scripts dll ----
	dll := len(os.args) > 1 ? os.args[1] : "tests/showcase/bin/libodinscripts.dylib"
	h := dlopen(strings.clone_to_cstring(dll), 2 /* RTLD_NOW */)
	if h == nil {
		fmt.printf("BTPROBE_FAIL: dlopen failed for %s\n", dll)
		os.exit(1)
	}
	if len(os.args) < 3 {
		fmt.println("BTPROBE_FAIL: missing argv[2] = coin_collect's unslid nm address")
		os.exit(1)
	}
	file_addr, addr_ok := strconv.parse_u64_of_base(os.args[2], 16)
	if !addr_ok {
		fmt.printf("BTPROBE_FAIL: argv[2] is not a hex address: %s\n", os.args[2])
		os.exit(1)
	}
	// Module base: dladdr any EXPORTED anchor (the boot handshake proc is always there);
	// its dli_fbase is the dylib's slid load address. Script procs are local symbols
	// (see header), so this is the only dlopen-visible route to an in-proc address.
	anchor := dlsym(h, "odin_scripts_boot")
	if anchor == nil {
		fmt.println("BTPROBE_FAIL: dlsym could not find the odin_scripts_boot anchor")
		os.exit(1)
	}
	base_info: Dl_info
	if dladdr(anchor, &base_info) == 0 || base_info.dli_fbase == nil {
		fmt.println("BTPROBE_FAIL: dladdr failed on the boot anchor")
		os.exit(1)
	}
	// +8: an address strictly INSIDE the proc (mirrors a faulting pc, and keeps a
	// boundary symbol's end address from resolving to whatever proc follows it).
	addr := rawptr(uintptr(base_info.dli_fbase) + uintptr(file_addr) + 8)
	info: Dl_info
	if dladdr(addr, &info) == 0 || info.dli_sname == nil || info.dli_fname == nil {
		fmt.println("BTPROBE_FAIL: dladdr failed on coin_collect address")
		os.exit(1)
	}
	sname := string(info.dli_sname)
	fname := string(info.dli_fname)
	fmt.printf("BTPROBE part2 dli_sname=%s dli_fname=%s\n", sname, fname)
	if !strings.contains(sname, "coin_collect") || !strings.contains(sname, "::") {
		fmt.println("BTPROBE_FAIL: dladdr symbol for coin_collect is not a readable pkg::proc")
		os.exit(1)
	}
	if !strings.contains(fname, "libodinscripts") {
		fmt.println("BTPROBE_FAIL: dladdr file for coin_collect does not contain libodinscripts")
		os.exit(1)
	}

	fmt.println("BTPROBE_OK")
}
