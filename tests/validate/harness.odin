package main

// ----------------------------------------------------------------------------
// Headless proof of OdinLanguage._validate's engine — now including the NON-BLOCKING
// background-worker coordinator that keeps the editor responsive.
//
// `_validate` is dispatched by the editor through the GDExtension virtual table and is NOT
// callable from GDScript, so the END-TO-END validate logic is proven here by calling the SAME
// shared procedures the core dll uses:
//   * `diag.run_check_overlay` — the LIVE-buffer overlay -> real `odin check` -> diagnostic
//     parsing (the slow, load-bearing work), and
//   * `diag.validate_async`    — the main-thread entry the editor hits: it returns INSTANTLY
//     with the last-known result and schedules ONE background worker to run the slow check.
//
// Asserts:
//   1. run_check_overlay: clean baseline -> 0 diagnostics; broken buffer -> the exact
//      line/column/message (proves the underlying check is correct), and TIMES the check so we
//      have a "check duration" baseline.
//   2. NON-BLOCKING: the FIRST validate_async call (cold, slow check still running in the
//      background) RETURNS in « the check duration — it does NOT block on `odin check`.
//   3. EVENTUAL CORRECTNESS: after the background worker completes, validate_async for the
//      broken buffer surfaces the error at line 4 / column 11; a clean buffer -> no errors.
//   4. COALESCING: rapid successive calls with CHANGING content keep at most ONE worker
//      in-flight plus ONE coalesced pending job — no unbounded thread pile-up.
// Prints VALIDATE_HARNESS_OK on success.
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:time"
import diag "godot:core/diag" // the godot collection == repo root, so this is core/diag

fail :: proc(msg: string) {
    fmt.eprintln("VALIDATE_HARNESS_FAIL:", msg)
    os.exit(1)
}

BROKEN :: "package validate_fixture\n\nbad :: proc() {\n\ty: int = \"oops\"\n}\n"
// Half-typed expression — the everyday while-typing state the syntax tier exists for.
SYNTAX_BROKEN :: "package validate_fixture\n\nbad :: proc() {\n\tx := (1 +\n}\n"

free_diags :: proc(ds: []diag.Diagnostic) {
    for x in ds {delete(x.message)}
    delete(ds)
}

// Locked snapshot of the coordinator's shared flags — reads under the mutex so we observe the
// worker's writes with correct acquire/release ordering (matters on arm64).
Snap :: struct {
    worker_running: bool,
    pending:        bool,
    have_result:    bool,
    result_valid:   bool,
}
snapshot :: proc(s: ^diag.Async_State) -> Snap {
    sync.lock(&s.mutex)
    defer sync.unlock(&s.mutex)
    return Snap{s.worker_running, s.pending, s.have_result, s.result_valid}
}

