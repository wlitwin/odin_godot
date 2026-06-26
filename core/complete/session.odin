#+build darwin, linux, windows
package complete

// ----------------------------------------------------------------------------
// PERSISTENT ols session — the fast path for editor autocomplete.
//
// The fresh-spawn `run_completion` (complete.odin) starts a brand-new `ols`, has it index the
// whole `godot` collection (~1059 files), answers ONE completion, and exits — ~0.5-1.25s PER
// keystroke-completion. That index cost is paid every time.
//
// This module keeps ONE long-lived `ols` subprocess alive for the editor session over real
// bidirectional stdio pipes (core:os process + pipe API). It does the `initialize` handshake +
// `ols.json` write ONCE; the godot-collection index then stays warm in ols's memory, so each
// subsequent completion is `didChange` + `textDocument/completion` against the resident index —
// measured WARM at ~30-70 ms vs the ~0.5-1.25s fresh spawn (see tests/lsp).
//
// Design / threading:
//   * One process, lazily started on the first completion (the cold index cost is paid once,
//     on that first request — exactly as the old fresh-spawn paid it every time).
//   * A dedicated READER THREAD owns ols's stdout: it parses every Content-Length frame and,
//     when a frame is the response to the id we're awaiting, hands the body to the requester
//     via a cond var. Server notifications (logMessage, publishDiagnostics) are ignored — this
//     module is completion-only (diagnostics stay on the async `odin check` path; ols computes
//     diagnostics by shelling the SAME `odin check`, so routing them through ols buys no speed).
//   * `req_mutex` serializes the one outstanding response-bearing request; `write_mutex` guards
//     stdin writes; `state_mutex` + `cond` guard the awaited-reply slot, the doc/pkg maps and
//     the liveness flags. `start_mutex` serializes start/teardown.
//   * ROBUST: if ols can't start / dies / times out, the session is marked dead and the call
//     returns ok=false so the caller transparently FALLS BACK to fresh-spawn `run_completion`.
//     A short retry backoff prevents spawn-storms on every keystroke; the session restarts on
//     the next use after a death.
//   * NEVER calls Godot/gdext. Headlessly testable (tests/lsp). Desktop-only (web has no ols).
//
// `session_complete` blocks the calling thread only for the request round-trip (warm: tens of
// ms) — completion is a discrete user action, and this is far less than the fresh spawn it
// replaces. Validation (every keystroke) is untouched and remains fully non-blocking.
// ----------------------------------------------------------------------------

import "base:runtime"
import "core:c/libc"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"

// LSP request ids start high so they never collide with server->client request ids (which ols
// numbers from small values for things like registerCapability).
@(private = "file")
ID_BASE :: 1000
@(private = "file")
INIT_ID :: 1

// How long a completion round-trip may take before we give up and fall back.
@(private = "file")
REQUEST_TIMEOUT :: 3 * time.Second
// How long to wait for ols to answer `initialize` (cold: process start + godot-collection index).
@(private = "file")
INIT_TIMEOUT :: 30 * time.Second
// After a failed start, don't retry for this long (avoid spawn-storms on every keystroke).
@(private = "file")
RETRY_BACKOFF :: 2 * time.Second

Session :: struct {
    start_mutex:   sync.Mutex, // serializes start / teardown
    write_mutex:   sync.Mutex, // serializes stdin writes (framed messages)
    req_mutex:     sync.Mutex, // serializes the single outstanding response-bearing request
    state_mutex:   sync.Mutex, // guards everything below + the awaited-reply slot
    cond:          sync.Cond,  // signalled by the reader on an awaited reply or on death

    started:       bool,
    dead:          bool,
    next_retry_ns: i64, // monotonic ns before which a failed start won't be retried

    proc_:         os.Process,
    stdin:         ^os.File,
    stdout_r:      ^os.File,
    reader:        ^thread.Thread,

    // config captured on the first successful start (heap-owned)
    configured:    bool,
    ols_bin:       string,
    root:          string,
    share:         string,
    workspace:     string, // temp workspace dir holding ols.json + per-package overlays

    next_id:       int,
    pkg_counter:   int,

    // real package dir -> overlay subdir under `workspace` (copied once)
    pkgs:          map[string]string,
    // overlay-file uri -> last sent version (>0 means didOpen already sent)
    docs:          map[string]int,

    // single awaited response slot (correlated by id; only one in flight via req_mutex)
    awaiting_id:   int,
    awaited_ready: bool,
    awaited_body:  []u8, // heap-owned clone of the reply frame body
}

