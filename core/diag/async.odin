#+build darwin, linux, windows
package diag

// ----------------------------------------------------------------------------
// NON-BLOCKING validation coordinator.
//
// `OdinLanguage._validate` is called on the editor MAIN THREAD every time the user edits a
// script (debounced). The load-bearing work — `run_check_overlay` — shells `odin check` over
// the whole `godot` collection (1059 files / 341k lines) COLD, which takes 10-20s. Doing that
// synchronously on the main thread froze the editor for the entire check.
//
// This coordinator makes validation non-blocking: the main thread NEVER waits on `odin check`.
// Instead it consults a cache of the latest completed diagnostics (keyed by a content hash of
// the script + path) and kicks a single background worker thread to (re)compute when the
// content it sees is not already cached. `validate_async` returns INSTANTLY with the
// last-known result; the editor re-validates on its own debounce timer, so a freshly-computed
// result is picked up on a later call (~check-duration later) WITHOUT ever blocking the UI.
//
// SYNTAX errors don't wait for any of that: an in-process parse tier (syntax.odin, ~1ms)
// runs synchronously per call, so the common while-typing breakage squiggles on the FIRST
// debounce — and syntactically broken buffers never schedule the slow check at all.
//
// Threading rules (correctness over cleverness):
//   * All shared state lives in `Async_State` and is touched ONLY under `state.mutex`.
//   * The worker runs `run_check_overlay` (plain `Diagnostic{line,col,message}` data, NO Godot
//     objects) on a private context (heap allocator + a per-thread temp arena) so it never
//     touches the Godot/gdext context or races the main thread's temp allocator.
//   * At most ONE worker is in-flight. Edits that arrive while a worker runs are COALESCED into
//     a single LATEST-pending job, which the finishing worker kicks off — no thread pile-up.
//   * Cached diagnostic strings are heap-owned and freed when their slot is replaced.
//
// The Godot glue (building the result Dictionary from the returned plain data) stays in
// core/validate.odin and runs ONLY on the main thread. Headlessly testable: see tests/validate.
// ----------------------------------------------------------------------------

import "base:runtime"
import "core:hash"
import "core:strings"
import "core:sync"
import "core:thread"

// A unit of background work. Strings are owned (heap-cloned) copies so the worker is fully
// decoupled from the caller's (transient) buffers and from the Godot context.
@(private)
Validate_Job :: struct {
    state:    ^Async_State,
    hash:     u64,
    source:   string,
    abs_path: string,
    root:     string,
    odin_bin: string,
}

// Shared validation state. A single global instance (`g_validate`) backs the editor; tests may
// use their own local instance. Zero value is a valid, empty state.
Async_State :: struct {
    mutex:          sync.Mutex,

    // Last COMPLETED result (heap-owned). `have_result` gates the others.
    have_result:    bool,
    result_hash:    u64,
    result_valid:   bool,
    result_diags:   [dynamic]Diagnostic,

    // A worker PUBLISHED a result that no `_validate` call has consumed yet. The editor only
    // calls `_validate` when the text changes, so without a nudge a result computed after the
    // user's LAST edit would sit in the cache forever (the red-line squiggle never appears).
    // The main-thread frame pump reads-and-clears this (take_fresh) and pokes the script
    // editor to re-validate, which cache-hits the published result.
    fresh:          bool,

    // The single in-flight worker, if any.
    worker_running: bool,
    worker_hash:    u64,

    // Coalesced latest pending request (kicked when the running worker finishes).
    pending:        bool,
    pending_job:    Validate_Job,
}

// The editor-wide validation state used by core/validate.odin's `lv_validate`.
g_validate: Async_State

@(private)
async_alloc :: proc() -> runtime.Allocator {
    return runtime.heap_allocator()
}

// Content hash of the inputs that determine the diagnostics (the live buffer + the file it
// stands in for). fnv64a chained so the two are order-distinguished.
@(private)
hash_inputs :: proc(source, abs_path: string) -> u64 {
    h := hash.fnv64a(transmute([]byte)source)
    h = hash.fnv64a(transmute([]byte)abs_path, h)
    return h
}

@(private)
make_job :: proc(state: ^Async_State, h: u64, source, abs_path, root, odin_bin: string) -> Validate_Job {
    a := async_alloc()
    return Validate_Job {
        state    = state,
        hash     = h,
        source   = strings.clone(source, a),
        abs_path = strings.clone(abs_path, a),
        root     = strings.clone(root, a),
        odin_bin = strings.clone(odin_bin, a),
    }
}

@(private)
free_job :: proc(job: Validate_Job) {
    a := async_alloc()
    delete(job.source, a)
    delete(job.abs_path, a)
    delete(job.root, a)
    delete(job.odin_bin, a)
}

@(private)
free_diags :: proc(diags: ^[dynamic]Diagnostic) {
    a := async_alloc()
    for d in diags {
        delete(d.message, a)
    }
    delete(diags^)
    diags^ = nil
}

@(private)
clone_diags :: proc(src: []Diagnostic, allocator := context.allocator) -> []Diagnostic {
    out := make([]Diagnostic, len(src), allocator)
    for d, i in src {
        out[i] = Diagnostic{line = d.line, column = d.column, message = strings.clone(d.message, allocator)}
    }
    return out
}

// Spawn a detached, self-cleaning worker for `job`. Caller MUST hold `state.mutex` and have
// already set `worker_running`/`worker_hash`.
@(private)
spawn_worker :: proc(job: Validate_Job) {
    p := new(Validate_Job, async_alloc())
    p^ = job
    // A private heap context so the post-run hook in core:thread won't touch the (shared)
    // global temp allocator; worker_entry replaces the context with its own temp arena.
    ctx := runtime.default_context()
    ctx.allocator = async_alloc()
    thread.create_and_start_with_data(rawptr(p), worker_entry, init_context = ctx, self_cleanup = true)
}

