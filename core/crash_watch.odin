#+build darwin, linux
package core

import "godot:godot"

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

// ----------------------------------------------------------------------------
// EDITOR-side crash-report surfacing. WHY: when the game is launched FROM THE EDITOR
// (macOS verified), the child's stderr never reaches any terminal, and the mid-crash
// push_error does not survive the dying debugger connection — so the fatal-signal
// report (core/crash.odin) and the panic line (runtime/panic_native.odin) were only
// visible on a direct terminal run. The dying GAME process therefore also writes its
// report to `<res://>/bin/.odin_crash.log`; THIS pump runs in the (alive) EDITOR
// process from the per-frame lv_frame driver and, every ~30 ticks, stats that path.
// A new report is read (capped), pushed into the editor Output as ONE framed
// push_error, then renamed to `.odin_crash.prev.log` — fires once per report, the
// artifact is preserved for symbolization, and a report left by a PREVIOUS session
// (Finder-launched games included) surfaces once on the next editor start.
//
// GATES: editor_hint only (the game child runs lv_frame too — it must never surface
// its own file; the editor itself never installs the handler, so a report here is
// always a child's/previous session's). Headless `--import` runs also have editor_hint
// set and may surface+rename a stale report — harmless by design (the rename makes it
// one-shot). Windows: no-op stub in crash_other.odin (no handler writes files there).
// ----------------------------------------------------------------------------

// ~0.5s at 60fps — a crash is rare; one stat(2) every 30 frames is free.
@(private = "file")
WATCH_INTERVAL_TICKS :: 30

// Read cap: a report is a few KB; never slurp an unbounded file into a push_error.
@(private = "file")
WATCH_READ_CAP :: 64 * 1024

@(private = "file")
g_watch_ticks: int

@(private = "file")
g_watch_path_ready: bool

// Globalized res://bin/.odin_crash.log (+ its .prev rename target), computed once,
// lazily, on the main thread (Godot calls are legal in lv_frame). core-allocator owned,
// alive for the whole editor session. "" == compute failed; the pump stays a no-op.
@(private = "file")
g_watch_path: string

@(private = "file")
g_watch_prev_path: string

// mtime (ns) of the last SURFACED report — guards a refire if the rename fails.
@(private = "file")
g_watch_last_mtime: i64

// crash_watch_pump — poll for (and surface) a game child's crash report. Called every
// frame from lv_frame (core/highlighter.odin); cheap when idle: a counter, then one
// stat(2) every WATCH_INTERVAL_TICKS frames.
crash_watch_pump :: proc() {
	g_watch_ticks += 1
	if g_watch_ticks < WATCH_INTERVAL_TICKS {
		return
	}
	g_watch_ticks = 0
	// EDITOR process only. The game child (editor_hint false) writes the file; it must
	// never surface it. The editor never installs the handler (crash_reporter_install
	// gates it out), so this can never fire on the editor's own session.
	if !bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		return
	}
	if !g_watch_path_ready {
		g_watch_path_ready = true
		gres := godot.new_string_cstring("res://bin/.odin_crash.log")
		global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
		p := string_to_odin(global, core_allocator())
		if p == "" {
			return
		}
		g_watch_path = p
		g_watch_prev_path = strings.concatenate(
			{p[:len(p) - len(".log")], ".prev.log"},
			core_allocator(),
		)
	}
	if g_watch_path == "" {
		return
	}

	cpath := strings.clone_to_cstring(g_watch_path, context.temp_allocator)
	st: posix.stat_t
	if posix.stat(cpath, &st) != .OK {
		return // no report — the overwhelmingly common case
	}
	mtime := i64(st.st_mtim.tv_sec) * 1_000_000_000 + i64(st.st_mtim.tv_nsec)
	if mtime <= g_watch_last_mtime {
		return // already surfaced (rename must have failed) — never spam
	}
	g_watch_last_mtime = mtime

	// Read the report (capped) and push the FULL text as ONE framed red error into the
	// editor Output — the symbolized report finally lands where the user is looking.
	content := ""
	if fd, oerr := os.open(g_watch_path); oerr == nil {
		buf := make([]byte, WATCH_READ_CAP, context.temp_allocator)
		total := 0
		for total < len(buf) {
			n, rerr := os.read(fd, buf[total:])
			if rerr != nil || n <= 0 {
				break
			}
			total += n
		}
		os.close(fd)
		content = strings.trim_space(string(buf[:total]))
	}
	if content != "" {
		msg := godot.new_string_odin(
			fmt.tprintf(
				"odin_godot: the game process CRASHED — report (%s):\n%s",
				g_watch_prev_path, // where the artifact lives AFTER the rename below
				content,
			),
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
	}
	// One-shot + artifact preserved: the next crash recreates .odin_crash.log fresh.
	os.rename(g_watch_path, g_watch_prev_path)
}