// The editor-wide session used by core/complete.odin. Tests use their own local Session.
g_session: Session

@(private = "file")
sess_alloc :: proc() -> runtime.Allocator {
    return runtime.heap_allocator()
}

// ---- framing over the live pipes -------------------------------------------

@(private = "file")
Frame_Reader :: struct {
    f:   ^os.File,
    buf: [dynamic]u8,
    pos: int,
}

@(private = "file")
fr_fill :: proc(fr: ^Frame_Reader) -> bool {
    tmp: [8192]u8
    n, err := os.read(fr.f, tmp[:])
    if n <= 0 || err != nil {return false}
    append(&fr.buf, ..tmp[:n])
    return true
}

// Read one LSP frame body (allocates a heap copy the caller owns). Returns ok=false on EOF/err.
@(private = "file")
fr_read :: proc(fr: ^Frame_Reader) -> (body: []u8, ok: bool) {
    for {
        rel := strings.index(string(fr.buf[fr.pos:]), "\r\n\r\n")
        if rel >= 0 {
            header := string(fr.buf[fr.pos:fr.pos + rel])
            clen := 0
            if ci := strings.index(header, "Content-Length:"); ci >= 0 {
                rest := strings.trim_space(header[ci + len("Content-Length:"):])
                for ch in rest {
                    if ch < '0' || ch > '9' {break}
                    clen = clen * 10 + int(ch - '0')
                }
            }
            body_start := fr.pos + rel + 4
            for len(fr.buf) - body_start < clen {
                if !fr_fill(fr) {return nil, false}
            }
            out := make([]u8, clen, sess_alloc())
            copy(out, fr.buf[body_start:body_start + clen])
            fr.pos = body_start + clen
            if fr.pos == len(fr.buf) {
                clear(&fr.buf)
                fr.pos = 0
            }
            return out, true
        }
        if !fr_fill(fr) {return nil, false}
    }
}

// Write a single framed message to ols stdin under the write mutex.
@(private = "file")
send_frame :: proc(s: ^Session, payload: string) {
    sync.lock(&s.write_mutex)
    defer sync.unlock(&s.write_mutex)
    hdr := fmt.tprintf("Content-Length: %d\r\n\r\n", len(payload))
    if s.stdin != nil {
        os.write(s.stdin, transmute([]u8)hdr)
        os.write(s.stdin, transmute([]u8)payload)
    }
}

// ---- the reader thread ------------------------------------------------------

@(private = "file")
reader_entry :: proc(data: rawptr) {
    s := (^Session)(data)

    // Private, race-free context (heap allocator + private temp arena) — never the Godot
    // context, never the shared global temp allocator.
    context = runtime.default_context()
    context.allocator = sess_alloc()
    temp: runtime.Default_Temp_Allocator
    runtime.default_temp_allocator_init(&temp, runtime.DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE, sess_alloc())
    context.temp_allocator = runtime.Allocator {
        procedure = runtime.default_temp_allocator_proc,
        data      = &temp,
    }
    defer runtime.default_temp_allocator_destroy(&temp)

    fr := Frame_Reader{f = s.stdout_r}
    defer delete(fr.buf)

    for {
        body, ok := fr_read(&fr)
        if !ok {
            // ols closed stdout / died.
            sync.lock(&s.state_mutex)
            s.dead = true
            sync.cond_broadcast(&s.cond)
            sync.unlock(&s.state_mutex)
            return
        }

        // Only responses carry our awaited id. Parse just enough to read "id".
        id, is_resp := frame_response_id(body)
        if is_resp {
            sync.lock(&s.state_mutex)
            if id == s.awaiting_id && !s.awaited_ready {
                s.awaited_body = body // transfer ownership
                s.awaited_ready = true
                body = nil
                sync.cond_broadcast(&s.cond)
            }
            sync.unlock(&s.state_mutex)
        }
        if body != nil {delete(body, sess_alloc())}
    }
}

