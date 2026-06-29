#+build darwin, linux, windows
package core

import "godot:godot"

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:hash"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

// ----------------------------------------------------------------------------
// Editor "show on save" — rebuild + reload the scripts dll while the editor RUNS.
//
// GDScript is interpreted, so saving a `.gd` shows new `@export`s instantly. An Odin
// `@export` lives in the COMPILED scripts dll, so it does NOT exist until that dll is
// REBUILT. Inside a running editor the dll is loaded once and never recompiled, so a
// freshly-added `@export` only appears after a full quit + relaunch.
//
// This coordinator closes that gap, GATED ON THE EDITOR (engine_is_editor_hint) so a
// running GAME never rebuilds:
//   1. On save the editor calls `OdinScript._reload` (script.odin v_reload), which calls
//      `reload_request`. We resolve the odin compiler + project/scripts dirs on the MAIN
//      thread (Godot calls must be main-thread) and kick `build/build_scripts.sh` on a
//      BACKGROUND worker — the compile takes seconds and must NOT freeze the editor.
//   2. When the build finishes the worker sets `swap_ready`. The next editor `_frame`
//      (OdinLanguage._frame -> lv_frame, MAIN thread) calls `reload_pump_main_thread`,
//      which performs the Phase-4 in-process dll swap (`odin_scripts_reload`) and then
//      refreshes the editor's placeholder property lists (refresh_placeholder_exports).
//
// Threading rules mirror the async validator (core/diag/async.odin): all shared state is
// touched ONLY under `mutex`; at most ONE build is in-flight; saves that arrive mid-build
// are COALESCED into a single pending job (no build pile-up); the worker NEVER calls Godot
// (it only shells out + flips flags); the swap + all gdext calls happen on the main thread.
// ----------------------------------------------------------------------------

@(private)
Reload_State :: struct {
	mutex:          sync.Mutex,

	// A build is currently running on the worker thread.
	build_running:  bool,
	// A save arrived while a build ran: rebuild once more when the current one finishes.
	// Only the LATEST pending command is kept (coalesced).
	build_pending:  bool,
	pending_cmd:    string, // heap-owned; transferred to the worker when kicked

	// A build COMPLETED successfully: the main thread must swap the dll + refresh.
	swap_ready:     bool,
	// A build FAILED: the main thread must surface the error in the editor Output (the worker
	// thread cannot call into Godot). Read + cleared by reload_pump_main_thread.
	build_failed:   bool,
	// Wall-clock duration of the last finished build (ms) — surfaced as a UX hint on reload.
	last_build_ms:  f64,

	// Content hash of the authored sources the LAST kicked build was for. Guards against a
	// rebuild LOOP: the editor's filesystem watcher re-triggers `_reload` when the build
	// writes the `*.gen.odin` artifacts, but those don't change the authored-source hash, so
	// an unchanged hash is skipped. 0 == nothing built yet.
	last_hash:      u64,
	have_last_hash: bool,

	// One-time "odin not found" warning guard (don't spam on every save).
	warned_no_odin: bool,
}

@(private)
g_reload: Reload_State

@(private)
Reload_Job :: struct {
	state: ^Reload_State,
	cmd:   string, // heap-owned shell command; the worker frees it
}

// Absolute filesystem path of `res://` for the open project (globalized, trailing-/ trimmed).
@(private = "file")
reload_project_dir :: proc(allocator := context.allocator) -> string {
	gres := godot.new_string_odin("res://")
	global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
	s := string_to_odin(global, allocator)
	return strings.trim_suffix(s, "/")
}

// The scripts PACKAGE directory to (re)compile. ProjectSetting `odin_godot/scripts_dir`
// (globalized if `res://`-relative) overrides; default `<proj>/scripts` (the convention used
// by the examples + tests). Caller owns the result.
@(private = "file")
reload_scripts_dir :: proc(proj: string, allocator := context.allocator) -> string {
	ps := godot.singleton_project_settings()
	key := godot.new_string_cstring("odin_godot/scripts_dir")
	if bool(godot.project_settings_has_setting(ps, key)) {
		def := godot.Variant{}
		v := godot.project_settings_get_setting(ps, key, def)
		s := godot.variant_to_string(&v)
		cand := string_to_odin(s, allocator)
		if cand != "" {
			// Globalize a res://-relative value; an absolute path passes through.
			gs := godot.new_string_odin(cand)
			global := godot.project_settings_globalize_path(ps, gs)
			out := string_to_odin(global, allocator)
			delete(cand, allocator)
			return strings.trim_suffix(out, "/")
		}
		delete(cand, allocator)
	}
	return strings.concatenate({proj, "/scripts"}, allocator)
}

