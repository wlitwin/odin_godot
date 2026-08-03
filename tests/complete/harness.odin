package main

// ----------------------------------------------------------------------------
// Headless proof of OdinLanguage._complete_code's engine.
//
// `_complete_code` is dispatched by the editor through the GDExtension virtual table and is
// NOT callable from GDScript, so the END-TO-END completion logic (LIVE-buffer overlay -> real
// `ols` LSP handshake -> CompletionItem parsing) is proven here by calling the SAME shared
// procedure the core dll uses: `complete.run_completion`. Core's `lv_complete_code` is a thin
// wrapper adding path-globalizing, ols/collection resolution, and Dictionary building.
//
// Asserts (against the REAL ols server + the REAL generated `godot` package):
//   * typing `gd.node2d_set_p` inside the showcase player package yields options that
//     CONTAIN `node2d_set_position` (a real proc in godot/node2d.gen.odin) — proves ols
//     actually produced accurate, scope-aware completions, not a faked list.
//   * the U+FFFF caret-marker form (what Godot passes) resolves to the same caret.
//   * empty / garbage input does NOT crash and returns a well-formed (possibly empty) list.
// Prints COMPLETE_HARNESS_OK on success.
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:os"
import "core:strings"
import complete "godot:core/complete" // godot collection == repo root, so this is core/complete

fail :: proc(msg: string) {
    fmt.eprintln("COMPLETE_HARNESS_FAIL:", msg)
    os.exit(1)
}

slice_has :: proc(s: []string, v: string) -> bool {
    for x in s {
        if x == v {return true}
    }
    return false
}

