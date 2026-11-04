package replay_godot_storage

import "core:strings"
import net "godot:replay/net"

Browser_Identity_Phase :: enum {
    Closed,
    Reading,
    Creating,
    Ready,
    Failed,
}

Browser_Identity :: struct {
    phase:          Browser_Identity_Phase,
    op:             Browser_Store_Op,
    namespace, key: string,
    token:          net.Token,
    error:          Browser_Store_Error,
    revision:       u64,
}

// A missing identity is created with CAS(0). A competing creator is read back;
// existing/corrupt records are never overwritten or replaced by a volatile token.
browser_identity_open :: proc(p: ^Browser_Identity, namespace: string, key: string = "identity") -> bool {
    if p.phase != .Closed {
        return false
    }

    p.namespace, p.key = strings.clone(namespace), strings.clone(key)

    if !browser_store_read(&p.op, p.namespace, p.key, 16) {
        p.error = p.op.error
        p.phase = .Failed
        return false
    }

    p.phase = .Reading
    return true
}

browser_identity_frame :: proc(p: ^Browser_Identity) {
    if p.phase != .Reading && p.phase != .Creating {
        return
    }

    if browser_store_poll(&p.op) != .Complete {
        return
    }

    if p.phase == .Reading && p.op.error == .Missing {
        browser_store_close(&p.op)
        candidate := session_token()

        if !browser_identity_valid(candidate) {
            p.error = .Corrupt
            p.phase = .Failed
            return
        }

        p.token = candidate

        if !browser_store_write(&p.op, p.namespace, p.key, p.token[:], 0, 16) {
            p.error = p.op.error
            p.phase = .Failed
            return
        }

        p.phase = .Creating
        return
    }

    if p.phase == .Creating && p.op.error == .Conflict {
        browser_store_close(&p.op)
        p.token = {}

        if !browser_store_read(&p.op, p.namespace, p.key, 16) {
            p.error = p.op.error
            p.phase = .Failed
            return
        }

        p.phase = .Reading
        return
    }

    if p.op.error != .None {
        p.error = p.op.error
        p.phase = .Failed
        browser_store_close(&p.op)
        p.token = {}
        return
    }

    if p.phase == .Reading {
        bytes, err := browser_store_bytes(&p.op)
        defer delete(bytes)

        if err != .None || len(bytes) != 16 {
            p.error = err != .None ? err : .Corrupt
            p.phase = .Failed
            browser_store_close(&p.op)
            return
        }

        copy(p.token[:], bytes)

        if !browser_identity_valid(p.token) {
            p.error = .Corrupt
            p.phase = .Failed
            browser_store_close(&p.op)
            return
        }
    }

    p.revision = p.op.revision
    browser_store_close(&p.op)
    p.phase = .Ready
}

browser_identity_valid :: proc(token: net.Token) -> bool {
    bits := u8(0)

    for b in token {
        bits |= b
    }

    return bits != 0
}

browser_identity_token :: proc(p: ^Browser_Identity) -> (net.Token, bool) {
    if p.phase != .Ready {
        return {}, false
    }

    return p.token, true
}

browser_identity_close :: proc(p: ^Browser_Identity) {
    browser_store_close(&p.op)
    delete(p.namespace)
    delete(p.key)
    p^ = {}
}
