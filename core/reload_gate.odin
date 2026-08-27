#+build darwin, linux, windows
package core

import "core:sync"

// Reload/execution ownership gate.
//
// Godot may enter ScriptInstance callbacks from worker threads (notably during
// threaded resource loading). A hot reload mutates the descriptor map, per-class
// caches, and every live instance's desc/cache/user tuple, so merely locking the live
// registry while copying its pointers is not enough: an old trampoline can still be
// executing while its instance is migrated.
//
// The gate is writer-preferring:
//   - the outermost callback/access on a thread takes one shared execution lease;
//   - nested calls are a TLS counter only (script -> Godot -> script is common);
//   - reload closes the gate, drains every outer lease, then owns the mutable graph;
//   - callbacks re-entered synchronously by Godot on the reload thread bypass the
//     closed gate, so lifecycle.reload and onready resolution cannot deadlock.
//
// A reload may NOT start inside a script execution lease. The current script frame
// would return into old code with a potentially reallocated `self`, which no lock can
// make sound. Callers reject that case and ask the user to defer the reload instead.

@(private)
Script_Access_Gate :: struct {
	mutex:          sync.Mutex,
	changed:        sync.Cond,
	active_readers: int,
	reload_pending: bool,
}

@(private)
g_script_access: Script_Access_Gate

@(private, thread_local)
g_script_access_depth: int

@(private, thread_local)
g_script_access_counted: bool

@(private, thread_local)
g_script_reload_writer: bool

// Enter code that may read a scripts-DLL descriptor/proc pointer or an instance's
// desc/cache/user tuple. Pair with script_access_leave (normally via defer).
@(private)
script_access_enter :: proc "contextless" () {
	if g_script_access_depth > 0 {
		g_script_access_depth += 1
		return
	}

	// The reload owner is allowed to call through the NEW descriptor while the gate is
	// closed (reload hooks and synchronous Godot re-entry). It is not a reader that the
	// writer must wait for.
	if g_script_reload_writer {
		g_script_access_depth = 1
		g_script_access_counted = false
		return
	}

	sync.lock(&g_script_access.mutex)
	for g_script_access.reload_pending {
		sync.wait(&g_script_access.changed, &g_script_access.mutex)
	}
	g_script_access.active_readers += 1
	sync.unlock(&g_script_access.mutex)

	g_script_access_depth = 1
	g_script_access_counted = true
}

@(private)
script_access_leave :: proc "contextless" () {
	if g_script_access_depth <= 0 {return}
	g_script_access_depth -= 1
	if g_script_access_depth != 0 {
		return
	}

	counted := g_script_access_counted
	g_script_access_counted = false
	if !counted {
		return
	}

	sync.lock(&g_script_access.mutex)
	if g_script_access.active_readers > 0 {
		g_script_access.active_readers -= 1
	}
	if g_script_access.active_readers == 0 {
		sync.broadcast(&g_script_access.changed)
	}
	sync.unlock(&g_script_access.mutex)
}

// False means the current thread is executing script code. Reload must be deferred
// until that outer call returns; attempting an in-place reader->writer upgrade would
// deadlock and, more importantly, could invalidate the active frame's `self` pointer.
@(private)
script_reload_can_begin :: proc "contextless" () -> bool {
	return g_script_access_depth == 0 && !g_script_reload_writer
}

// Close the gate and wait for all callbacks which can still reference the old scripts
// generation. Must only be called when script_reload_can_begin returned true.
@(private)
script_reload_begin :: proc "contextless" () {
	sync.lock(&g_script_access.mutex)
	// Reload is normally main-thread-only, but serializing here makes the ownership
	// contract explicit even if two engine entry points race in the future.
	for g_script_access.reload_pending {
		sync.wait(&g_script_access.changed, &g_script_access.mutex)
	}
	g_script_access.reload_pending = true
	for g_script_access.active_readers != 0 {
		sync.wait(&g_script_access.changed, &g_script_access.mutex)
	}
	g_script_reload_writer = true
	sync.unlock(&g_script_access.mutex)
}

@(private)
script_reload_end :: proc "contextless" () {
	sync.lock(&g_script_access.mutex)
	g_script_reload_writer = false
	g_script_access.reload_pending = false
	sync.broadcast(&g_script_access.changed)
	sync.unlock(&g_script_access.mutex)
}