// Content hash of the AUTHORED `.odin` sources in `scripts` (skipping generated `*.gen.odin`).
// Used to skip a rebuild when nothing the compiler cares about actually changed — which is
// what makes the feature loop-safe against the editor re-importing the build's `*.gen.odin`
// output. Hashes each file's name + bytes (fnv64a chained); unreadable dir => 0.
@(private = "file")
hash_sources :: proc(scripts: string) -> u64 {
	fis, err := os.read_directory_by_path(scripts, -1, context.temp_allocator)
	if err != nil {
		return 0
	}
	h: u64 = 0xcbf29ce484222325 // fnv64a offset basis
	for fi in fis {
		// Only authored sources; skip generated artifacts (a directory named `*.odin` is
		// pathological — read_entire_file simply errors on it and it contributes nothing).
		if !strings.has_suffix(fi.name, ".odin") || strings.has_suffix(fi.name, ".gen.odin") {
			continue
		}
		data, rerr := os.read_entire_file(fi.fullpath, context.temp_allocator)
		if rerr == nil {
			h = hash.fnv64a(transmute([]byte)fi.name, h)
			h = hash.fnv64a(data, h)
		}
	}
	return h
}

// `reload_request` — kick a background rebuild of the scripts dll (editor only).
//
// Called on the MAIN THREAD from `OdinScript._reload` (save) and from the manual editor
// reload virtuals. Resolves everything that needs Godot here, then hands an opaque shell
// command to a worker thread. Returns immediately (non-blocking).
@(private)
reload_request :: proc() {
	// Hard gate: never rebuild outside the editor (a shipped game has no compiler and must
	// never shell out to one).
	if !bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		return
	}
	context.allocator = core_allocator()

	odin_bin, found := resolve_odin_bin()
	if !found {
		// The editor process can't see `odin` (commonly: launched from Finder, so the
		// nix-store odin isn't on PATH). Warn ONCE with an actionable fix, then skip — a
		// dev-experience feature must never break the editor.
		sync.lock(&g_reload.mutex)
		warn := !g_reload.warned_no_odin
		g_reload.warned_no_odin = true
		sync.unlock(&g_reload.mutex)
		if warn {
			msg := godot.new_string_cstring(
				"odin_godot: `odin` not found — live `@export` reload-on-save is OFF. Fix: set the " +
				"`odin_godot/odin_bin` project setting to your odin binary (absolute path), or launch " +
				"the editor from a shell where `odin` is on PATH.",
			)
			godot.gd_push_warning(godot.variant_from_string(&msg))
		}
		return
	}
	defer delete(odin_bin)

	root := odin_collection_root()
	defer delete(root)
	proj := reload_project_dir()
	defer delete(proj)
	scripts := reload_scripts_dir(proj)
	defer delete(scripts)

	// Resolve the odin binary's DIRECTORY too: build_scripts.sh runs `"$ODIN"` directly, but
	// it also recursively shells `odin build` for the scriptgen step — prepend the dir to PATH
	// so a bare `odin` resolves there as well. `ODIN=<bin>` makes the scripts/core builds use
	// the exact resolved compiler; `SKIP_CORE=1` skips the (stable) core dll — only the scripts
	// dll carries `@export` changes. stdout -> stderr so the editor console shows progress.
	odin_dir := odin_bin
	if idx := strings.last_index_byte(odin_bin, '/'); idx >= 0 {
		odin_dir = odin_bin[:idx]
	}
	cmd := fmt.aprintf(
		"PATH='%s':\"$PATH\" ODIN='%s' ODIN_GODOT_ROOT='%s' SKIP_CORE=1 bash '%s/build/build_scripts.sh' '%s' '%s' 1>&2",
		odin_dir,
		odin_bin,
		root,
		root,
		proj,
		scripts,
	)

	src_hash := hash_sources(scripts)

	sync.lock(&g_reload.mutex)
	defer sync.unlock(&g_reload.mutex)

	// Loop guard: if the authored sources are byte-identical to the last build we kicked,
	// there is nothing new to compile — skip (this is what the editor re-importing our own
	// `*.gen.odin` output looks like). A hash of 0 (unreadable dir) always proceeds.
	if src_hash != 0 && g_reload.have_last_hash && g_reload.last_hash == src_hash {
		delete(cmd)
		return
	}
	g_reload.last_hash = src_hash
	g_reload.have_last_hash = true

	// Tell the user their save is being processed. The rebuild is async (background worker),
	// so without this the editor looks idle until the swap lands a few seconds later — a new
	// `@export` or code change appears to "do nothing" in the meantime. Goes to the editor
	// Output panel (godot.print), not just stderr, so it shows regardless of how the editor
	// was launched. Safe here: reload_request runs on the MAIN thread.
	godot.print_str("odin_godot: rebuilding scripts…")

	if g_reload.build_running {
		// Coalesce: keep only the LATEST pending command (replace any earlier one).
		if g_reload.build_pending && g_reload.pending_cmd != "" {
			delete(g_reload.pending_cmd)
		}
		g_reload.pending_cmd = cmd // transfer ownership
		g_reload.build_pending = true
	} else {
		g_reload.build_running = true
		spawn_build_worker(cmd) // transfer ownership
	}
}

