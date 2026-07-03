#+build darwin, linux
package core

import "godot:godot"

import "base:intrinsics"
import "core:sys/posix"

// ----------------------------------------------------------------------------
// Fatal-signal crash reporter (darwin + linux; the Windows SEH twin lives in
// crash_windows.odin). WHY: a mistake in script code (the classic: calling an engine
// method on a nil object handle) kills the game with a raw SIGSEGV and ZERO Odin-side
// output — and when the game was launched from the editor, the editor's Output dock
// shows the child's output via Godot's debugger TCP channel, not piped stderr, so the
// user sees NOTHING at all. This installs sigaction handlers for the fatal quartet
// (SIGSEGV/SIGBUS/SIGILL/SIGFPE) that, best-effort (the process is dying):
//
//   1. write a grep-able ODIN_GODOT_CRASH marker to STDERR (unbuffered write(2) —
//      always lands, headless harnesses and terminals capture it) AND to a crash-report
//      FILE (path precomputed at install — see crash_file_precompute_path): when the game
//      was launched from the editor its stderr goes nowhere and the mid-crash push_error
//      dies with the debugger connection, so the FILE is the only artifact that survives;
//      the EDITOR-side watcher (core/crash_watch.odin) surfaces it in the editor Output,
//   2. write the FAULTING pc (and, on arm64, the caller lr) pulled out of the signal
//      ucontext, symbolized with dladdr — in the backtrace spike this was the ONLY
//      mechanism that named the faulting Odin proc: both execinfo's backtrace() and
//      libunwind's _Unwind_Backtrace lose the interrupted frame across the signal
//      trampoline (they recover the handler + the fault's CALLER, not the fault),
//   3. dump an execinfo `backtrace_symbols_fd` stack (async-signal-safe by design;
//      frame-pointer based, so Odin frames — Odin omits fp — appear shallow, but
//      engine frames below the extension boundary walk fine),
//   4. best-effort push ONE red line through Godot's error channel so the EDITOR
//      Output says the game crashed (guarded: stderr came first, and the previous
//      handlers are restored before trying, so a fault inside push_error chains to
//      Godot's handler instead of recursing here),
//   5. CHAIN: re-raise with the PREVIOUS sigaction restored, so Godot's own crash
//      handler (installed in main setup, BEFORE extension .Scene init — saving
//      "previous" saves Godot's) still prints its engine backtrace.
//
// EDITOR GATE: the editor process loads this same core; the reporter is only installed
// when engine_is_editor_hint is FALSE (the game child / exported game / headless run),
// so the EDITOR's own crash behavior is never altered.
//
// Symbolizing the module+offset lines: `atos -o libodinscripts.dylib.dSYM/Contents/
// Resources/DWARF/libodinscripts.dylib -l <load addr> <pc>` (see docs/debugging.md).
//
// SIGTRAP is in the handled set: Odin terminates panics/asserts AND bounds-check
// failures with a trap instruction, which on arm64 raises SIGTRAP (x86: ud2 -> SIGILL).
// Handling it (a) closes the bounds-check hole — those bypass the assertion proc via a
// contextless runtime path, so without this an editor-launched game died silently —
// and (b) makes arm64 panics append the signal report after the ODIN_SCRIPT_PANIC line
// exactly like x86 (the O_APPEND coordination below).
//
// The handler runs on a SIGALTSTACK, so a STACK-OVERFLOW SIGSEGV (whose faulting thread
// has no usable stack left) still reports. NOT handled: Windows — SEH, not signals; see
// core/crash_windows.odin.
// ----------------------------------------------------------------------------

// execinfo: backtrace/backtrace_symbols_fd live in libSystem on Darwin, glibc on Linux.
when ODIN_OS == .Darwin {
	foreign import libexecinfo "system:System"
} else {
	foreign import libexecinfo "system:c"
}
foreign libexecinfo {
	backtrace :: proc "c" (buffer: [^]rawptr, size: i32) -> i32 ---
	backtrace_symbols_fd :: proc "c" (buffer: [^]rawptr, size: i32, fd: i32) ---
}

