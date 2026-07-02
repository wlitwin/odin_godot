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