// Pull the integer "id" out of a frame body IF it is a response (has "result" or "error").
// Notifications (no id) and server->client requests (id + "method") return is_resp=false.
@(private = "file")
frame_response_id :: proc(body: []u8) -> (id: int, is_resp: bool) {
    v, perr := json.parse(body, .JSON, true, context.temp_allocator)
    if perr != nil {return 0, false}
    obj, ok := v.(json.Object)
    if !ok {return 0, false}
    if _, has_method := obj["method"]; has_method {return 0, false} // request/notification
    _, has_res := obj["result"]
    _, has_err := obj["error"]
    if !has_res && !has_err {return 0, false}
    idv, has_id := obj["id"]
    if !has_id {return 0, false}
    iv, iok := as_int(idv)
    if !iok {return 0, false}
    return iv, true
}

// ---- request / response round-trip ------------------------------------------

// Send `payload` (a request with `id`), then block until the reader hands back its reply, the
// session dies, or `timeout` elapses. Returns the heap-owned body (caller frees) or ok=false.
@(private = "file")
do_request :: proc(s: ^Session, id: int, payload: string, timeout: time.Duration) -> (body: []u8, ok: bool) {
    sync.lock(&s.state_mutex)
    if s.dead {
        sync.unlock(&s.state_mutex)
        return nil, false
    }
    s.awaiting_id = id
    s.awaited_ready = false
    if s.awaited_body != nil {
        delete(s.awaited_body, sess_alloc())
        s.awaited_body = nil
    }
    sync.unlock(&s.state_mutex)

    send_frame(s, payload)

    deadline := time.tick_now()
    sync.lock(&s.state_mutex)
    for !s.awaited_ready && !s.dead {
        remaining := timeout - time.tick_since(deadline)
        if remaining <= 0 {break}
        sync.cond_wait_with_timeout(&s.cond, &s.state_mutex, remaining)
    }
    got := s.awaited_ready
    body = s.awaited_body
    s.awaited_body = nil
    s.awaited_ready = false
    s.awaiting_id = -1
    dead := s.dead
    sync.unlock(&s.state_mutex)

    if !got || dead {
        if body != nil {delete(body, sess_alloc())}
        return nil, false
    }
    return body, true
}

// Fire-and-forget notification (no reply expected).
@(private = "file")
notify :: proc(s: ^Session, payload: string) {
    send_frame(s, payload)
}

// ---- ols.json + workspace setup --------------------------------------------

@(private = "file")
session_write_ols_json :: proc(s: ^Session) -> bool {
    path := fmt.tprintf("%s/ols.json", s.workspace)
    return write_ols_json(path, s.root, s.share)
}

// ---- lifecycle --------------------------------------------------------------

// Ensure a live, initialized session. Lazily starts (and re-starts after a death) ols, paying
// the cold index cost on the calling thread. Returns false (and the caller falls back) when ols
// can't be reached; a short backoff prevents retry-storms. Holds start_mutex.
@(private = "file")
ensure_started :: proc(s: ^Session, ols_bin, root, share: string) -> bool {
    sync.lock(&s.start_mutex)
    defer sync.unlock(&s.start_mutex)

    if s.started && !s.dead {return true}

    if s.dead {teardown_locked(s)} // reclaim a crashed session before restarting

    now := time.tick_now()._nsec
    if s.next_retry_ns != 0 && now < s.next_retry_ns {return false}

    if !s.configured {
        a := sess_alloc()
        s.ols_bin = strings.clone(ols_bin, a)
        s.root = strings.clone(root, a)
        s.share = strings.clone(share, a)
        // temp workspace dir
        tmpdir := os.get_env("TMPDIR", a)
        if tmpdir == "" {tmpdir = strings.clone("/tmp", a)}
        tmpdir = strings.trim_suffix(tmpdir, "/")
        s.workspace = fmt.aprintf("%s/odin_ols_session_%d", tmpdir, os.get_pid())
        s.pkgs = make(map[string]string, a)
        s.docs = make(map[string]int, a)
        s.next_id = ID_BASE
        s.configured = true
    }

    // (re)create workspace + ols.json
    libc.system(fmt.ctprintf("rm -rf '%s' && mkdir -p '%s'", s.workspace, s.workspace))
    clear(&s.pkgs)
    clear(&s.docs)
    if !session_write_ols_json(s) {
        s.next_retry_ns = now + i64(RETRY_BACKOFF)
        return false
    }

    if !spawn_locked(s) {
        teardown_locked(s)
        s.next_retry_ns = now + i64(RETRY_BACKOFF)
        return false
    }

    if !handshake(s) {
        teardown_locked(s)
        s.next_retry_ns = now + i64(RETRY_BACKOFF)
        return false
    }

    s.started = true
    s.dead = false
    s.next_retry_ns = 0
    return true
}

