#+build windows
package core

import "godot:godot"

import "base:intrinsics"
import win32 "core:sys/windows"

// SetThreadStackGuarantee is missing from core:sys/windows (a second kernel32 import
// block; scripts_native_windows.odin owns `kernel32_`, so a distinct identifier).
foreign import kernel32_crash "system:Kernel32.lib"
@(default_calling_convention = "system")
foreign kernel32_crash {
	SetThreadStackGuarantee :: proc(StackSizeInBytes: ^win32.ULONG) -> win32.BOOL ---
}

// ----------------------------------------------------------------------------
// Fatal-crash reporter — WINDOWS (SEH). The structural twin of core/crash.odin
// (darwin/linux signals): a crash in script code must never be silent, and when the
// game was launched from the editor the report must reach a FILE the editor-side
// watcher (core/crash_watch.odin — shared, all platforms) can surface in the Output.
//
// Mechanics differ from POSIX in Windows' favor:
//   * SetUnhandledExceptionFilter replaces sigaction; the PREVIOUS filter (Godot's —
//     installed during main setup, before extension init) is saved and CHAINED to, so
//     Godot's own crash text still prints.
//   * The faulting pc is EXCEPTION_RECORD.ExceptionAddress — handed over directly, no
//     ucontext offset archaeology.
//   * Symbolization is DbgHelp (SymFromAddrW / SymGetLineFromAddrW64) against the .pdb
//     the -debug builds already emit — names AND file:line, richer than dladdr.
//   * A stack overflow arrives as a real exception code (EXCEPTION_STACK_OVERFLOW);
//     SetThreadStackGuarantee reserves handler headroom (the sigaltstack analogue).
//   * An Odin panic/assert/bounds-check terminates in a trap -> EXCEPTION_BREAKPOINT
//     reaches this filter when no debugger is attached; the O_APPEND-style coordination
//     with the panic line (g_crash_file_panic) mirrors the POSIX side exactly.
//
// UNVERIFIED ON REAL WINDOWS: written against the documented SEH/DbgHelp contracts and
// compile-checked with -target:windows_amd64; runtime verification rides the Windows
// kit (WINDOWS-VERIFY.md). Every step is guarded so the worst case is a silent
// fall-through to the previous filter — never a masked crash.
// ----------------------------------------------------------------------------

@(private = "file")
g_crash_installed: bool

@(private = "file")
g_crash_reporting: bool

@(private = "file")
g_prev_filter: win32.LPTOP_LEVEL_EXCEPTION_FILTER

// Crash-report file path as UTF-16 (CreateFileW), fixed at install. [0]==0 -> no file.
@(private = "file")
g_crash_file_path: [1024]u16

// A panic line already landed this process: the filter APPENDS after it (one coherent
// file), instead of truncating a fresh report. Mirrors core/crash.odin.
@(private = "file")
g_crash_file_panic: bool

// Report file handle, valid only while the filter runs.
@(private = "file")
g_crash_file: win32.HANDLE = win32.INVALID_HANDLE_VALUE

@(private = "file")
g_sym_ready: bool

// Same placement rules as the POSIX side: editor-feature runs -> res://bin (what the
// editor watcher polls); exported game -> user:// (the post-mortem a player can send).
@(private = "file")
crash_file_precompute_path :: proc() {
	feat := godot.new_string_cstring("editor")
	editor_run := bool(godot.os_has_feature(godot.singleton_os(), feat))
	loc: cstring = editor_run ? "res://bin/.odin_crash.log" : "user://odin_crash.log"
	gres := godot.new_string_cstring(loc)
	global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
	s := string_to_odin(global, context.temp_allocator)
	if len(s) == 0 {
		return
	}
	wide := win32.utf8_to_utf16_alloc(s, context.temp_allocator)
	if len(wide) == 0 || len(wide) >= len(g_crash_file_path) {
		return
	}
	copy(g_crash_file_path[:], wide)
	g_crash_file_path[len(wide)] = 0
}

@(private = "file")
crash_file_open :: proc "system" () -> win32.HANDLE {
	if g_crash_file_path[0] == 0 {
		return win32.INVALID_HANDLE_VALUE
	}
	// Append after a panic line, else truncate to a fresh report — the FILE_APPEND_DATA
	// access right (not a flag on write) is how Win32 spells O_APPEND.
	access: win32.DWORD = g_crash_file_panic ? win32.FILE_APPEND_DATA : win32.GENERIC_WRITE
	disp: win32.DWORD = g_crash_file_panic ? win32.OPEN_ALWAYS : win32.CREATE_ALWAYS
	return win32.CreateFileW(
		cast(win32.wstring)raw_data(g_crash_file_path[:]),
		access,
		win32.FILE_SHARE_READ,
		nil,
		disp,
		win32.FILE_ATTRIBUTE_NORMAL,
		nil,
	)
}

