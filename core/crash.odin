#+build darwin, linux
package core

import "godot:godot"

import "base:intrinsics"
import "core:sys/posix"

// ----------------------------------------------------------------------------
// Fatal-signal crash reporter (darwin + linux; Windows is OUT OF SCOPE — see
// crash_other.odin). WHY: a mistake in script code (the classic: calling an engine
// method on a nil object handle) kills the game with a raw SIGSEGV and ZERO Odin-side
// output — and when the game was launched from the editor, the editor's Output dock
// shows the child's output via Godot's debugger TCP channel, not piped stderr, so the
// user sees NOTHING at all. This installs sigaction handlers for the fatal quartet
// (SIGSEGV/SIGBUS/SIGILL/SIGFPE) that, best-effort (the process is dying):
//
//   1. write a grep-able ODIN_GODOT_CRASH marker to STDERR (unbuffered write(2) —
//      always lands, headless harnesses and terminals capture it),
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
// NOT handled: stack-overflow crashes (no sigaltstack — the handler runs on the dead
// stack), and anything on Windows (SEH, not signals — documented out of scope).
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
CRASH_SIGNALS :: [4]posix.Signal{.SIGSEGV, .SIGBUS, .SIGILL, .SIGFPE}

@(private = "file")
g_prev_actions: [len(CRASH_SIGNALS)]posix.sigaction_t

@(private = "file")
g_crash_installed: bool

// One-per-process reentrancy latch: a fault INSIDE the handler (or a second thread
// crashing mid-report) must not recurse — restore Godot's handlers and re-raise.
@(private = "file")
g_crash_reporting: bool

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

	act: posix.sigaction_t
	act.sa_sigaction = crash_handler
	act.sa_flags = {.SIGINFO}
	posix.sigemptyset(&act.sa_mask)
	sigs := CRASH_SIGNALS
	for s, i in sigs {
		posix.sigaction(s, &act, &g_prev_actions[i])
	}
}

// ---- async-signal-safe stderr helpers (raw write(2); no fmt, no allocation) ----

@(private = "file")
cwrite :: proc "c" (s: string) {
	posix.write(posix.FD(2), raw_data(s), uint(len(s)))
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