main :: proc() {
    root := os.get_env("ODIN_GODOT_ROOT", context.allocator)
    if root == "" {
        if len(os.args) > 1 {
            root = os.args[1]
        } else {
            fail("set ODIN_GODOT_ROOT or pass the repo root as arg 1")
        }
    }

    fixture := strings.concatenate({root, "/tests/showcase/validate_fixture/sample.odin"})
    odin_bin := "odin" // resolved from PATH inside the nix dev shell

    // ------------------------------------------------------------------
    // 1. Underlying check is correct + measure the check duration.
    // ------------------------------------------------------------------
    clean, rerr := os.read_entire_file(fixture, context.allocator)
    if rerr != nil {
        fail(fmt.tprintf("could not read fixture %s", fixture))
    }
    good := diag.run_check_overlay(string(clean), fixture, root)
    fmt.printf("clean -> %d diagnostic(s)\n", len(good))
    if len(good) != 0 {
        fail(fmt.tprintf("clean baseline reported %d errors: %v", len(good), good[:]))
    }

    t_check := time.now()
    bad := diag.run_check_overlay(BROKEN, fixture, root)
    check_dur := time.since(t_check)
    fmt.printf("broken -> %d diagnostic(s)  (check duration: %.1f ms)\n", len(bad), time.duration_milliseconds(check_dur))
    if len(bad) == 0 {
        fail("broken buffer reported NO errors")
    }
    d := bad[0]
    fmt.printf("first diagnostic: line=%d column=%d message=%q\n", d.line, d.column, d.message)
    if d.line != 4 {
        fail(fmt.tprintf("expected error on line 4, got line %d", d.line))
    }
    if d.column != 11 {
        fail(fmt.tprintf("expected error on column 11, got column %d", d.column))
    }
    if strings.index(d.message, "Cannot convert") == -1 {
        fail(fmt.tprintf("unexpected message: %q", d.message))
    }

    // ------------------------------------------------------------------
    // 1.5 TIER 1 — the resident parser: SYNTAX errors are caught in-process, without the
    //     checker. A type-only error (BROKEN) and the clean fixture must parse silently;
    //     a syntactically broken buffer must report, and orders of magnitude faster than
    //     the check.
    // ------------------------------------------------------------------
    t_parse := time.now()
    syn := diag.parse_syntax(SYNTAX_BROKEN, fixture)
    parse_dur := time.since(t_parse)
    fmt.printf(
        "syntax-broken -> %d syntax diagnostic(s)  (parse duration: %.3f ms)\n",
        len(syn),
        time.duration_milliseconds(parse_dur),
    )
    if len(syn) == 0 {
        fail("syntax-broken buffer reported NO syntax errors")
    }
    fmt.printf("first syntax diagnostic: line=%d column=%d message=%q\n", syn[0].line, syn[0].column, syn[0].message)
    if syn[0].line < 4 || syn[0].line > 5 {
        fail(fmt.tprintf("expected the syntax error near line 4-5, got line %d", syn[0].line))
    }
    if parse_dur >= check_dur / 10 {
        fail(fmt.tprintf("parse tier (%.3f ms) is not clearly faster than the check (%.1f ms)", time.duration_milliseconds(parse_dur), time.duration_milliseconds(check_dur)))
    }
    for x in syn {delete(x.message)}
    delete(syn)
    syn_type := diag.parse_syntax(BROKEN, fixture) // a TYPE error parses clean
    if len(syn_type) != 0 {
        fail(fmt.tprintf("type-only BROKEN buffer reported %d syntax errors: %v", len(syn_type), syn_type[:]))
    }
    delete(syn_type)
    syn_clean := diag.parse_syntax(string(clean), fixture)
    if len(syn_clean) != 0 {
        fail(fmt.tprintf("clean fixture reported %d syntax errors: %v", len(syn_clean), syn_clean[:]))
    }
    delete(syn_clean)

    // ------------------------------------------------------------------
    // 1.6 validate_async on a SYNTAX-broken buffer: the diagnostic comes back on the very
    //     FIRST call (no worker, no wait), the slow check is never scheduled, and the fresh
    //     flag stays consumed (the result reached a real caller — no poke owed).
    // ------------------------------------------------------------------
    sstate: diag.Async_State
    t_syn := time.now()
    sdiags, svalid := diag.validate_async(&sstate, SYNTAX_BROKEN, fixture, root, odin_bin)
    syn_lat := time.since(t_syn)
    fmt.printf(
        "async syntax-broken first call: %.3f ms -> valid=%v diags=%d\n",
        time.duration_milliseconds(syn_lat),
        svalid,
        len(sdiags),
    )
    if svalid || len(sdiags) == 0 {
        fail("syntax-broken buffer must be invalid with >=1 diagnostic on the FIRST async call")
    }
    free_diags(sdiags)
    if syn_lat > 200 * time.Millisecond {
        fail(fmt.tprintf("syntax tier took %.1f ms — it must not run the check", time.duration_milliseconds(syn_lat)))
    }
    ss := snapshot(&sstate)
    if ss.worker_running || ss.pending {
        fail("syntax-broken buffer must NOT schedule the slow check (worker/pending set)")
    }
    if diag.take_fresh(&sstate) {
        fail("syntax tier result was returned directly — the fresh poke must not be armed")
    }
    // Cache hit on the same broken content: same answer, still no worker.
    sdiags2, svalid2 := diag.validate_async(&sstate, SYNTAX_BROKEN, fixture, root, odin_bin)
    if svalid2 || len(sdiags2) == 0 {
        fail("cached syntax result lost on the second call")
    }
    free_diags(sdiags2)
    fmt.println("syntax tier: instant diagnostic, no worker scheduled, cache serves repeats")

    // ------------------------------------------------------------------
    // 2. NON-BLOCKING: the first async call returns immediately even though the cold check is
    //    slow. We assert first-call latency « the measured check duration (and < 200 ms).
    // ------------------------------------------------------------------
    state: diag.Async_State

    t0 := time.now()
    diags0, valid0 := diag.validate_async(&state, BROKEN, fixture, root, odin_bin)
    lat := time.since(t0)
    fmt.printf(
        "async first-call latency: %.3f ms  (vs check %.1f ms) -> valid=%v diags=%d\n",
        time.duration_milliseconds(lat),
        time.duration_milliseconds(check_dur),
        valid0,
        len(diags0),
    )
    // Cold: no cached result yet, so it returns empty/valid INSTANTLY while a worker spins up.
    if len(diags0) != 0 {
        fail("first async call should return empty (no cached result yet)")
    }
    free_diags(diags0)
    if lat > 200 * time.Millisecond {
        fail(fmt.tprintf("first async call BLOCKED for %.1f ms (expected « check duration)", time.duration_milliseconds(lat)))
    }
    // And it must be dramatically faster than actually running the check.
    if lat >= check_dur {
        fail(fmt.tprintf("first async call (%.1f ms) was not faster than the check (%.1f ms) — it blocked", time.duration_milliseconds(lat), time.duration_milliseconds(check_dur)))
    }

    // ------------------------------------------------------------------
    // 3a. EVENTUAL CORRECTNESS (broken): after the worker completes, the broken buffer's error
    //     surfaces via the async path at the exact line/column.
    // ------------------------------------------------------------------
    broken_ready := false
    {
        start := time.now()
        for time.since(start) < 30 * time.Second {
            ds, _ := diag.validate_async(&state, BROKEN, fixture, root, odin_bin)
            n := len(ds)
            free_diags(ds)
            if n > 0 {
                broken_ready = true
                break
            }
            time.sleep(25 * time.Millisecond)
        }
    }
    if !broken_ready {
        fail("background worker did not surface the broken diagnostic within 30s")
    }
    adiags, avalid := diag.validate_async(&state, BROKEN, fixture, root, odin_bin)
    fmt.printf("async broken -> valid=%v diags=%d\n", avalid, len(adiags))
    if avalid || len(adiags) == 0 {
        fail("async broken buffer should be invalid with >=1 diagnostic")
    }
    ad := adiags[0]
    fmt.printf("async first diagnostic: line=%d column=%d message=%q\n", ad.line, ad.column, ad.message)
    if ad.line != 4 || ad.column != 11 || strings.index(ad.message, "Cannot convert") == -1 {
        fail(fmt.tprintf("async diagnostic mismatch: line=%d col=%d msg=%q", ad.line, ad.column, ad.message))
    }
    free_diags(adiags)

    // ------------------------------------------------------------------
    // 3b. EVENTUAL CORRECTNESS (clean): the clean buffer eventually reports valid / no errors.
    // ------------------------------------------------------------------
    // Kick the clean content; it becomes the next (coalesced) job whose worker overwrites the
    // cache. Wait until the coordinator is idle and holding a valid (clean) result.
    cdiags0, _ := diag.validate_async(&state, string(clean), fixture, root, odin_bin)
    free_diags(cdiags0)
    clean_done := false
    {
        start := time.now()
        for time.since(start) < 30 * time.Second {
            s := snapshot(&state)
            if !s.worker_running && !s.pending && s.have_result && s.result_valid {
                clean_done = true
                break
            }
            // keep nudging the same content so a fresh worker is (re)scheduled if needed
            ds, _ := diag.validate_async(&state, string(clean), fixture, root, odin_bin)
            free_diags(ds)
            time.sleep(25 * time.Millisecond)
        }
    }
    if !clean_done {
        fail("clean buffer did not settle to valid within 30s")
    }
    cdiags, cvalid := diag.validate_async(&state, string(clean), fixture, root, odin_bin)
    fmt.printf("async clean -> valid=%v diags=%d\n", cvalid, len(cdiags))
    if !cvalid || len(cdiags) != 0 {
        fail(fmt.tprintf("async clean buffer should be valid with 0 diagnostics, got valid=%v n=%d", cvalid, len(cdiags)))
    }
    free_diags(cdiags)

    // ------------------------------------------------------------------
    // 4. COALESCING: fire several DISTINCT, never-seen contents in a tight loop. Because each
    //    check is slow, only the FIRST spawns a worker; the rest coalesce into a SINGLE pending
    //    job. Assert: exactly one in-flight worker + at most one pending (never N workers).
    // ------------------------------------------------------------------
    cstate: diag.Async_State
    contents := [5]string {
        "package validate_fixture\n\na :: proc() { x := 1; _ = x }\n",
        "package validate_fixture\n\nb :: proc() { x := 2; _ = x }\n",
        "package validate_fixture\n\nc :: proc() { x := 3; _ = x }\n",
        "package validate_fixture\n\ndd :: proc() { x := 4; _ = x }\n",
        "package validate_fixture\n\nee :: proc() { x := 5; _ = x }\n",
    }
    for src in contents {
        ds, _ := diag.validate_async(&cstate, src, fixture, root, odin_bin)
        free_diags(ds)
    }
    // Immediately after the burst (the slow check is still running): one worker, one pending.
    cs := snapshot(&cstate)
    fmt.printf("coalescing: worker_running=%v pending=%v\n", cs.worker_running, cs.pending)
    if !cs.worker_running {
        fail("coalescing: expected exactly one in-flight worker after the burst")
    }
    if !cs.pending {
        fail("coalescing: expected the later contents to coalesce into one pending job")
    }
    // The single `pending` field structurally guarantees at most ONE coalesced job — N rapid
    // edits can never spawn N workers. Let the in-flight + pending workers drain before exit.
    drained := false
    {
        start := time.now()
        for time.since(start) < 30 * time.Second {
            s := snapshot(&cstate)
            if !s.worker_running && !s.pending {
                drained = true
                break
            }
            time.sleep(25 * time.Millisecond)
        }
    }
    if !drained {
        fail("coalescing: workers did not drain within 30s")
    }

    // ------------------------------------------------------------------
    // 5. FRESH-RESULT FLAG (drives the editor re-validate poke): a completed worker sets it;
    //    take_fresh consumes it exactly once; a cache-hit validate_async (the editor picked
    //    the result up naturally) suppresses a pending poke.
    // ------------------------------------------------------------------
    // The drained coordinator above just published its last result -> flag must be set.
    if !diag.take_fresh(&cstate) {
        fail("fresh flag: expected true after a worker published a result")
    }
    if diag.take_fresh(&cstate) {
        fail("fresh flag: take_fresh must consume the flag (second read true)")
    }
    // Natural pickup: recompute for known content -> the publish sets the flag; a cache-HIT
    // call for that same content clears it (no redundant poke).
    {
        // last published content was contents[4] (the final coalesced job) — cache-hit it.
        ds, _ := diag.validate_async(&cstate, contents[4], fixture, root, odin_bin)
        free_diags(ds)
        // wait: is contents[4] actually the cached one? the coalesced pending kept only the
        // LATEST, so yes — but guard against surprises by asserting via the snapshot instead.
        s := snapshot(&cstate)
        if !s.have_result {
            fail("fresh flag: expected a cached result to still be present")
        }
    }
    // A worker publish followed by a cache-hit _validate must leave the flag CLEARED: force
    // one more full cycle on never-seen content, wait for publish, cache-hit, then check.
    fresh_src := "package validate_fixture\n\nzz :: proc() { x := 9; _ = x }\n"
    {
        ds0, _ := diag.validate_async(&cstate, fresh_src, fixture, root, odin_bin)
        free_diags(ds0)
        start := time.now()
        published := false
        for time.since(start) < 30 * time.Second {
            s := snapshot(&cstate)
            if !s.worker_running && !s.pending && s.have_result {
                published = true
                break
            }
            time.sleep(25 * time.Millisecond)
        }
        if !published {
            fail("fresh flag: publish cycle did not complete within 30s")
        }
        // Cache-hit pickup (what the editor's own debounce would do)...
        ds1, _ := diag.validate_async(&cstate, fresh_src, fixture, root, odin_bin)
        free_diags(ds1)
        // ...must have consumed the flag: the pump should NOT poke afterwards.
        if diag.take_fresh(&cstate) {
            fail("fresh flag: a cache-hit validate_async must clear the pending poke")
        }
    }
    fmt.println("fresh-flag semantics: set on publish, consumed once, cleared by cache-hit pickup")

    fmt.println("VALIDATE_HARNESS_OK")
}
