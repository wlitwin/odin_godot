#+build windows
package core

// Fatal-signal crash reporter — WINDOWS STUB. Windows crash handling is SEH
// (AddVectoredExceptionHandler / SetUnhandledExceptionFilter), not POSIX signals, and
// is deliberately OUT OF SCOPE for now: a Windows crash keeps today's behavior
// (Godot's own crash handler / Windows Error Reporting). The Odin panic/assert half
// (runtime/panic_native.odin) DOES work on Windows — script panics still print
// ODIN_SCRIPT_PANIC and push_error to the editor; only the raw-signal net is missing.
// (The web build has no crash reporter either; main.odin gates the call with !WEB.)
crash_reporter_install :: proc() {
}

// Crash-report FILE + editor-side watcher — WINDOWS STUBS. The signal-handler install
// above never runs, so no crash-file path is ever precomputed and no report file is
// written on Windows; the panic hook's file write and the editor watcher are no-ops to
// match (script panics still print + push_error via runtime/panic_native.odin).
crash_file_note_panic :: proc "c" (msg: cstring) {
}

crash_watch_pump :: proc() {
}