@(private)
worker_entry :: proc(data: rawptr) {
    job := (^Validate_Job)(data)

    // Dedicated, race-free context: heap allocator + a private temp arena. Never the Godot
    // context, never the shared global temp allocator.
    context = runtime.default_context()
    context.allocator = async_alloc()
    temp: runtime.Default_Temp_Allocator
    runtime.default_temp_allocator_init(&temp, runtime.DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE, async_alloc())
    context.temp_allocator = runtime.Allocator {
        procedure = runtime.default_temp_allocator_proc,
        data      = &temp,
    }
    defer runtime.default_temp_allocator_destroy(&temp)

    // The slow part — runs entirely off the main thread.
    diags := run_check_overlay(job.source, job.abs_path, job.root, job.odin_bin, async_alloc())

    state := job.state
    sync.lock(&state.mutex)

    // Publish the result, replacing (and freeing) any prior cached diagnostics.
    free_diags(&state.result_diags)
    state.result_diags = diags
    state.result_hash = job.hash
    state.result_valid = len(diags) == 0
    state.have_result = true
    state.fresh = true
    state.worker_running = false

    // Coalesce: if newer content arrived while we ran, kick exactly one fresh worker for it.
    next: Validate_Job
    has_next := false
    if state.pending {
        next = state.pending_job
        state.pending = false
        state.pending_job = {}
        state.worker_running = true
        state.worker_hash = next.hash
        has_next = true
    }
    if has_next {
        spawn_worker(next) // transfers ownership of next's cloned strings
    }

    sync.unlock(&state.mutex)

    free_job(job^)
    free(job, async_alloc())
}

// Non-blocking validation entry. Returns INSTANTLY:
//   * a heap-independent COPY (in `allocator`) of the latest known diagnostics for `source`,
//   * `valid` = whether that result had zero diagnostics.
// Side effect: ensures a background worker is (or gets) scheduled to compute the diagnostics
// for THIS exact content if they aren't already cached. The caller owns the returned slice
// (and each `.message`) and must free them.
//
// Behaviour (two tiers — see syntax.odin's header):
//   - cache hit for this exact content  -> returns those diagnostics.
//   - SYNTAX errors (resident parse, ~1ms) -> published + returned NOW; the slow check is
//                                           never scheduled (it would stop at the same error).
//   - cache miss, no worker running     -> starts ONE worker, returns last-known (or empty).
//   - cache miss, worker already running -> coalesces this content as the LATEST pending job
//                                           (replacing any earlier pending), returns last-known.
validate_async :: proc(
    state: ^Async_State,
    source, abs_path, root, odin_bin: string,
    allocator := context.allocator,
) -> (diags: []Diagnostic, valid: bool) {
    h := hash_inputs(source, abs_path)

    // 1. Exact cache hit -> return immediately. The published result has now reached a
    // real `_validate` call, so any pending re-validate poke would be redundant.
    sync.lock(&state.mutex)
    if state.have_result && state.result_hash == h {
        state.fresh = false
        out := clone_diags(state.result_diags[:], allocator)
        ok := state.result_valid
        sync.unlock(&state.mutex)
        return out, ok
    }
    sync.unlock(&state.mutex)

    // 2. TIER 1 — the resident parser (~1ms, in-process). A syntax error is published and
    // returned right here: the squiggle lands on the FIRST debounce, and the slow check is
    // never scheduled for a buffer it couldn't type-check anyway. A worker already in flight
    // for OLDER content may later overwrite this slot; its fresh-flag poke makes the editor
    // re-ask for THIS content, which re-parses (~1ms) and republishes — converges.
    syn := parse_syntax(source, abs_path, async_alloc())
    if len(syn) > 0 {
        sync.lock(&state.mutex)
        free_diags(&state.result_diags)
        state.result_diags = syn
        state.result_hash = h
        state.result_valid = false
        state.have_result = true
        state.fresh = false // handed to THIS caller right now — no poke needed
        out := clone_diags(state.result_diags[:], allocator)
        sync.unlock(&state.mutex)
        return out, false
    }
    delete(syn)

    sync.lock(&state.mutex)
    defer sync.unlock(&state.mutex)

    // 3. TIER 2 — schedule the real `odin check` for this content (without blocking).
    if state.worker_running {
        if state.worker_hash != h {
            // Coalesce: keep only the LATEST pending request.
            if !(state.pending && state.pending_job.hash == h) {
                if state.pending {
                    free_job(state.pending_job)
                }
                state.pending_job = make_job(state, h, source, abs_path, root, odin_bin)
                state.pending = true
            }
        }
    } else {
        state.worker_running = true
        state.worker_hash = h
        spawn_worker(make_job(state, h, source, abs_path, root, odin_bin))
    }

    // 4. Return last-known result immediately (empty + valid if nothing computed yet).
    if state.have_result {
        return clone_diags(state.result_diags[:], allocator), state.result_valid
    }
    return nil, true
}

// take_fresh reads-and-clears the "a result landed that nothing has consumed" flag.
// Called once per editor frame by the main-thread pump; true means "poke the script
// editor to re-validate now" (see Async_State.fresh).
take_fresh :: proc(state: ^Async_State) -> bool {
    sync.lock(&state.mutex)
    defer sync.unlock(&state.mutex)
    f := state.fresh
    state.fresh = false
    return f
}
