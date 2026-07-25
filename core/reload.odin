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
	// File the build's combined stdout+stderr is captured to (so the COMPILER ERROR can be
	// shown in Godot's Output, not just the terminal). Constant per project; set once.
	log_path:       string,
	// On failure, the worker reads `log_path` into here; the pump prints it (filtered) + frees.
	build_output:   string,
	// Wall-clock duration of the last finished build (ms) — surfaced as a UX hint on reload.
	last_build_ms:  f64,
	// PERSISTENT outcome of the most recent finished build (unlike build_failed, which is a
	// one-shot the pump consumes). Read by the toolbar status widget and the Play gate
	// (core/build_status.odin): a red badge must stay red, and Play must stay blocked,
	// until a build actually SUCCEEDS — not just until the failure has been printed once.
	last_build_failed: bool,

	// PER-MODULE content hashes of the authored sources the LAST kicked build was for,
	// keyed by module name ("" == the main scripts dir; "<name>" == res://modules/<name>).
	// Guards against a rebuild LOOP: the editor's filesystem watcher re-triggers `_reload`
	// when the build writes the `*.gen.odin` artifacts, but those don't change the
	// authored-source hash, so an unchanged module is skipped — which is ALSO the payoff:
	// a save in one module rebuilds only that module's dll. Missing key == never built.
	last_hashes:    map[string]u64,
	// Modules the next successful swap must hot-reload (heap-owned names, deduped).
	// Appended by reload_request for each module it kicks a rebuild of; drained by the
	// pump once swap_ready fires; cleared on build failure (never swap an unbuilt dll).
	swap_modules:   [dynamic]string,

	// One-time "odin not found" warning guard (don't spam on every save).
	warned_no_odin: bool,

	// THE DELETION PROBE (main thread only — touched exclusively from the
	// frame pump, no mutex): a names-only fingerprint of the script tree,
	// re-taken every ~2s. Saves already trigger rebuilds; DELETIONS never
	// did — a script removed in the dock (or by git) left its generated code
	// behind, breaking the next build invisibly (the dock hides gen files,
	// and the staleness guard still hashes the vanished source). A changed
	// name SET fires reload_request; the rebuild's regeneration does the rest.
	// Catches creations from outside the editor as a bonus.
	probe_hash: u64,
	probe_tick: int,
	// The edge trigger above can MISS a pulse: a source created and deleted
	// inside one probe window samples as "no change" while the create already
	// materialized its generated code (the editor's own import can kick that
	// build). So the probe is also LEVEL-triggered on the inconsistent state
	// itself — a `// ==== <src>` section in odin_godot_scripts.gen.odin whose
	// source is gone, or a pre-consolidation `<name>.gen.odin` without its
	// sibling. This remembers the orphan set already kicked, so a sweep that
	// cannot succeed (read-only tree, ...) fires once instead of every two seconds.
	probe_orphans: u64,
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
	h: u64 = 0xcbf29ce484222325 // fnv64a offset basis
	hash_sources_dir(scripts, &h)
	if h == 0xcbf29ce484222325 {
		return 0 // nothing hashed (unreadable or empty) — treat like "unknown", always build
	}
	return h
}

// Fold the shared tree's content hash into ONE module's, so an edit under res://shared
// invalidates every module that could import it. `module` == 0 (unreadable/empty dir)
// stays 0 — "unknown", always build. `shared` == 0 (no shared/ tree at all) returns the
// module hash untouched, so a project without one behaves exactly as it did before.
@(private = "file")
mix_shared_hash :: proc(module, shared: u64) -> u64 {
	if module == 0 || shared == 0 {
		return module
	}
	b := transmute([8]u8)shared
	return hash.fnv64a(b[:], module)
}

