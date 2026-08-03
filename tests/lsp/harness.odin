package main

// ----------------------------------------------------------------------------
// Headless proof of the PERSISTENT ols session that backs OdinLanguage._complete_code.
//
// `_complete_code` is engine-dispatched (not callable from GDScript), so the load-bearing
// logic is proven here by driving the SAME `complete.session_complete` the core dll uses (core's
// `lv_complete_code` is a thin wrapper that resolves ols/collections, calls session_complete, and
// falls back to fresh-spawn `run_completion` on failure).
//
// Asserts (against the REAL ols server + the REAL generated `godot` package):
//   1. CORRECT: typing `gd.node2d_set_p` in the showcase player package yields options that
//      CONTAIN `node2d_set_position` (a real proc in godot/node2d.gen.odin) via the persistent
//      session — not a faked list.
//   2. FAST WARM: the COLD first completion pays ols startup + the godot-collection index; every
//      WARM completion afterwards (a small edit + re-query against the resident index) returns in
//      « the cold time. Prints the actual ms; asserts warm is materially faster.
//   3. ROBUST FALLBACK: a session pointed at a BOGUS ols binary returns ok=false QUICKLY (no
//      hang) so the caller falls back — proving the editor never blocks on a missing ols.
//   4. CRASH RECOVERY: killing the live ols process mid-session is detected; the next call
//      restarts the session and still returns correct completions (no crash, no hang).
//   5. CLEAN SHUTDOWN: session_shutdown kills the subprocess + reader thread without hanging.
// Prints LSP_HARNESS_OK on success.
// ----------------------------------------------------------------------------

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import complete "godot:core/complete" // godot collection == repo root, so this is core/complete

fail :: proc(msg: string) {
    fmt.eprintln("LSP_HARNESS_FAIL:", msg)
    os.exit(1)
}

has_label :: proc(cs: [dynamic]complete.Completion, label: string) -> bool {
    for c in cs {
        if c.label == label {return true}
    }
    return false
}

free_cs :: proc(cs: [dynamic]complete.Completion) {
    for c in cs {
        delete(c.label)
        delete(c.insert_text)
        delete(c.detail)
    }
    delete(cs)
}

// Build the player buffer with `<prefix>` injected (with the U+FFFF caret marker) right after
// the `singleton_input()` line (player_process's stable first statement) — the exact shape
// Godot's get_text_for_code_completion() produces.
make_code :: proc(base: string, prefix: string) -> string {
    inject := strings.concatenate({"\tgd.", prefix, "￿"}) // U+FFFF caret marker at end
    lines := strings.split_lines(base)
    b := strings.builder_make()
    for ln in lines {
        strings.write_string(&b, ln)
        strings.write_byte(&b, '\n')
        if strings.contains(ln, "gd.singleton_input()") {
            strings.write_string(&b, inject)
            strings.write_byte(&b, '\n')
        }
    }
    return strings.to_string(b)
}