// ---- allocation-free output (WriteFile to stderr + the report file) ----

@(private = "file")
cwrite :: proc "system" (s: string) {
	written: win32.DWORD
	err := win32.GetStdHandle(win32.STD_ERROR_HANDLE)
	if err != win32.INVALID_HANDLE_VALUE {
		win32.WriteFile(err, raw_data(s), win32.DWORD(len(s)), &written, nil)
	}
	if g_crash_file != win32.INVALID_HANDLE_VALUE {
		win32.WriteFile(g_crash_file, raw_data(s), win32.DWORD(len(s)), &written, nil)
	}
}

@(private = "file")
cwrite_hex :: proc "system" (v: uintptr) {
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
	cwrite(string(buf[:n]))
}

// Narrow a WCHAR buffer into a stack byte buffer ('?' for anything non-ASCII — symbol
// and module names in practice are ASCII); returns the narrowed slice.
@(private = "file")
narrow :: proc "system" (wide: []u16, out: []byte) -> string {
	n := 0
	for c in wide {
		if n >= len(out) {break}
		if c == 0 {break}
		out[n] = c < 128 ? byte(c) : '?'
		n += 1
	}
	return string(out[:n])
}

// One "  <addr>  <symbol> + <off>  (module)  [file:line]" line via DbgHelp.
@(private = "file")
cwrite_frame :: proc "system" (label: string, addr: rawptr) {
	cwrite(label)
	cwrite_hex(uintptr(addr))
	if addr == nil || !g_sym_ready {
		cwrite("\n")
		return
	}
	process := win32.GetCurrentProcess()

	// SYMBOL_INFOW with trailing name storage (the canonical DbgHelp dance).
	storage: [size_of(win32.SYMBOL_INFOW) + 256 * size_of(win32.WCHAR)]byte
	sym := cast(^win32.SYMBOL_INFOW)raw_data(storage[:])
	sym.SizeOfStruct = size_of(win32.SYMBOL_INFOW)
	sym.MaxNameLen = 255
	disp: win32.DWORD64
	if win32.SymFromAddrW(process, win32.DWORD64(uintptr(addr)), &disp, sym) {
		name_w := ([^]u16)(&sym.Name[0])[:sym.NameLen]
		nbuf: [256]byte
		cwrite("  ")
		cwrite(narrow(name_w, nbuf[:]))
		cwrite(" + ")
		cwrite_hex(uintptr(disp))
		// file:line from the .pdb (best-effort; richer than the POSIX side's dladdr).
		line: win32.IMAGEHLP_LINE64
		line.SizeOfStruct = size_of(win32.IMAGEHLP_LINE64)
		ldisp: win32.DWORD
		if win32.SymGetLineFromAddrW64(process, win32.DWORD64(uintptr(addr)), &ldisp, &line) &&
		   line.FileName != nil {
			fbuf: [260]byte
			fwide := ([^]u16)(line.FileName)[:260]
			cwrite("  ")
			cwrite(narrow(fwide, fbuf[:]))
			cwrite(":")
			lbuf: [12]byte
			ln := line.LineNumber
			li := len(lbuf)
			for {
				li -= 1
				lbuf[li] = byte('0' + ln % 10)
				ln /= 10
				if ln == 0 || li == 0 {break}
			}
			cwrite(string(lbuf[li:]))
		}
	} else {
		cwrite("  <no symbol — is the .pdb beside the dll?>")
	}
	cwrite("\n")
}

@(private = "file")
exception_name :: proc "system" (code: win32.DWORD) -> string {
	switch code {
	case win32.EXCEPTION_ACCESS_VIOLATION:    return "ACCESS_VIOLATION"
	case win32.EXCEPTION_STACK_OVERFLOW:      return "STACK_OVERFLOW"
	case win32.EXCEPTION_ILLEGAL_INSTRUCTION: return "ILLEGAL_INSTRUCTION"
	case win32.EXCEPTION_INT_DIVIDE_BY_ZERO:  return "INT_DIVIDE_BY_ZERO"
	case win32.EXCEPTION_BREAKPOINT:          return "BREAKPOINT (trap — Odin panic/assert/bounds-check)"
	}
	return "EXCEPTION"
}