@(private = "file")
CRASH_SIGNALS :: [5]posix.Signal{.SIGSEGV, .SIGBUS, .SIGILL, .SIGFPE, .SIGTRAP}

@(private = "file")
g_prev_actions: [len(CRASH_SIGNALS)]posix.sigaction_t

@(private = "file")
g_crash_installed: bool

// One-per-process reentrancy latch: a fault INSIDE the handler (or a second thread
// crashing mid-report) must not recurse — restore Godot's handlers and re-raise.
@(private = "file")
g_crash_reporting: bool

// ---- crash-report FILE (the artifact that survives an editor-launched child) ----

// Absolute, NUL-terminated crash-report file path, filled at install time (the handler
// cannot allocate or call the engine). [0] == 0 means "no file" (editor process /
// precompute failure) — the stderr path is unaffected either way.
@(private = "file")
g_crash_file_path: [1024]byte

// Set once crash_file_note_panic has written a panic line this process: the signal
// handler then APPENDS instead of truncating, so a trap-after-panic that IS a handled
// signal (x86: ud2 -> SIGILL) yields ONE coherent file, never a clobbered panic line.
@(private = "file")
g_crash_file_panic: bool

// Crash file fd, open only while the handler runs (-1 otherwise).
@(private = "file")
g_crash_fd: posix.FD = -1

// Precompute the crash-report file path while Godot calls are still legal (install runs
// at .Scene init in the GAME process). Where:
//   - ANY non-exported run (os_has_feature("editor") — true for editor-Play children and
//     headless --script runs alike): <globalized res://>/bin/.odin_crash.log. bin/ exists
//     in every built project (the dlls live there) and is exactly the path the EDITOR
//     process polls (core/crash_watch.odin) to surface the report in the editor Output.
//   - exported game: <globalized user://>/odin_crash.log — always writable, and a shipped
//     game's crash leaves a post-mortem file a player can send in.
@(private = "file")
crash_file_precompute_path :: proc() {
	feat := godot.new_string_cstring("editor")
	editor_run := bool(godot.os_has_feature(godot.singleton_os(), feat))
	loc: cstring = editor_run ? "res://bin/.odin_crash.log" : "user://odin_crash.log"
	gres := godot.new_string_cstring(loc)
	global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
	s := string_to_odin(global, context.temp_allocator)
	if len(s) == 0 || len(s) >= len(g_crash_file_path) {
		return
	}
	copy(g_crash_file_path[:], s)
	g_crash_file_path[len(s)] = 0
}

// Open the crash-report file for one report. O_TRUNC normally (a fresh report replaces
// any stale one); O_APPEND once a panic line landed (see g_crash_file_panic). Raw
// open(2) — async-signal-safe, allocation-free — so it is legal both mid-signal and
// mid-panic. Returns -1 (disabled/failed) without affecting the stderr path.
@(private = "file")
crash_file_open :: proc "c" () -> posix.FD {
	if g_crash_file_path[0] == 0 {
		return -1
	}
	flags := posix.O_Flags{.WRONLY, .CREAT} +
		(g_crash_file_panic ? posix.O_Flags{.APPEND} : posix.O_Flags{.TRUNC})
	mode := posix.mode_t{.IRUSR, .IWUSR, .IRGRP, .IROTH} // 0644
	return posix.open(cast(cstring)raw_data(g_crash_file_path[:]), flags, mode)
}