main :: proc() {
    root := os.get_env("ODIN_GODOT_ROOT", context.allocator)
    if root == "" {
        if len(os.args) > 1 {root = os.args[1]} else {fail("set ODIN_GODOT_ROOT or pass repo root as arg 1")}
    }
    ols_bin := os.get_env("OLS", context.allocator)
    if ols_bin == "" {ols_bin = "ols"}
    share := os.get_env("ODIN_SHARE", context.allocator)

    fixture := strings.concatenate({root, "/tests/showcase/scripts/player.odin"})
    base, rerr := os.read_entire_file(fixture, context.allocator)
    if rerr != nil {fail(fmt.tprintf("could not read fixture %s", fixture))}

    sess: complete.Session

    // ------------------------------------------------------------------
    // 1+2. COLD vs WARM through the persistent session.
    // ------------------------------------------------------------------
    code0 := make_code(string(base), "node2d_set_p")
    t_cold := time.now()
    cs0, ok0 := complete.session_complete(&sess, code0, fixture, root, share, ols_bin)
    cold := time.since(t_cold)
    fmt.printf("COLD session_complete: %.0f ms, ok=%v options=%d\n", time.duration_milliseconds(cold), ok0, len(cs0))
    if !ok0 {
        fail("persistent session failed COLD (is `ols` on PATH / OLS set?)")
    }
    if !has_label(cs0, "node2d_set_position") {
        fail("COLD: expected `node2d_set_position` not present — session not returning REAL godot procs")
    }
    for c in cs0 {
        if c.label == "" || c.insert_text == "" {fail("a completion option had an empty label/insert_text")}
    }
    free_cs(cs0)

    // WARM: a handful of small edits, each re-queried against the resident index.
    prefixes := [4]string{"node2d_set_po", "node2d_set_pos", "node2d_set_p", "node2d_set_posi"}
    warm_total: time.Duration
    warm_max: time.Duration
    for p, i in prefixes {
        code := make_code(string(base), p)
        t := time.now()
        cs, ok := complete.session_complete(&sess, code, fixture, root, share, ols_bin)
        dt := time.since(t)
        fmt.printf("WARM[%d] prefix=%q: %.0f ms, ok=%v options=%d\n", i, p, time.duration_milliseconds(dt), ok, len(cs))
        if !ok {fail(fmt.tprintf("WARM[%d] session_complete returned ok=false", i))}
        if !has_label(cs, "node2d_set_position") {
            fail(fmt.tprintf("WARM[%d] expected node2d_set_position for prefix %q", i, p))
        }
        free_cs(cs)
        warm_total += dt
        if dt > warm_max {warm_max = dt}
    }
    warm_avg := time.Duration(i64(warm_total) / i64(len(prefixes)))
    fmt.printf("WARM avg: %.0f ms, WARM max: %.0f ms, COLD: %.0f ms\n",
        time.duration_milliseconds(warm_avg), time.duration_milliseconds(warm_max), time.duration_milliseconds(cold))

    // The whole point: warm must be MATERIALLY faster than the cold (index-once) path.
    if warm_max >= cold {
        fail(fmt.tprintf("WARM max (%.0f ms) was not faster than COLD (%.0f ms) — index is not staying warm",
            time.duration_milliseconds(warm_max), time.duration_milliseconds(cold)))
    }
    // And warm should be genuinely fast (well under the ~0.5-1.25s fresh spawn it replaces).
    if warm_avg > 300 * time.Millisecond {
        fail(fmt.tprintf("WARM avg %.0f ms is too slow to call a warm speedup", time.duration_milliseconds(warm_avg)))
    }

    // ------------------------------------------------------------------
    // 2b. SIGNATURE HELP through the WARM session — the `call_hint` parameter tooltip.
    // Caret INSIDE `gd.node2d_set_position(` must yield the REAL Odin signature (explicit
    // `self` first arg) in Godot's CodeEdit format: active param wrapped in U+FFFF markers.
    // ------------------------------------------------------------------
    marker :: "￿" // U+FFFF
    sig_code := make_code(string(base), "node2d_set_position(")
    t_sig := time.now()
    hint, hok := complete.session_signature_help(&sess, sig_code, fixture, root, share, ols_bin)
    fmt.printf("WARM session_signature_help: %.0f ms, ok=%v hint=%q\n",
        time.duration_milliseconds(time.since(t_sig)), hok, hint)
    if !hok {fail("session_signature_help returned ok=false on a warm session")}
    if !strings.contains(hint, "node2d_set_position") {
        fail("session call_hint does not contain the proc name")
    }
    if !strings.contains(hint, "position_: Vector2") {
        fail("session call_hint is missing the parameter list (`position_: Vector2`)")
    }
    if !strings.contains(hint, strings.concatenate({marker, "self:"})) {
        fail("session call_hint does not mark the active `self` parameter with U+FFFF")
    }
    delete(hint)

    // NOT in a call -> ols answers null -> empty hint, still ok=true (session healthy).
    no_call := make_code(string(base), "node2d_set_p")
    hint2, hok2 := complete.session_signature_help(&sess, no_call, fixture, root, share, ols_bin)
    if !hok2 {fail("session_signature_help (not in call) returned ok=false")}
    if hint2 != "" {fail(fmt.tprintf("expected empty hint outside a call, got %q", hint2))}
    delete(hint2)
    fmt.println("session signatureHelp OK (in-call hint + empty outside call)")

    // ------------------------------------------------------------------
    // 4. CRASH RECOVERY: kill the live ols process; the next call must restart + still work.
    // ------------------------------------------------------------------
    pid := sess.proc_.pid
    fmt.printf("killing live ols pid=%d to prove crash recovery...\n", pid)
    libc.system(fmt.ctprintf("kill -9 %d 2>/dev/null", pid))
    time.sleep(300 * time.Millisecond) // let the reader observe EOF

    code_r := make_code(string(base), "node2d_set_p")
    t_rec := time.now()
    csr, okr := complete.session_complete(&sess, code_r, fixture, root, share, ols_bin)
    rec := time.since(t_rec)
    fmt.printf("RECOVERY after kill: %.0f ms, ok=%v options=%d\n", time.duration_milliseconds(rec), okr, len(csr))
    if !okr {
        fail("session did not recover after the ols process was killed")
    }
    if !has_label(csr, "node2d_set_position") {
        fail("RECOVERY: completions wrong after restart")
    }
    free_cs(csr)

    // ------------------------------------------------------------------
    // 5. CLEAN SHUTDOWN must not hang.
    // ------------------------------------------------------------------
    complete.session_shutdown(&sess)
    fmt.println("session_shutdown returned cleanly")

    // ------------------------------------------------------------------
    // 3. ROBUST FALLBACK: a BOGUS ols binary -> ok=false QUICKLY, no hang.
    // ------------------------------------------------------------------
    bsess: complete.Session
    t_bad := time.now()
    bcs, bok := complete.session_complete(&bsess, code0, fixture, root, share, "/nonexistent/definitely/not/ols")
    bad := time.since(t_bad)
    fmt.printf("BOGUS ols: %.0f ms, ok=%v (expect ok=false, fast)\n", time.duration_milliseconds(bad), bok)
    if bok {
        fail("session_complete with a bogus ols returned ok=true — fallback signal broken")
    }
    if bad > 5 * time.Second {
        fail(fmt.tprintf("session_complete with a bogus ols took %.0f ms — it hung instead of failing fast", time.duration_milliseconds(bad)))
    }
    free_cs(bcs)
    // signatureHelp against the same bogus session must also fail fast with an EMPTY hint —
    // the ok=false + "" contract lv_complete_code relies on (empty hint, never a hang).
    bhint, bhok := complete.session_signature_help(&bsess, sig_code, fixture, root, share, "/nonexistent/definitely/not/ols")
    if bhok {fail("session_signature_help with a bogus ols returned ok=true")}
    if bhint != "" {fail(fmt.tprintf("bogus-ols hint must be empty, got %q", bhint))}
    delete(bhint)
    fmt.println("bogus-ols signatureHelp fails fast with empty hint")
    complete.session_shutdown(&bsess)

    fmt.println("LSP_HARNESS_OK")
}