@(private = "file")
editor_crash_message :: proc "system" (code: win32.DWORD) -> cstring {
	switch code {
	case win32.EXCEPTION_ACCESS_VIOLATION:
		return "Odin: the game CRASHED in native code (access violation — e.g. an engine call on a nil object handle). Report in bin/.odin_crash.log."
	case win32.EXCEPTION_STACK_OVERFLOW:
		return "Odin: the game CRASHED with a STACK OVERFLOW (unbounded recursion in script code?). Report in bin/.odin_crash.log."
	case win32.EXCEPTION_BREAKPOINT:
		return "Odin: the game hit a TRAP (how an Odin panic/assert/bounds-check terminates). If no ODIN_SCRIPT_PANIC message appears above, this is likely a bounds-check failure. Report in bin/.odin_crash.log."
	}
	return "Odin: the game CRASHED in native code. Report in bin/.odin_crash.log."
}

@(private = "file")
crash_filter :: proc "system" (info: ^win32.EXCEPTION_POINTERS) -> win32.LONG {
	// Reentry (a fault inside this filter): hand straight to the previous filter.
	if intrinsics.atomic_exchange(&g_crash_reporting, true) {
		if g_prev_filter != nil {
			return g_prev_filter(info)
		}
		return win32.EXCEPTION_CONTINUE_SEARCH
	}

	code: win32.DWORD = 0
	fault_addr: rawptr = nil
	if info != nil && info.ExceptionRecord != nil {
		code = info.ExceptionRecord.ExceptionCode
		fault_addr = info.ExceptionRecord.ExceptionAddress
	}

	// DbgHelp init, once, lazily (invasive: load symbols for all loaded modules — the
	// scripts dlls' .pdb files sit beside them).
	if !g_sym_ready {
		win32.SymSetOptions(0x00000002 | 0x00000004) // SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS
		g_sym_ready = bool(win32.SymInitialize(win32.GetCurrentProcess(), nil, win32.TRUE))
	}

	g_crash_file = crash_file_open()

	cwrite("\nODIN_GODOT_CRASH: fatal exception ")
	cwrite(exception_name(code))
	cwrite(" — crash in native code (Odin script or engine).\n")
	cwrite_frame("ODIN_GODOT_CRASH at   pc ", fault_addr)

	cwrite("ODIN_GODOT_CRASH backtrace (RtlCaptureStackBackTrace):\n")
	frames: [62]rawptr
	n := win32.RtlCaptureStackBackTrace(0, u32(len(frames)), raw_data(frames[:]), nil)
	for i in 0 ..< int(n) {
		cwrite_frame("  ", frames[i])
	}

	// Complete the file BEFORE the risky part (push_error into a dying process).
	if g_crash_file != win32.INVALID_HANDLE_VALUE {
		win32.CloseHandle(g_crash_file)
		g_crash_file = win32.INVALID_HANDLE_VALUE
	}

	// Restore the previous filter before push_error: a fault in there goes to Godot's
	// handler, not back here.
	win32.SetUnhandledExceptionFilter(g_prev_filter)
	godot.error(editor_crash_message(code))

	// Chain: Godot's crash handler (or WER) still runs.
	if g_prev_filter != nil {
		return g_prev_filter(info)
	}
	return win32.EXCEPTION_CONTINUE_SEARCH
}

// Install the SEH reporter. Same call site + gates as the POSIX side (extension .Scene
// init; game processes only — the editor's crash behavior is never altered).
crash_reporter_install :: proc() {
	if g_crash_installed {
		return
	}
	if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		return
	}
	g_crash_installed = true

	crash_file_precompute_path()

	// Headroom so the filter can run after EXCEPTION_STACK_OVERFLOW (the sigaltstack
	// analogue; per-thread — the main/game thread is what script code runs on).
	guarantee: win32.ULONG = 64 * 1024
	SetThreadStackGuarantee(&guarantee)

	g_prev_filter = win32.SetUnhandledExceptionFilter(crash_filter)
}

// crash_file_note_panic — Windows twin of the POSIX version (core/crash.odin): the
// script assertion proc writes its already-formatted ODIN_SCRIPT_PANIC line to the
// report file BEFORE trapping; the trap then reaches crash_filter (EXCEPTION_BREAKPOINT),
// which APPENDS its report — one coherent file. proc "c", allocation-free.
crash_file_note_panic :: proc "c" (msg: cstring) {
	if msg == nil {
		return
	}
	fd := crash_file_open()
	if fd == win32.INVALID_HANDLE_VALUE {
		return
	}
	g_crash_file_panic = true
	written: win32.DWORD
	win32.WriteFile(fd, rawptr(msg), win32.DWORD(len(msg)), &written, nil)
	nl: [1]byte = {'\n'}
	win32.WriteFile(fd, raw_data(nl[:]), 1, &written, nil)
	win32.CloseHandle(fd)
}