// crash_file_note_panic — write one already-formatted ODIN_SCRIPT_PANIC line to the
// crash-report file. Reached via core's script_panic_report (scripts_native.odin), which
// the scripts dll's assertion proc calls BEFORE it traps. This is NOT redundant with the
// signal handler: on darwin arm64 the trap raises SIGTRAP (verified empirically — Godot's
// handle_crash reports "signal 5"), which is not in CRASH_SIGNALS, so without this write
// the file would stay empty for script panics. Where the trap IS a handled signal (x86:
// ud2 -> SIGILL) the handler sees g_crash_file_panic and APPENDS its report after this
// line — one coherent file either way. proc "c" + raw write(2): called mid-panic, must
// not allocate. No-op when no path was precomputed (editor process / Windows stub).
crash_file_note_panic :: proc "c" (msg: cstring) {
	if msg == nil {
		return
	}
	fd := crash_file_open()
	if fd < 0 {
		return
	}
	g_crash_file_panic = true
	posix.write(fd, transmute([^]u8)msg, uint(len(msg)))
	nl: [1]byte = {'\n'}
	posix.write(fd, raw_data(nl[:]), 1)
	posix.close(fd)
}

// Install the fatal-signal reporter. Called at extension .Scene init (runs in both the
// editor and the game — the editor-hint gate below picks the game only). Idempotent.
// Godot installs its own crash handler during main setup, BEFORE extension init, so the
// sigactions saved here are Godot's — restored + re-raised after reporting (step 5).
crash_reporter_install :: proc() {
	if g_crash_installed {
		return
	}
	// Never alter the EDITOR's crash behavior; only the running game reports.
	if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		return
	}
	g_crash_installed = true

	// Godot calls are legal HERE (not in the handler): fix the crash-report file path
	// now, into a static buffer the handler and the panic path can use allocation-free.
	crash_file_precompute_path()

	// Alternate signal stack: a STACK-OVERFLOW SIGSEGV leaves the faulting thread no
	// stack to run a handler on — without this the process just dies, report-less. A
	// static buffer (never freed; the reporter lives for the process) + SA_ONSTACK.
	// Failure is non-fatal: handlers still work for every non-overflow crash.
	@(static) alt_stack: [256 * 1024]byte
	ss := posix.stack_t {
		ss_sp    = raw_data(alt_stack[:]),
		ss_size  = len(alt_stack),
		ss_flags = {},
	}
	posix.sigaltstack(&ss, nil)

	act: posix.sigaction_t
	act.sa_sigaction = crash_handler
	act.sa_flags = {.SIGINFO, .ONSTACK}
	posix.sigemptyset(&act.sa_mask)
	sigs := CRASH_SIGNALS
	for s, i in sigs {
		posix.sigaction(s, &act, &g_prev_actions[i])
	}
}

// ---- async-signal-safe output helpers (raw write(2); no fmt, no allocation) ----
// Every chunk goes to STDERR and, when the handler opened it, the crash-report FILE —
// the file is what survives an editor-launched child whose stderr goes nowhere.

@(private = "file")
cwrite :: proc "c" (s: string) {
	posix.write(posix.FD(2), raw_data(s), uint(len(s)))
	if g_crash_fd >= 0 {
		posix.write(g_crash_fd, raw_data(s), uint(len(s)))
	}
}

@(private = "file")
cwrite_hex :: proc "c" (v: uintptr) {
	digits := "0123456789abcdef"
	buf: [18]byte
	buf[0] = '0'
	buf[1] = 'x'
	n := 2
	shift := (size_of(uintptr) * 8) - 4
	for shift >= 0 {
		buf[n] = digits[(v >> uint(shift)) & 0xf]
		n += 1
		shift -= 4
	}
	posix.write(posix.FD(2), raw_data(buf[:]), uint(n))
	if g_crash_fd >= 0 {
		posix.write(g_crash_fd, raw_data(buf[:]), uint(n))
	}
}