@(private = "file")
spawn_locked :: proc(s: ^Session) -> bool {
    cin_r, cin_w, e1 := os.pipe()
    if e1 != nil {return false}
    cout_r, cout_w, e2 := os.pipe()
    if e2 != nil {
        os.close(cin_r); os.close(cin_w)
        return false
    }

    p, perr := os.process_start({
        command     = {s.ols_bin},
        working_dir = s.workspace,
        stdin       = cin_r,
        stdout      = cout_w,
        stderr      = nil, // ols logs to LSP window/logMessage; drop OS stderr
    })
    // Parent never uses the child's ends.
    os.close(cin_r)
    os.close(cout_w)
    if perr != nil {
        os.close(cin_w); os.close(cout_r)
        return false
    }

    s.proc_ = p
    s.stdin = cin_w
    s.stdout_r = cout_r
    s.awaiting_id = -1
    s.awaited_ready = false

    // Reader must be running before we send `initialize` so we can catch its reply.
    ctx := runtime.default_context()
    ctx.allocator = sess_alloc()
    s.reader = thread.create_and_start_with_data(rawptr(s), reader_entry, init_context = ctx)
    return s.reader != nil
}

@(private = "file")
handshake :: proc(s: ^Session) -> bool {
    root_uri := fmt.tprintf("file://%s", s.workspace)
    init := fmt.tprintf(
        `{{"jsonrpc":"2.0","id":%d,"method":"initialize","params":{{"processId":%d,"rootUri":"%s","capabilities":{{}}}}}}`,
        INIT_ID,
        os.get_pid(),
        root_uri,
    )
    body, ok := do_request(s, INIT_ID, init, INIT_TIMEOUT)
    if !ok {return false}
    delete(body, sess_alloc())
    notify(s, `{"jsonrpc":"2.0","method":"initialized","params":{}}`)
    return true
}

// Kill the process, join the reader, close handles, drop overlay state. Caller holds start_mutex.
@(private = "file")
teardown_locked :: proc(s: ^Session) {
    if s.started || s.stdin != nil {
        _ = os.process_kill(s.proc_) // EOFs the reader so it exits
    }
    if s.reader != nil {
        thread.join(s.reader)
        thread.destroy(s.reader)
        s.reader = nil
    }
    if s.started || s.stdin != nil {
        _, _ = os.process_wait(s.proc_)
    }
    if s.stdin != nil {os.close(s.stdin); s.stdin = nil}
    if s.stdout_r != nil {os.close(s.stdout_r); s.stdout_r = nil}

    sync.lock(&s.state_mutex)
    if s.awaited_body != nil {
        delete(s.awaited_body, sess_alloc())
        s.awaited_body = nil
    }
    s.awaited_ready = false
    s.awaiting_id = -1
    s.started = false
    s.dead = false
    sync.unlock(&s.state_mutex)

    // Drop opened-doc / package-overlay bookkeeping (the dir itself is recreated on restart).
    a := sess_alloc()
    for _, ov in s.pkgs {delete(ov, a)}
    clear(&s.pkgs)
    for uri in s.docs {delete(uri, a)}
    clear(&s.docs)
}