@(private = "file")
spawn_build_worker :: proc(cmd: string) {
	job := new(Reload_Job, core_allocator())
	job^ = Reload_Job {
		state = &g_reload,
		cmd   = cmd,
	}
	ctx := runtime.default_context()
	ctx.allocator = core_allocator()
	thread.create_and_start_with_data(rawptr(job), build_worker_entry, init_context = ctx, self_cleanup = true)
}

@(private = "file")
build_worker_entry :: proc(data: rawptr) {
	job := (^Reload_Job)(data)

	// Private heap context — never the Godot context, and we issue NO Godot calls here.
	context = runtime.default_context()
	context.allocator = runtime.heap_allocator()

	ccmd := strings.clone_to_cstring(job.cmd)
	start := time.tick_now()
	rc := libc.system(ccmd)
	build_ms := time.duration_milliseconds(time.tick_since(start))
	delete(ccmd)
	if rc != 0 {
		os.write_string(os.stderr, "odin reload: background scripts build FAILED (see output above)\n")
	}

	state := job.state
	sync.lock(&state.mutex)
	state.build_running = false
	state.last_build_ms = build_ms
	if rc == 0 {
		// Only schedule a swap when the rebuild succeeded — never swap to a stale/unchanged
		// dll on a broken build (the old code keeps running until the next good save).
		state.swap_ready = true
	} else {
		// Surface the failure on the MAIN thread (this worker can't call Godot).
		state.build_failed = true
		// Failed build: forget the source hash so the SAME source can be retried (e.g. after a
		// transient error). A real source change would change the hash and rebuild regardless.
		state.have_last_hash = false
	}
	next_cmd: string
	has_next := false
	if state.build_pending {
		next_cmd = state.pending_cmd
		state.pending_cmd = ""
		state.build_pending = false
		state.build_running = true
		has_next = true
	}
	sync.unlock(&state.mutex)

	if has_next {
		spawn_build_worker(next_cmd)
	}

	delete(job.cmd)
	free(job, core_allocator())
}

// `reload_pump_main_thread` — drive a completed build's swap on the MAIN thread.
//
// Called every editor frame from OdinLanguage._frame (lv_frame). Cheap when idle (one
// mutex check). When a background build has finished it performs the in-process dll swap
// (Phase-4 `odin_scripts_reload`: copies to a unique path to dodge macOS dlopen caching,
// re-pulls the manifest, re-binds live instances) and then refreshes the editor's
// placeholder property lists so a newly-added `@export` appears in the Inspector.
@(private)
reload_pump_main_thread :: proc() {
	sync.lock(&g_reload.mutex)
	ready := g_reload.swap_ready
	g_reload.swap_ready = false
	failed := g_reload.build_failed
	g_reload.build_failed = false
	build_ms := g_reload.last_build_ms
	sync.unlock(&g_reload.mutex)

	// A finished build failed: surface it prominently in the editor (Output + Errors). The
	// compiler error itself already streamed to the Output above (build_scripts.sh 1>&2).
	if failed {
		msg := godot.new_string_cstring(
			"odin_godot: scripts build FAILED — your change is NOT live. See the compiler error " +
			"in the Output above.",
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
	}

	if !ready {
		return
	}

	context.allocator = core_allocator()
	if odin_scripts_reload() {
		// Real (tool) instances are already re-bound by the swap; placeholders (the common
		// non-tool editor case) still hold the OLD property list, so re-push their exports.
		refresh_placeholder_exports()
		os.write_string(os.stderr, "odin reload: scripts dll swapped + exports refreshed (RELOAD_SWAPPED)\n")
		// Editor-Output confirmation (with the build time) so the user knows their save is now
		// live — the visible bookend to the "rebuilding…" message from reload_request.
		godot.print_str(fmt.tprintf("odin_godot: scripts reloaded — your change is live (%.1fs)", build_ms / 1000))
	}
}