// One "  <addr>  <symbol> + <offset>  (<module>)" line via dladdr (Dl_info/dladdr are
// declared package-wide in scripts_native.odin). dladdr is not formally on the
// async-signal-safe list, but it takes no locks worth fearing and every production
// crash handler (Godot's included) leans on it — and stderr step 1 already landed.
@(private = "file")
cwrite_frame :: proc "c" (label: string, addr: rawptr) {
	cwrite(label)
	cwrite_hex(uintptr(addr))
	info: Dl_info
	if addr != nil && dladdr(addr, &info) != 0 && info.dli_sname != nil {
		cwrite("  ")
		cwrite(string(info.dli_sname))
		cwrite(" + ")
		cwrite_hex(uintptr(addr) - uintptr(info.dli_saddr))
		if info.dli_fname != nil {
			cwrite("  (")
			cwrite(string(info.dli_fname))
			cwrite(")")
		}
	} else {
		cwrite("  <no symbol — symbolize via dSYM, see docs/debugging.md>")
	}
	cwrite("\n")
}

// Pull the interrupted pc (and caller lr on arm64) out of the signal ucontext. Raw,
// platform-pinned offsets (core:sys/posix carries no ucontext_t): VERIFIED on darwin
// arm64 (the backtrace spike + tests/crash); darwin amd64 / linux offsets are from the
// platform headers but untested at runtime here — a wrong offset yields a garbage
// address that dladdr simply fails to resolve (best-effort by design).
@(private = "file")
fault_pc_lr :: proc "c" (uctx: rawptr) -> (pc: rawptr, lr: rawptr) {
	if uctx == nil {
		return nil, nil
	}
	when ODIN_OS == .Darwin {
		// ucontext_t.uc_mcontext (a POINTER) at +48.
		mctx := (cast(^rawptr)(uintptr(uctx) + 48))^
		if mctx == nil {
			return nil, nil
		}
		when ODIN_ARCH == .arm64 {
			// mcontext64: __es{far,esr,exc}=16, __ss.x[29]=232, then fp, lr@256, sp, pc@272.
			pc = (cast(^rawptr)(uintptr(mctx) + 272))^
			lr = (cast(^rawptr)(uintptr(mctx) + 256))^
		} else when ODIN_ARCH == .amd64 {
			// mcontext64: __es=16, then x86_thread_state64 — rip is its 17th u64.
			pc = (cast(^rawptr)(uintptr(mctx) + 16 + 16 * 8))^
		}
	} else when ODIN_OS == .Linux {
		when ODIN_ARCH == .amd64 {
			// glibc ucontext_t.uc_mcontext (INLINE) at +40; gregs[REG_RIP=16].
			pc = (cast(^rawptr)(uintptr(uctx) + 40 + 16 * 8))^
		} else when ODIN_ARCH == .arm64 {
			// uc_mcontext (INLINE, 16-aligned) at +176; {fault_address, regs[31], sp, pc}.
			pc = (cast(^rawptr)(uintptr(uctx) + 176 + 264))^
			lr = (cast(^rawptr)(uintptr(uctx) + 176 + 8 + 30 * 8))^
		}
	}
	return
}

@(private = "file")
signal_name :: proc "c" (sig: posix.Signal) -> string {
	#partial switch sig {
	case .SIGSEGV: return "SIGSEGV"
	case .SIGBUS:  return "SIGBUS"
	case .SIGILL:  return "SIGILL"
	case .SIGFPE:  return "SIGFPE"
	case .SIGTRAP: return "SIGTRAP"
	}
	return "signal"
}