// Clean shutdown for editor `_finish` / module deinit. Idempotent.
session_shutdown :: proc(s: ^Session) {
    sync.lock(&s.start_mutex)
    defer sync.unlock(&s.start_mutex)
    if !s.configured && !s.started {return}
    if s.started && !s.dead {
        // best-effort graceful shutdown before the kill in teardown
        notify(s, fmt.tprintf(`{{"jsonrpc":"2.0","id":%d,"method":"shutdown"}}`, ID_BASE - 1))
        notify(s, `{"jsonrpc":"2.0","method":"exit","params":{}}`)
    }
    if s.workspace != "" {
        libc.system(fmt.ctprintf("rm -rf '%s'", s.workspace))
    }
    teardown_locked(s)
}

// ---- per-package overlay ----------------------------------------------------

// Ensure `abs_path`'s package is copied into the workspace once; return the overlay file path
// for `abs_path` (where the live buffer is opened/changed). ok=false on a malformed path/copy.
@(private = "file")
ensure_overlay :: proc(s: ^Session, abs_path: string) -> (overlay: string, ok: bool) {
    slash := strings.last_index_byte(abs_path, '/')
    if slash <= 0 {return "", false}
    pkgdir := abs_path[:slash]
    basename := abs_path[slash + 1:]

    sync.lock(&s.state_mutex)
    ov_dir, seen := s.pkgs[pkgdir]
    sync.unlock(&s.state_mutex)

    a := sess_alloc()
    if !seen {
        sync.lock(&s.start_mutex) // serialize counter + copy with start/teardown
        s.pkg_counter += 1
        ov_dir = fmt.aprintf("%s/pkg%d", s.workspace, s.pkg_counter, allocator = a)
        sync.unlock(&s.start_mutex)
        cp := fmt.ctprintf("mkdir -p '%s' && cp '%s'/*.odin '%s'/ 2>/dev/null", ov_dir, pkgdir, ov_dir)
        if libc.system(cp) != 0 {
            delete(ov_dir, a)
            return "", false
        }
        sync.lock(&s.state_mutex)
        s.pkgs[strings.clone(pkgdir, a)] = ov_dir
        sync.unlock(&s.state_mutex)
    }
    overlay = fmt.aprintf("%s/%s", ov_dir, basename)
    return overlay, true
}

// ---- the public completion entry --------------------------------------------

// Persistent-session completion. Returns the options at the caret (owned by `allocator`) and
// ok=true when ols answered; ok=false means "session unavailable — caller should fall back".
// Mirrors run_completion's contract so core can swap transparently.
session_complete :: proc(
    s: ^Session,
    code: string,
    abs_path: string,
    root: string,
    share: string,
    ols_bin := "ols",
    allocator := context.allocator,
) -> (opts: [dynamic]Completion, ok: bool) {
    opts = make([dynamic]Completion, allocator)

    if !ensure_started(s, ols_bin, root, share) {return opts, false}

    overlay, ook := ensure_overlay(s, abs_path)
    if !ook {return opts, false}
    defer delete(overlay, sess_alloc())

    clean, line, char := caret_from_code(code, context.temp_allocator)
    uri := fmt.tprintf("file://%s", overlay)

    text_json, mErr := json.marshal(clean, {}, context.temp_allocator)
    if mErr != nil {return opts, false}

    // didOpen the first time we see this uri, didChange afterwards (live buffer either way).
    sync.lock(&s.state_mutex)
    ver, opened := s.docs[uri]
    ver += 1
    s.docs[strings.clone(uri, sess_alloc()) if !opened else uri] = ver
    sync.unlock(&s.state_mutex)

    sync.lock(&s.req_mutex)
    defer sync.unlock(&s.req_mutex)

    if !opened {
        notify(s, fmt.tprintf(
            `{{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{{"textDocument":{{"uri":"%s","languageId":"odin","version":%d,"text":%s}}}}}}`,
            uri, ver, string(text_json),
        ))
    } else {
        notify(s, fmt.tprintf(
            `{{"jsonrpc":"2.0","method":"textDocument/didChange","params":{{"textDocument":{{"uri":"%s","version":%d}},"contentChanges":[{{"text":%s}}]}}}}`,
            uri, ver, string(text_json),
        ))
    }

    s.next_id += 1
    id := s.next_id
    req := fmt.tprintf(
        `{{"jsonrpc":"2.0","id":%d,"method":"textDocument/completion","params":{{"textDocument":{{"uri":"%s"}},"position":{{"line":%d,"character":%d}}}}}}`,
        id, uri, line, char,
    )
    body, rok := do_request(s, id, req, REQUEST_TIMEOUT)
    if !rok {return opts, false} // timeout / death -> fall back (session marked dead by reader)
    defer delete(body, sess_alloc())

    delete(opts)
    return parse_completion_reply(body, allocator), true
}