has_label :: proc(cs: [dynamic]complete.Completion, label: string) -> bool {
    for c in cs {
        if c.label == label {return true}
    }
    return false
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

    // Inject a partial member-completion line `gd.node2d_set_p` right after the
    // `singleton_input()` line inside player_process (a stable first-statement anchor),
    // with the U+FFFF caret marker at its end — exactly the shape Godot's
    // get_text_for_code_completion() produces.
    marker := "￿" // U+FFFF, the caret sentinel Godot inserts
    inject := strings.concatenate({"\tgd.node2d_set_p", marker})

    lines := strings.split_lines(string(base))
    b := strings.builder_make()
    for ln in lines {
        strings.write_string(&b, ln)
        strings.write_byte(&b, '\n')
        if strings.contains(ln, "gd.singleton_input()") {
            strings.write_string(&b, inject)
            strings.write_byte(&b, '\n')
        }
    }
    code := strings.to_string(b)

    // 1. REAL ols completion for the `gd.node2d_set_p` prefix.
    cs, hint0 := complete.run_completion(code, fixture, root, share, ols_bin)
    if hint0 != "" {
        fail(fmt.tprintf("call_hint should be empty outside a call, got %q", hint0))
    }
    fmt.printf("prefix 'gd.node2d_set_p' -> %d option(s)\n", len(cs))
    if len(cs) == 0 {
        fail("ols returned NO completions for a known prefix (is `ols` on PATH / OLS set?)")
    }
    // Show a few for the record.
    for c, idx in cs {
        if idx >= 8 {break}
        fmt.printf("  option: kind=%d label=%q insert=%q\n", c.kind, c.label, c.insert_text)
    }
    if !has_label(cs, "node2d_set_position") {
        fail("expected option `node2d_set_position` not present — completion is not returning REAL godot procs")
    }
    // Every returned option must be a well-formed record.
    for c in cs {
        if c.label == "" || c.insert_text == "" {
            fail("a completion option had an empty label/insert_text")
        }
    }
    fmt.println("found node2d_set_position among real ols completions")

    // 2. Garbage / empty input must not crash and must return a well-formed (empty ok) list.
    junk, junk_hint := complete.run_completion("", fixture, root, share, ols_bin)
    fmt.printf("empty input -> %d option(s), hint=%q (no crash)\n", len(junk), junk_hint)
    garbage, garbage_hint := complete.run_completion("@@@ not odin %%%", fixture, root, share, ols_bin)
    fmt.printf("garbage input -> %d option(s), hint=%q (no crash)\n", len(garbage), garbage_hint)

    // 3. Completion-option Dictionary SHAPE — the font_color log-spam fix.
    //
    // The editor calls OdinLanguage._complete_code and reads back an option Dictionary per
    // completion; core/complete.odin builds each by iterating complete.Completion_Option_Field
    // (the SINGLE source of truth), emitting one key per field. Godot's complete_code
    // (script_language_extension.h ~L407-420) does ERR_CONTINUE(!op.has("<key>")) on each of
    // kind/display/insert_text/font_color/icon/default_value/location BEFORE reading it, so a
    // missing key both drops the option AND spams the log (the user's original `font_color`
    // error). The real Godot Dictionary can't be built/inspected headless (the _complete_code
    // virtual isn't callable from GDScript — has_method is false — and the headless editor
    // crashes opening a script editor), so we assert the canonical field set that core EMITS
    // FROM: it must be exactly the keys Godot requires, none missing, none stray.
    expected := []string {
        "kind",
        "display",
        "insert_text",
        "font_color",
        "icon",
        "default_value",
        "location",
    }
    // Collect the keys core emits (one per canonical field) and cross-check against `expected`.
    seen: [dynamic]string
    defer delete(seen)
    for f in complete.Completion_Option_Field {
        k := string(complete.completion_option_field_key(f))
        if k == "" {fail(fmt.tprintf("option field %v has an empty key", f))}
        for prev in seen {
            if prev == k {fail(fmt.tprintf("duplicate completion-option key %q", k))}
        }
        if !slice_has(expected, k) {
            fail(fmt.tprintf("unexpected completion-option key %q (not a Godot-required key)", k))
        }
        append(&seen, k)
    }
    for want in expected {
        if !slice_has(seen[:], want) {
            fail(fmt.tprintf("completion option MISSING required key %q — Godot complete_code ERR_CONTINUEs on it", want))
        }
    }
    fmt.printf("completion-option shape OK: all %d required keys present: %v\n", len(seen), seen[:])

    // 4. Filter/cap helpers — the `gd.` autocomplete-stutter fix. These thin a huge
    // member list down to what's typed and cap it, so the editor doesn't stall
    // building/rendering ~24k Dictionaries. Pure functions, asserted headless.
    cm :: "￿" // U+FFFF caret marker
    if p := complete.prefix_at_caret(strings.concatenate({"\tgd.node2d_set_p", cm})); p != "node2d_set_p" {
        fail(fmt.tprintf("prefix_at_caret member = %q, want \"node2d_set_p\"", p))
    }
    if p := complete.prefix_at_caret(strings.concatenate({"\tgd.", cm})); p != "" {
        fail(fmt.tprintf("prefix_at_caret bare-dot = %q, want \"\"", p))
    }
    if p := complete.prefix_at_caret("gd.Vector2"); p != "Vector2" { // no marker -> end of buffer
        fail(fmt.tprintf("prefix_at_caret no-marker = %q, want \"Vector2\"", p))
    }
    if !complete.matches_prefix("node2d_set_position", "node2d_set_p") {fail("matches_prefix: prefix should match")}
    if !complete.matches_prefix("node2d_set_position", "set_position") {fail("matches_prefix: substring should match")}
    if !complete.matches_prefix("Vector2", "vector") {fail("matches_prefix: should be case-insensitive")}
    if !complete.matches_prefix("anything", "") {fail("matches_prefix: empty prefix should match all")}
    if complete.matches_prefix("foo", "xyz") {fail("matches_prefix: non-match should be false")}
    if complete.matches_prefix("ab", "abc") {fail("matches_prefix: prefix longer than label should be false")}
    if complete.MAX_OPTIONS <= 0 {fail("MAX_OPTIONS must be positive")}
    fmt.printf("filter/cap helpers OK (MAX_OPTIONS=%d)\n", complete.MAX_OPTIONS)

    // 5. textDocument/definition reply parsing — the local goto-definition fix. ols may answer
    // with a single Location, an array of Location, or an array of LocationLink; line is 0-based.
    d1 := complete.parse_definition_reply(
        transmute([]u8)string(
            `{"jsonrpc":"2.0","id":5,"result":{"uri":"file:///proj/foo.odin","range":{"start":{"line":41,"character":2},"end":{"line":41,"character":10}}}}`,
        ),
    )
    if !d1.ok || d1.path != "/proj/foo.odin" || d1.line != 41 {
        fail(fmt.tprintf("parse_definition Location: ok=%v path=%q line=%d", d1.ok, d1.path, d1.line))
    }
    d2 := complete.parse_definition_reply(
        transmute([]u8)string(`{"result":[{"uri":"file:///a/bar.odin","range":{"start":{"line":7,"character":0}}}]}`),
    )
    if !d2.ok || d2.path != "/a/bar.odin" || d2.line != 7 {
        fail(fmt.tprintf("parse_definition Location[]: ok=%v path=%q line=%d", d2.ok, d2.path, d2.line))
    }
    d3 := complete.parse_definition_reply(
        transmute([]u8)string(
            `{"result":[{"targetUri":"file:///a/baz.odin","targetSelectionRange":{"start":{"line":3,"character":5}}}]}`,
        ),
    )
    if !d3.ok || d3.path != "/a/baz.odin" || d3.line != 3 {
        fail(fmt.tprintf("parse_definition LocationLink[]: ok=%v path=%q line=%d", d3.ok, d3.path, d3.line))
    }
    if complete.parse_definition_reply(transmute([]u8)string(`{"result":null}`)).ok {
        fail("parse_definition null -> ok must be false")
    }
    if complete.parse_definition_reply(transmute([]u8)string(`{"result":[]}`)).ok {
        fail("parse_definition [] -> ok must be false")
    }
    fmt.println("definition-reply parsing OK")

    // 6. SIGNATURE HELP (the `call_hint` parameter tooltip) — end-to-end through the SAME
    // one-shot batch that serves completion. Caret INSIDE `gd.node2d_set_position(` must
    // yield the REAL Odin signature (explicit `self` first arg — the thing Godot's class
    // docs hide) in Godot's CodeEdit format: active parameter wrapped in U+FFFF markers.
    sig_inject := strings.concatenate({"\tgd.node2d_set_position(", cm})
    sb := strings.builder_make()
    for ln in lines {
        strings.write_string(&sb, ln)
        strings.write_byte(&sb, '\n')
        if strings.contains(ln, "gd.singleton_input()") {
            strings.write_string(&sb, sig_inject)
            strings.write_byte(&sb, '\n')
        }
    }
    sig_code := strings.to_string(sb)
    sig_cs, sig_hint := complete.run_completion(sig_code, fixture, root, share, ols_bin)
    _ = sig_cs
    fmt.printf("caret in `gd.node2d_set_position(` -> call_hint=%q\n", sig_hint)
    if !strings.contains(sig_hint, "node2d_set_position") {
        fail("call_hint does not contain the proc name — signatureHelp not answered")
    }
    if !strings.contains(sig_hint, "position_: Vector2") {
        fail("call_hint is missing the parameter list (`position_: Vector2`)")
    }
    // Active parameter 0 (`self: ...`) must be wrapped in the U+FFFF pair CodeEdit
    // underlines (scene/gui/code_edit.cpp finds the first/last 0xFFFF per line).
    if !strings.contains(sig_hint, strings.concatenate({cm, "self:"})) {
        fail("call_hint does not mark the active `self` parameter with U+FFFF")
    }
    if strings.count(sig_hint, cm) != 2 {
        fail(fmt.tprintf("call_hint must carry exactly 2 U+FFFF markers, got %d", strings.count(sig_hint, cm)))
    }
    fmt.println("end-to-end signatureHelp call_hint OK")

    // 7. call-hint FORMATTER unit tests (fabricated LSP replies — pin the exact
    // Godot-facing format independently of what ols emits today).
    // 7a. string param labels + activeParameter=1 -> second param wrapped.
    h1 := complete.parse_signature_help_reply(
        transmute([]u8)string(
            `{"jsonrpc":"2.0","id":6,"result":{"signatures":[{"label":"f :: proc(a: int, b: f32)","parameters":[{"label":"a: int"},{"label":"b: f32"}]}],"activeSignature":0,"activeParameter":1}}`,
        ),
    )
    if h1 != strings.concatenate({"f :: proc(a: int, ", cm, "b: f32", cm, ")"}) {
        fail(fmt.tprintf("formatter string-labels: got %q", h1))
    }
    // 7b. [start,end] offset param labels.
    h2 := complete.parse_signature_help_reply(
        transmute([]u8)string(
            `{"result":{"signatures":[{"label":"g(x, y)","parameters":[{"label":[2,3]},{"label":[5,6]}]}],"activeParameter":0}}`,
        ),
    )
    if h2 != strings.concatenate({"g(", cm, "x", cm, ", y)"}) {
        fail(fmt.tprintf("formatter offset-labels: got %q", h2))
    }
    // 7c. duplicate param text resolves to the RIGHT occurrence (left-to-right walk).
    h3 := complete.parse_signature_help_reply(
        transmute([]u8)string(
            `{"result":{"signatures":[{"label":"h(a: int, a: int)","parameters":[{"label":"a: int"},{"label":"a: int"}],"activeParameter":1}]}}`,
        ),
    )
    if h3 != strings.concatenate({"h(a: int, ", cm, "a: int", cm, ")"}) {
        fail(fmt.tprintf("formatter duplicate-params (per-signature activeParameter): got %q", h3))
    }
    // 7d. multiple signatures -> '\n'-joined lines; only the ACTIVE one gets markers.
    h4 := complete.parse_signature_help_reply(
        transmute([]u8)string(
            `{"result":{"signatures":[{"label":"o(a: int)","parameters":[{"label":"a: int"}]},{"label":"o(a: int, b: int)","parameters":[{"label":"a: int"},{"label":"b: int"}]}],"activeSignature":1,"activeParameter":1}}`,
        ),
    )
    if h4 != strings.concatenate({"o(a: int)\no(a: int, ", cm, "b: int", cm, ")"}) {
        fail(fmt.tprintf("formatter multi-signature: got %q", h4))
    }
    // 7e. null result (caret not in a call) and malformed replies -> "" — never break.
    if h := complete.parse_signature_help_reply(transmute([]u8)string(`{"result":null}`)); h != "" {
        fail(fmt.tprintf("formatter null result: got %q, want \"\"", h))
    }
    if h := complete.parse_signature_help_reply(transmute([]u8)string(`not json at all`)); h != "" {
        fail(fmt.tprintf("formatter garbage body: got %q, want \"\"", h))
    }
    // 7f. activeParameter out of range -> plain signature, no markers.
    h5 := complete.parse_signature_help_reply(
        transmute([]u8)string(
            `{"result":{"signatures":[{"label":"p()","parameters":[]}],"activeParameter":3}}`,
        ),
    )
    if h5 != "p()" {
        fail(fmt.tprintf("formatter out-of-range activeParameter: got %q, want \"p()\"", h5))
    }
    fmt.println("call-hint formatter OK")

    // 8. in_call_context — the cheap gate that decides whether to spend the extra
    // signatureHelp round-trip at all.
    if !complete.in_call_context(strings.concatenate({"foo(", cm})) {fail("in_call_context: `foo(` should be in-call")}
    if !complete.in_call_context(strings.concatenate({"foo(bar, ", cm})) {fail("in_call_context: `foo(bar, ` should be in-call")}
    if !complete.in_call_context(strings.concatenate({"foo(bar(x), ", cm})) {fail("in_call_context: nested closed call should be in-call")}
    if !complete.in_call_context(strings.concatenate({"foo(a,\n\tb, ", cm})) {fail("in_call_context: calls span newlines")}
    if complete.in_call_context(strings.concatenate({"foo(bar)", cm})) {fail("in_call_context: closed call should NOT be in-call")}
    if complete.in_call_context(strings.concatenate({"foo", cm})) {fail("in_call_context: bare ident should NOT be in-call")}
    if complete.in_call_context(strings.concatenate({"f(x) {\n\ty ", cm})) {fail("in_call_context: `{` at depth 0 is a statement boundary")}
    fmt.println("in_call_context OK")

    fmt.println("COMPLETE_HARNESS_OK")
}