// The one-liner for the editor Output. Static cstrings only — mid-crash is no place
// to format.
@(private = "file")
editor_crash_message :: proc "c" (sig: posix.Signal) -> cstring {
	#partial switch sig {
	case .SIGSEGV:
		return "Odin: the game CRASHED in native code (SIGSEGV — bad memory access, e.g. an engine call on a nil object handle). Backtrace on stderr/terminal; symbolize with docs/debugging.md."
	case .SIGBUS:
		return "Odin: the game CRASHED in native code (SIGBUS — misaligned/invalid memory access). Backtrace on stderr/terminal; symbolize with docs/debugging.md."
	case .SIGILL:
		return "Odin: the game CRASHED in native code (SIGILL — illegal instruction; also how an Odin panic/trap terminates). Backtrace on stderr/terminal; symbolize with docs/debugging.md."
	case .SIGFPE:
		return "Odin: the game CRASHED in native code (SIGFPE — integer division by zero or similar). Backtrace on stderr/terminal; symbolize with docs/debugging.md."
	case .SIGTRAP:
		return "Odin: the game hit a TRAP (SIGTRAP — how an Odin panic/assert/bounds-check terminates). If no ODIN_SCRIPT_PANIC message appears above, this is likely a bounds-check failure: run from a terminal (or under Tools > Debug Game (LLDB)) to see the runtime's index/range message."
	}
	return "Odin: the game CRASHED in native code (fatal signal). Backtrace on stderr/terminal; symbolize with docs/debugging.md."
}

@(private = "file")
restore_previous_actions :: proc "c" () {
	sigs := CRASH_SIGNALS
	for s, i in sigs {
		posix.sigaction(s, &g_prev_actions[i], nil)
	}
}

@(private = "file")
crash_handler :: proc "c" (sig: posix.Signal, info: ^posix.siginfo_t, uctx: rawptr) {
	// Reentry (a fault inside this handler, or a second crashing thread): hand straight
	// to Godot's handlers — our report is already (partially) out.
	if intrinsics.atomic_exchange(&g_crash_reporting, true) {
		restore_previous_actions()
		posix.raise(sig)
		return
	}

	// 0. Open the crash-report FILE (path fixed at install). Best-effort: on failure
	//    g_crash_fd stays -1 and every cwrite below is stderr-only, exactly as before.
	g_crash_fd = crash_file_open()

	// 1. Marker FIRST — an unbuffered write that survives whatever happens next.
	cwrite("\nODIN_GODOT_CRASH: fatal signal ")
	cwrite(signal_name(sig))
	cwrite(" — crash in native code (Odin script or engine).\n")

	// 2. The faulting frame, from the ucontext (see fault_pc_lr — the stack walkers
	//    below cannot recover this frame across the signal trampoline).
	pc, lr := fault_pc_lr(uctx)
	cwrite_frame("ODIN_GODOT_CRASH at   pc ", pc)
	if lr != nil {
		cwrite_frame("ODIN_GODOT_CRASH from lr ", lr)
	}

	// 3. Stack dump (execinfo; async-signal-safe). Engine frames below the extension
	//    boundary carry frame pointers and walk fully; Odin frames appear shallow.
	cwrite("ODIN_GODOT_CRASH backtrace (backtrace_symbols_fd):\n")
	frames: [64]rawptr
	n := backtrace(raw_data(frames[:]), i32(len(frames)))
	if n > 0 {
		backtrace_symbols_fd(raw_data(frames[:]), n, 2)
		if g_crash_fd >= 0 {
			backtrace_symbols_fd(raw_data(frames[:]), n, i32(g_crash_fd))
		}
	}

	// 3b. Close the crash file BEFORE the risky part below: the report must be complete
	//     on disk even if push_error or the re-raise teardown faults.
	if g_crash_fd >= 0 {
		posix.close(g_crash_fd)
		g_crash_fd = -1
	}

	// 4. Restore Godot's handlers BEFORE the risky part: if push_error faults mid-crash,
	//    the nested signal chains to Godot's crash handler instead of recursing here.
	restore_previous_actions()

	// 5. Best-effort ONE red line into the editor Output (push_error travels the
	//    debugger TCP link to the editor; stderr does not). May silently fail or be
	//    lost in the dying process — steps 1-3 are already on stderr regardless.
	godot.error(editor_crash_message(sig))

	// 6. Chain: previous (Godot's) handlers are restored; re-raise. The signal is
	//    blocked during this handler, so it is delivered — to Godot's handler — the
	//    moment we return (and a hardware fault would re-trigger at the faulting
	//    instruction anyway). Godot's engine backtrace still prints.
	posix.raise(sig)
}