// session_definition — like session_complete but asks ols for `textDocument/definition` and
// returns the resolved target, with the overlay path remapped back to the real package file.
// ok=false means the session was unavailable (caller -> FAILED); ok=true with def.ok=false means
// ols answered but found no definition.
session_definition :: proc(
    s: ^Session,
    code: string,
    abs_path: string,
    root: string,
    share: string,
    ols_bin := "ols",
    allocator := context.allocator,
) -> (def: Definition, ok: bool) {
    if !ensure_started(s, ols_bin, root, share) {return Definition{}, false}

    overlay, ook := ensure_overlay(s, abs_path)
    if !ook {return Definition{}, false}
    defer delete(overlay, sess_alloc())

    clean, line, char := caret_from_code(code, context.temp_allocator)
    uri := fmt.tprintf("file://%s", overlay)

    text_json, mErr := json.marshal(clean, {}, context.temp_allocator)
    if mErr != nil {return Definition{}, false}

    sync.lock(&s.state_mutex)
    ver, opened := s.docs[uri]
    ver += 1
    s.docs[strings.clone(uri, sess_alloc()) if !opened else uri] = ver
    sync.unlock(&s.state_mutex)

    sync.lock(&s.req_mutex)
    defer sync.unlock(&s.req_mutex)

    if !opened {
        notify(s, fmt.tprintf(
            `{{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{{"textDocument":{{"uri":"%s","languageId":"odin","version":%d,"text":%s}}}}}}`,
            uri, ver, string(text_json),
        ))
    } else {
        notify(s, fmt.tprintf(
            `{{"jsonrpc":"2.0","method":"textDocument/didChange","params":{{"textDocument":{{"uri":"%s","version":%d}},"contentChanges":[{{"text":%s}}]}}}}`,
            uri, ver, string(text_json),
        ))
    }

    s.next_id += 1
    id := s.next_id
    req := fmt.tprintf(
        `{{"jsonrpc":"2.0","id":%d,"method":"textDocument/definition","params":{{"textDocument":{{"uri":"%s"}},"position":{{"line":%d,"character":%d}}}}}}`,
        id, uri, line, char,
    )
    body, rok := do_request(s, id, req, REQUEST_TIMEOUT)
    if !rok {return Definition{}, false}
    defer delete(body, sess_alloc())

    def = parse_definition_reply(body, allocator)
    if def.ok {
        def.path = remap_overlay_path(s, def.path, allocator)
    }
    return def, true
}

// Map an overlay path (`<workspace>/pkgN/foo.odin`) back to the real package file. Same-package
// definitions resolve to the overlay copy; symbols in other packages already come back as real
// paths and pass through unchanged.
@(private = "file")
remap_overlay_path :: proc(s: ^Session, path: string, allocator: runtime.Allocator) -> string {
    sync.lock(&s.state_mutex)
    defer sync.unlock(&s.state_mutex)
    for real, ov in s.pkgs {
        if strings.has_prefix(path, ov) && len(path) > len(ov) && path[len(ov)] == '/' {
            remapped := strings.concatenate({real, path[len(ov):]}, allocator)
            delete(path, allocator)
            return remapped
        }
    }
    return path
}
