package replay_comms

import "core:unicode/utf8"

// Text is one bounded UTF-8 line. Never split a rune; reject controls and malformed
// input rather than allow an injected second speaker line in a plain-label view.
text_payload :: proc(text: string, system: bool = false) -> (Payload, bool) {
    p := Payload {
        kind = system ? .System : .Say,
    }
    at := 0

    for at < len(text) {
        rune, size := utf8.decode_rune_in_string(text[at:])

        if size == 0 ||
           (rune == utf8.RUNE_ERROR && size == 1) ||
           rune < 32 ||
           (rune >= 127 && rune <= 159) ||
           rune == 0x2028 ||
           rune == 0x2029 {
            return {}, false
        }

        if at + size > TEXT_BYTES {
            break
        }

        copy(p.text[at:at + size], transmute([]u8)text[at:at + size])
        at += size
    }

    p.length = u16(at)
    return p, at > 0
}

valid :: proc(p: Payload, system: bool = false) -> bool {
    if p.kind == .Say || (system && p.kind == .System) {
        if p.length < 1 || p.length > TEXT_BYTES || p.position != ([3]f32{}) || p.tag != 0 {
            return false
        }

        for b, i in p.text {
            if i >= int(p.length) && b != 0 {
                return false
            }
        }

        text := p.text
        _, ok := text_payload(string(text[:p.length]))
        return ok
    }

    if p.kind != .Marker || p.length != 0 || p.tag == 0 {
        return false
    }

    for b in p.text {
        if b != 0 {
            return false
        }
    }

    for x in p.position {
        if !(x >= -1000000 && x <= 1000000) {
            return false
        }
    }

    return true
}

say :: proc(c: ^Comms, text: string) -> Result {
    p, ok := text_payload(text)

    if !ok {
        return .Invalid
    }

    return issue(c, p)
}

mark :: proc(c: ^Comms, tag: u32, position: [3]f32) -> Result {
    return issue(c, Payload{kind = .Marker, tag = tag, position = position})
}

system :: proc(c: ^Comms, text: string) -> Result {
    if !c.authority || !c.enabled {
        return .Permission
    }

    p, ok := text_payload(text, true)

    if !ok {
        return .Invalid
    }

    return broadcast(c, p, Binding{})
}

@(private)
issue :: proc(c: ^Comms, p: Payload) -> Result {
    if !c.ready || !c.bound || !c.enabled {
        return .Not_Ready
    }

    if !valid(p) {
        return .Invalid
    }

    if c.local.spectator && p.kind == .Marker {
        return .Permission
    }

    if c.pending_count + c.receipt_count == PENDING || c.issued == max(u64) {
        return .Capacity
    }

    at := (c.pending_head + c.pending_count) % PENDING
    c.issued += 1
    c.pending[at] = p
    c.pending_names[at] = c.local.spectator && c.local.observer_name_allowed ? c.local.name : {}
    c.pending_ids[at] = c.issued
    c.pending_count += 1
    return .None
}

@(private)
newer :: proc(a, b: Id) -> bool {
    return a.epoch > b.epoch || (a.epoch == b.epoch && a.sequence > b.sequence)
}

@(private)
record :: proc(c: ^Comms, delivery: Delivery) {
    e := delivery.entry

    if !newer(e.id, c.last_id) {
        c.duplicates += 1
        return
    }

    c.last_id = e.id

    if e.value.kind == .Marker {
        if delivery.historical {
            return
        }

        if c.marker_count == len(c.markers) {
            c.marker_drops += 1
            return
        }

        c.markers[c.marker_count] = e
        c.marker_count += 1
        return
    }

    if c.line_count == HISTORY {
        copy(c.lines[:], c.lines[1:])
        c.line_count -= 1
    }

    c.lines[c.line_count] = e
    c.line_count += 1
    c.history_serial += 1
}

poll_marker :: proc(c: ^Comms) -> (Entry, bool) {
    if c.marker_count == 0 {
        return {}, false
    }

    entry := c.markers[0]
    c.marker_count -= 1
    copy(c.markers[:], c.markers[1:c.marker_count + 1])
    return entry, true
}

// Every accepted local submission reserves one result slot. Drain receipts to
// release submission capacity; unread results are never silently overwritten.
poll_result :: proc(c: ^Comms) -> (Receipt, bool) {
    if c.receipt_count == 0 {
        return {}, false
    }

    result := c.receipts[c.receipt_head]
    c.receipt_head = (c.receipt_head + 1) % PENDING
    c.receipt_count -= 1
    return result, true
}