// Recursive worker: the scripts dir can hold sub-package directories (the build compiles
// them too), so an edit anywhere under it must change the hash — a top-level-only scan
// made saves in a subdirectory silently skip the rebuild.
@(private = "file")
hash_sources_dir :: proc(dir: string, h: ^u64) {
	fis, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
	if err != nil {
		return
	}
	for fi in fis {
		if fi.type == .Directory {
			// Skip hidden dirs and build output — not compiler inputs.
			if strings.has_prefix(fi.name, ".") || fi.name == "bin" {
				continue
			}
			hash_sources_dir(fi.fullpath, h)
			continue
		}
		// Only authored sources; skip generated artifacts.
		if !strings.has_suffix(fi.name, ".odin") || strings.has_suffix(fi.name, ".gen.odin") {
			continue
		}
		data, rerr := os.read_entire_file(fi.fullpath, context.temp_allocator)
		if rerr == nil {
			h^ = hash.fnv64a(transmute([]byte)fi.name, h^)
			h^ = hash.fnv64a(data, h^)
		}
	}
}

// `reload_request` — kick a background rebuild of the scripts dll (editor only).
//
// Called on the MAIN THREAD from `OdinScript._reload` (save) and from the manual editor
// reload virtuals. Resolves everything that needs Godot here, then hands an opaque shell
// command to a worker thread. Returns immediately (non-blocking).
// `force` bypasses the unchanged-sources skip — used by the manual "Build Odin Scripts" editor
// action so a click always rebuilds (and gives feedback), even with nothing edited.
@(private)
reload_request :: proc(force := false) {
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
	// Capture the build's combined output to a log file (in bin/, which is build output + a
	// dotfile Godot ignores) instead of the terminal, so on failure the pump can show the
	// actual COMPILER ERROR in Godot's Output — not just to a terminal the GUI user never sees.
	// `> log 2>&1` (no pipe) preserves build_scripts.sh's exit code for the failure check.
	if g_reload.log_path == "" {
		g_reload.log_path = strings.concatenate({proj, "/bin/.odin_reload.log"})
	}
	// ---- enumerate the script modules: the main scripts dir + each res://modules/<name> ----
	Candidate :: struct {
		name: string, // "" == the main module
		dir:  string,
		hash: u64,
	}
	// THE SHARED VOCABULARY TREE (res://shared): read-only packages any module may
	// import (scriptgen/shared.odin). It belongs to no module, so hashing the module
	// dirs alone would make an edit there rebuild NOTHING. Fold its hash into EVERY
	// candidate: a shared edit invalidates all modules, which is correct (any of them
	// may import it) and rare enough to be cheap. No shared/ dir -> 0 -> every hash is
	// exactly what it was before.
	shared_dir := strings.concatenate({proj, "/shared"}, context.temp_allocator)
	shared_h := hash_sources(shared_dir)

	cands := make([dynamic]Candidate, context.temp_allocator)
	append(
		&cands,
		Candidate{
			name = "",
			dir  = strings.clone(scripts, context.temp_allocator),
			hash = mix_shared_hash(hash_sources(scripts), shared_h),
		},
	)
	// Every platform enumerates modules: build_scripts.sh (POSIX) and build_scripts.ps1
	// (Windows, -ScriptsDir/-SkipModules) both build one named scripts dir per invocation.
	mroot := strings.concatenate({proj, "/modules"}, context.temp_allocator)
	if fis, rerr := os.read_directory_by_path(mroot, -1, context.temp_allocator); rerr == nil {
		for fi in fis {
			if fi.type != .Directory || strings.has_prefix(fi.name, ".") {
				continue
			}
			append(
				&cands,
				Candidate{
					name = strings.clone(fi.name, context.temp_allocator),
					dir  = strings.clone(fi.fullpath, context.temp_allocator),
					hash = mix_shared_hash(hash_sources(fi.fullpath), shared_h),
				},
			)
		}
	}

	sync.lock(&g_reload.mutex)
	defer sync.unlock(&g_reload.mutex)

	if g_reload.last_hashes == nil {
		g_reload.last_hashes = make(map[string]u64)
	}

	// Loop guard, PER MODULE: skip modules whose authored sources are byte-identical to the
	// last build we kicked (this is what the editor re-importing our own `*.gen.odin` output
	// looks like) — which is ALSO the multi-module payoff: a save in ONE module rebuilds
	// only that module's dll. A hash of 0 (unreadable dir) always proceeds.
	changed := make([dynamic]Candidate, context.temp_allocator)
	for c in cands {
		prev, seen := g_reload.last_hashes[c.name]
		if !force && c.hash != 0 && seen && prev == c.hash {
			continue
		}
		append(&changed, c)
	}
	if len(changed) == 0 {
		// Diagnosable, not silent: this is normally the editor re-importing our own gen
		// output, but it's also what a save looks like when something upstream is stale.
		os.write_string(os.stderr, "odin reload: authored sources unchanged — rebuild skipped\n")
		return
	}
	for c in changed {
		if c.name in g_reload.last_hashes {
			g_reload.last_hashes[c.name] = c.hash
		} else {
			g_reload.last_hashes[strings.clone(c.name)] = c.hash
		}
		// Record the module for the pump's swap pass (deduped; heap-owned clone).
		already := false
		for s in g_reload.swap_modules {
			if s == c.name {
				already = true
				break
			}
		}
		if !already {
			append(&g_reload.swap_modules, strings.clone(c.name))
		}
	}

	// ---- assemble the shell command: ONE build invocation per CHANGED module ----
	cmd: string
	when ODIN_OS == .Windows {
		// libc.system routes through cmd.exe: drive the PowerShell counterpart of
		// build_scripts.sh (native MSVC toolchain — see build_scripts.ps1's header).
		// cmd.exe quoting: double quotes; ^-escaping is not needed for these paths.
		// PER-MODULE parity with the POSIX branch below: one invocation per CHANGED
		// module, scoped to exactly its dir via -ScriptsDir, with -SkipModules the
		// BUILD_MODULES=0 equivalent (no chaining of the other modules).
		parts := strings.builder_make(context.temp_allocator)
		for c, i in changed {
			if i > 0 {
				strings.write_string(&parts, " && ")
			}
			fmt.sbprintf(
				&parts,
				`powershell -NoProfile -ExecutionPolicy Bypass -File "%s\build\build_scripts.ps1" -Root "%s" -Project "%s" -ScriptsDir "%s" -Odin "%s" -SkipCore -SkipModules`,
				root,
				root,
				proj,
				c.dir,
				odin_bin,
			)
		}
		// `if not exist` needs the trailing `\` to test for a DIRECTORY; parentheses group
		// the chain for the one log redirect (mirrors the POSIX subshell + mkdir -p below).
		cmd = fmt.aprintf(
			`if not exist "%s\bin\" mkdir "%s\bin" & ( %s ) > "%s" 2>&1`,
			proj,
			proj,
			strings.to_string(parts),
			g_reload.log_path,
		)
	} else {
		// Every interpolated path goes through shell_quote (paths carry apostrophes; the
		// scripts-dir/odin-bin settings are user-editable text — see core/common.odin).
		// BUILD_MODULES=0 keeps each invocation scoped to exactly the one dir passed to it
		// (build_scripts.sh would otherwise chain the modules/* loop after a main build).
		q_proj := shell_quote(proj, context.temp_allocator)
		q_odin_dir := shell_quote(odin_dir, context.temp_allocator)
		q_odin_bin := shell_quote(odin_bin, context.temp_allocator)
		q_root := shell_quote(root, context.temp_allocator)
		q_log := shell_quote(g_reload.log_path, context.temp_allocator)
		parts := strings.builder_make(context.temp_allocator)
		for c, i in changed {
			if i > 0 {
				strings.write_string(&parts, " && ")
			}
			q_dir := shell_quote(c.dir, context.temp_allocator)
			fmt.sbprintf(
				&parts,
				"PATH=%s:\"$PATH\" ODIN=%s ODIN_GODOT_ROOT=%s SKIP_CORE=1 BUILD_MODULES=0 bash %s/build/build_scripts.sh %s %s",
				q_odin_dir,
				q_odin_bin,
				q_root,
				q_root,
				q_proj,
				q_dir,
			)
		}
		// Parentheses (a subshell), NOT `{ ...; }`: Odin's fmt parses braces as its own
		// placeholder syntax (they'd emit %!(MISSING CLOSE BRACE) into the shell command),
		// and the subshell grouping is equivalent for this redirect.
		cmd = fmt.aprintf(
			"mkdir -p %s/bin; ( %s ) > %s 2>&1",
			q_proj,
			strings.to_string(parts),
			q_log,
		)
	}

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
	state := job.state

	// On failure, slurp the captured build log so the MAIN thread can show the actual compiler
	// error in Godot's Output (the worker must not call Godot). Allocated on the long-lived
	// core allocator; the pump frees it.
	log_content: string
	if rc != 0 {
		os.write_string(os.stderr, "odin reload: background scripts build FAILED (see output above)\n")
		if state.log_path != "" {
			if data, rerr := os.read_entire_file(state.log_path, core_allocator()); rerr == nil {
				log_content = string(data)
			}
		}
	}

	sync.lock(&state.mutex)
	state.build_running = false
	state.last_build_ms = build_ms
	state.last_build_failed = rc != 0
	if rc == 0 {
		// Only schedule a swap when the rebuild succeeded — never swap to a stale/unchanged
		// dll on a broken build (the old code keeps running until the next good save).
		state.swap_ready = true
	} else {
		// Surface the failure on the MAIN thread (this worker can't call Godot).
		state.build_failed = true
		// Failed build: forget the source hashes so the SAME sources can be retried (e.g.
		// after a transient error). A real source change would rebuild regardless.
		clear(&state.last_hashes)
		// Never swap modules whose rebuild just failed — drop the pending swap set. (If an
		// EARLIER coalesced build succeeded, swap_ready stays set and the pump falls back to
		// swapping the main module.)
		for s in state.swap_modules {
			delete(s, core_allocator())
		}
		clear(&state.swap_modules)
		if state.build_output != "" {delete(state.build_output, core_allocator())}
		state.build_output = log_content
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

// Print the meaningful lines of a failed build's captured output into Godot's Output, dropping
// the benign linker dead-strip warnings (from scriptgen's own build) and scriptgen progress
// lines so the actual `path(line:col) Error: …` stands out. print_str -> Output dock + stdout.
@(private = "file")
print_build_errors :: proc(output: string) {
	b := strings.builder_make(context.temp_allocator)
	it := output
	for line in strings.split_lines_iterator(&it) {
		if strings.contains(line, "could not find symbol") {continue}
		if strings.has_prefix(line, "warning:") {continue}
		if strings.has_prefix(line, "scriptgen: wrote") {continue}
		if strings.has_prefix(line, "scriptgen: generated") {continue}
		strings.write_string(&b, line)
		strings.write_byte(&b, '\n')
	}
	text := strings.trim_space(strings.to_string(b))
	if text == "" {
		return
	}
	godot.print_str(strings.concatenate({"── odin_godot build errors ──\n", text}, context.temp_allocator))
}

// `reload_pump_main_thread` — drive a completed build's swap on the MAIN thread.
//
// Called every editor frame from OdinLanguage._frame (lv_frame). Cheap when idle (one
// mutex check). When a background build has finished it performs the in-process dll swap
// (Phase-4 `odin_scripts_reload`: copies to a unique path to dodge macOS dlopen caching,
// re-pulls the manifest, re-binds live instances) and then refreshes the editor's
// placeholder property lists so a newly-added `@export` appears in the Inspector.
// Names-only fingerprint of the authored `.odin` set under `dir` (recursive,
// generated artifacts skipped) — cheap enough for a ~2s cadence: readdir only,
// no file contents.
@(private = "file")
names_hash_dir :: proc(dir: string, h: ^u64) {
	fis, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
	if err != nil {
		return
	}
	for fi in fis {
		if fi.type == .Directory {
			if strings.has_prefix(fi.name, ".") || fi.name == "bin" {
				continue
			}
			names_hash_dir(fi.fullpath, h)
			continue
		}
		if !strings.has_suffix(fi.name, ".odin") || strings.has_suffix(fi.name, ".gen.odin") {
			continue
		}
		h^ = hash.fnv64a(transmute([]byte)fi.name, h^)
	}
}

// scriptgen's per-DIR artifacts: ONE consolidated `odin_godot_scripts.gen.odin` holding
// every script's generated section, plus the staleness guard and the boot shim. None of
// them has an authored `<base>.odin` sibling, so the file-level pairing rule below skips
// them — the consolidated file is checked SECTION by section instead.
@(private = "file")
SCRIPTS_GEN_NAME :: "odin_godot_scripts.gen.odin"
@(private = "file")
GUARD_GEN_NAME :: "odin_godot_guard.gen.odin"
@(private = "file")
BOOT_GEN_NAME :: "odin_godot_boot.gen.odin"

// The banner scriptgen writes above each script's section: `// ==== mob.odin (class Mob) ====`.
@(private = "file")
SECTION_BANNER :: "// ==== "

// Hash the ORPHANED SECTIONS of a consolidated artifact: each `// ==== <src> (class …`
// banner whose authored `<src>` is gone. That is the post-consolidation shape of "generated
// code for a source that no longer exists" — the state that breaks the next build (the
// section names vanished procs, and the staleness guard `#load_hash`es a missing file).
@(private = "file")
orphan_sections_hash :: proc(gen_path, dir: string, h: ^u64) {
	data, rerr := os.read_entire_file(gen_path, context.temp_allocator)
	if rerr != nil {
		return
	}
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		if !strings.has_prefix(line, SECTION_BANNER) {
			continue
		}
		rest := line[len(SECTION_BANNER):]
		cut := strings.index(rest, " (")
		if cut <= 0 {
			continue
		}
		src := rest[:cut]
		full := strings.concatenate({dir, "/", src}, context.temp_allocator)
		if !os.exists(full) {
			h^ = hash.fnv64a(transmute([]byte)src, h^)
		}
	}
}

// Fingerprint of the ORPHANED generated code under `dir` (recursive). The FNV basis back
// means "nothing orphaned". Two shapes count, because both break the next build and both
// are healed by the same rebuild:
//
//   1. A SECTION of `odin_godot_scripts.gen.odin` whose authored source is gone — the
//      everyday case since scriptgen emits one artifact per dir.
//   2. A per-source `<name>.gen.odin` with no `<name>.odin` — either a stale file from a
//      build made before consolidation, or one restored by a branch switch. scriptgen's
//      orphan sweep reaps these on its next run.
@(private = "file")
orphans_hash_dir :: proc(dir: string, h: ^u64) {
	fis, err := os.read_directory_by_path(dir, -1, context.temp_allocator)
	if err != nil {
		return
	}
	for fi in fis {
		if fi.type == .Directory {
			if strings.has_prefix(fi.name, ".") || fi.name == "bin" {
				continue
			}
			orphans_hash_dir(fi.fullpath, h)
			continue
		}
		if !strings.has_suffix(fi.name, ".gen.odin") {
			continue
		}
		if fi.name == SCRIPTS_GEN_NAME {
			orphan_sections_hash(fi.fullpath, dir, h)
			continue
		}
		if fi.name == GUARD_GEN_NAME || fi.name == BOOT_GEN_NAME {
			continue // per-dir shims: unpaired by design
		}
		src := strings.concatenate(
			{fi.fullpath[:len(fi.fullpath) - len(".gen.odin")], ".odin"},
			context.temp_allocator,
		)
		if !os.exists(src) {
			h^ = hash.fnv64a(transmute([]byte)fi.name, h^)
		}
	}
}

// The frame pump's deletion probe (see Reload_State.probe_hash/probe_orphans).
@(private = "file")
reload_probe_fs :: proc() {
	g_reload.probe_tick += 1
	if g_reload.probe_tick < 120 { // ~2s at editor frame rates
		return
	}
	g_reload.probe_tick = 0
	context.allocator = core_allocator()
	proj := reload_project_dir(context.temp_allocator)
	scripts := reload_scripts_dir(proj, context.temp_allocator)

	// LEVEL trigger first: generated code for a source that no longer exists IS
	// the broken state, however the tree got there — force past the
	// unchanged-sources skip (deleting an EMPTY source leaves the content
	// aggregate untouched) so scriptgen's regeneration always runs. One shot per
	// distinct orphan set. This is what catches a create+delete inside ONE probe
	// window, which the name-set edge trigger below samples as "no change".
	FNV_BASIS :: u64(0xcbf29ce484222325)
	fired := false
	orphans := FNV_BASIS
	orphans_hash_dir(scripts, &orphans)
	if orphans != FNV_BASIS {
		if orphans != g_reload.probe_orphans {
			g_reload.probe_orphans = orphans
			fired = true
			godot.print_str("odin_godot: generated code for a deleted script on disk — rebuilding to sweep")
			reload_request(force = true)
		}
	} else {
		g_reload.probe_orphans = 0
	}

	// EDGE trigger: a changed authored-name set (creations from git pulls,
	// external tools, ... — deletions too, when the pulse is visible).
	h := FNV_BASIS
	names_hash_dir(scripts, &h)
	// The shared vocabulary tree rides along: a shared source added or deleted from
	// OUTSIDE the editor (git pull, another tool) is a rebuild for every module, and
	// reload_request's per-module hashes — which fold shared in — decide the rest.
	names_hash_dir(strings.concatenate({proj, "/shared"}, context.temp_allocator), &h)
	if h == FNV_BASIS {
		return // unreadable/empty: leave the baseline alone
	}
	old := g_reload.probe_hash
	g_reload.probe_hash = h
	if old != 0 && old != h && !fired {
		// (!fired: the orphan sweep already kicked a rebuild this tick)
		godot.print_str("odin_godot: script set changed on disk — rebuilding (stale gen files sweep with it)")
		reload_request()
	}
}

@(private)
reload_pump_main_thread :: proc() {
	if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		reload_probe_fs()
	}
	sync.lock(&g_reload.mutex)
	// Don't swap while a coalesced follow-up build is STILL RUNNING: build A set
	// swap_ready, but build B's linker may be rewriting the dll right now — the swap
	// would snapshot a half-written image. Leave swap_ready set; B re-sets it (or flags
	// failure) and the next frame swaps a settled dll.
	ready := g_reload.swap_ready && !g_reload.build_running
	swap_names: []string
	if ready {
		g_reload.swap_ready = false
		// Drain the per-module swap set (ownership of the heap-owned names moves here).
		swap_names = make([]string, len(g_reload.swap_modules), context.temp_allocator)
		copy(swap_names, g_reload.swap_modules[:])
		clear(&g_reload.swap_modules)
	}
	failed := g_reload.build_failed
	g_reload.build_failed = false
	build_out := g_reload.build_output // transfer ownership to this frame
	g_reload.build_output = ""
	build_ms := g_reload.last_build_ms
	sync.unlock(&g_reload.mutex)

	// A finished build failed: print the ACTUAL compiler error into Godot's Output (the build
	// log was captured to a file, not the terminal — a GUI user never sees the terminal), then a
	// prominent red summary.
	if failed {
		if build_out != "" {
			print_build_errors(build_out)
			delete(build_out, core_allocator())
		}
		msg := godot.new_string_cstring(
			"odin_godot: scripts build FAILED — your change is NOT live (compiler errors above).",
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
	} else if build_out != "" {
		delete(build_out, core_allocator())
	}

	if !ready {
		return
	}

	context.allocator = core_allocator()
	// Swap each module the finished build(s) covered. An empty drained set (a failed
	// coalesced build cleared it while an earlier success left swap_ready) falls back to
	// the main module — the pre-spike behavior.
	swapped := 0
	if len(swap_names) == 0 {
		if odin_scripts_reload() {
			swapped += 1
		}
	} else {
		for name in swap_names {
			if odin_scripts_reload(name) {
				swapped += 1
			}
			delete(name) // heap-owned clone from reload_request
		}
	}
	if swapped > 0 {
		// Real (tool) instances are already re-bound by the swap; placeholders (the common
		// non-tool editor case) still hold the OLD property list, so re-push their exports.
		refresh_placeholder_exports()
		os.write_string(os.stderr, "odin reload: scripts dll swapped + exports refreshed (RELOAD_SWAPPED)\n")
		// Editor-Output confirmation (with the build time) so the user knows their save is now
		// live — the visible bookend to the "rebuilding…" message from reload_request.
		godot.print_str(fmt.tprintf("odin_godot: scripts reloaded — your change is live (%.1fs)", build_ms / 1000))
	}
}
