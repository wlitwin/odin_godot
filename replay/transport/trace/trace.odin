package replay_transport_trace

import "core:mem"
import "core:bytes"
import tr "godot:replay/transport"

Operation :: enum u8 {
    Send,
    Receive,
    Poll,
    Status,
    Connected,
    Generation,
    Close,
    Mark,
}

Error :: enum u8 {
    None,
    Invalid,
    Capacity,
    Allocation,
    Exhausted,
    Operation,
    Arguments,
}

Capabilities :: bit_set[Operation;u8]

Limits :: struct {
    events: int,
    bytes:  int,
}

DEFAULT_LIMITS :: Limits{1_000_000, 64 * 1024 * 1024}

Entry :: struct {
    operation:  Operation,
    peer:       u64,
    channel:    tr.Channel,
    count:      i64,
    capacity:   u64,
    generation: u64,
    returned:   u8,
    offset:     u64,
    size:       u32,
}

Log :: struct {
    capabilities: Capabilities,
    entries:      [dynamic]Entry,
    data:         [dynamic]u8,
    allocator:    mem.Allocator,
    limits:       Limits,
    error:        Error,
    ready:        bool,
}

Capture :: struct {
    base:   tr.Transport,
    log:    ^Log,
    closed: bool,
}

Replay :: struct {
    log:    ^Log,
    index:  int,
    error:  Error,
    closed: bool,
}

init :: proc(log: ^Log, limits := DEFAULT_LIMITS, allocator := context.allocator) -> bool {
    if log.ready ||
       limits.events < 1 ||
       limits.events > DEFAULT_LIMITS.events ||
       limits.bytes < 1 ||
       limits.bytes > DEFAULT_LIMITS.bytes {
        return false
    }

    log.allocator, log.limits, log.ready = allocator, limits, true
    log.entries = make([dynamic]Entry, 0, 0, allocator)
    log.data = make([dynamic]u8, 0, 0, allocator)

    if reserve(&log.entries, min(limits.events, 1024)) != nil || reserve(&log.data, min(limits.bytes, 65536)) != nil {
        destroy(log)
        return false
    }

    return true
}

destroy :: proc(log: ^Log) {
    delete(log.entries)
    delete(log.data)
    log^ = {}
}

@(private)
add :: proc(log: ^Log, entry: Entry, payload: []u8 = nil) {
    if log == nil || !log.ready || log.error != .None {
        return
    }

    if len(log.entries) >= log.limits.events || len(payload) > log.limits.bytes - len(log.data) {
        log.error = .Capacity
        return
    }

    item := entry
    item.offset, item.size = u64(len(log.data)), u32(len(payload))

    if len(log.data) + len(payload) > cap(log.data) {
        if reserve(&log.data, min(log.limits.bytes, max(len(log.data) + len(payload), cap(log.data) * 2))) != nil {
            log.error = .Allocation
            return
        }
    }

    if len(log.entries) == cap(log.entries) {
        if reserve(&log.entries, min(log.limits.events, max(1, cap(log.entries) * 2))) != nil {
            log.error = .Allocation
            return
        }
    }

    append(&log.data, ..payload)
    append(&log.entries, item)
}

// Caller-owned marks can identify pump boundaries, clocks and configuration.
mark :: proc(log: ^Log, label, value: u64, payload: []u8 = nil) {
    add(log, {operation = .Mark, peer = label, generation = value}, payload)
}

payload :: proc(log: ^Log, entry: Entry) -> []u8 {
    if entry.offset > u64(len(log.data)) || u64(entry.size) > u64(len(log.data)) - entry.offset {
        return nil
    }

    return log.data[int(entry.offset):int(entry.offset) + int(entry.size)]
}

// Borrowed wrapper. Recording exhaustion never changes underlying operations.
// Destroying the log does not close the wrapped endpoint.
capture :: proc(c: ^Capture, log: ^Log, base: tr.Transport) -> tr.Transport {
    if log == nil || !log.ready || len(log.entries) != 0 || len(log.data) != 0 || log.error != .None {
        return {}
    }

    c^ = {
        base = base,
        log  = log,
    }
    log.capabilities = {}
    wire := tr.Transport {
        user = c,
    }

    if base.send != nil {
        wire.send = record_send
        log.capabilities += {.Send}
    }

    if base.receive != nil {
        wire.receive = record_receive
        log.capabilities += {.Receive}
    }

    if base.poll != nil {
        wire.poll = record_poll
        log.capabilities += {.Poll}
    }

    if base.status != nil {
        wire.status = record_status
        log.capabilities += {.Status}
    }

    if base.connected != nil {
        wire.connected = record_connected
        log.capabilities += {.Connected}
    }

    if base.generation != nil {
        wire.generation = record_generation
        log.capabilities += {.Generation}
    }

    if base.close != nil {
        wire.close = record_close
        log.capabilities += {.Close}
    }

    return wire
}

@(private)
record_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, data: []u8) -> tr.Send_Result {
    c := cast(^Capture)user
    result := c.base.send(c.base.user, to, channel, data)
    add(c.log, {operation = .Send, peer = u64(to), channel = channel, returned = u8(result)}, data)
    return result
}

@(private)
record_receive :: proc(user: rawptr, dst: []u8) -> tr.Received {
    c := cast(^Capture)user
    result := c.base.receive(c.base.user, dst)
    data: []u8

    if result.state == .Received {
        if result.count < 0 || result.count > len(dst) {
            c.log.error = .Invalid
        } else {
            data = dst[:result.count]
        }
    }

    add(
        c.log,
        {
            operation = .Receive,
            peer = u64(result.from),
            channel = result.channel,
            count = i64(result.count),
            capacity = u64(len(dst)),
            generation = result.generation,
            returned = u8(result.state),
        },
        data,
    )
    return result
}

@(private)
record_poll :: proc(user: rawptr) {
    c := cast(^Capture)user
    c.base.poll(c.base.user)
    add(c.log, {operation = .Poll})
}

@(private)
record_status :: proc(user: rawptr) -> tr.Status {
    c := cast(^Capture)user
    value := c.base.status(c.base.user)
    add(c.log, {operation = .Status, returned = u8(value)})
    return value
}

@(private)
record_connected :: proc(user: rawptr, peer: tr.Peer_Id) -> bool {
    c := cast(^Capture)user
    value := c.base.connected(c.base.user, peer)
    add(c.log, {operation = .Connected, peer = u64(peer), returned = u8(value)})
    return value
}

@(private)
record_generation :: proc(user: rawptr, peer: tr.Peer_Id) -> u64 {
    c := cast(^Capture)user
    value := c.base.generation(c.base.user, peer)
    add(c.log, {operation = .Generation, peer = u64(peer), generation = value})
    return value
}

@(private)
record_close :: proc(user: rawptr) {
    c := cast(^Capture)user
    c.base.close(c.base.user)
    c.closed = true
    add(c.log, {operation = .Close})
}

// Strict replay checks calls and outbound bytes; it never opens a real endpoint.
// Nil callbacks remain nil so Transport's fallback/generation semantics survive.
replay :: proc(p: ^Replay, log: ^Log) -> tr.Transport {
    if !valid(log) {
        p.error = .Invalid
        return {}
    }

    p^ = {
        log = log,
    }
    wire := tr.Transport {
        user = p,
    }

    if .Send in log.capabilities {
        wire.send = play_send
    }

    if .Receive in log.capabilities {
        wire.receive = play_receive
    }

    if .Poll in log.capabilities {
        wire.poll = play_poll
    }

    if .Status in log.capabilities {
        wire.status = play_status
    }

    if .Connected in log.capabilities {
        wire.connected = play_connected
    }

    if .Generation in log.capabilities {
        wire.generation = play_generation
    }

    if .Close in log.capabilities {
        wire.close = play_close
    }

    return wire
}

finished :: proc(p: ^Replay) -> bool {
    return p.log != nil && p.error == .None && p.index == len(p.log.entries)
}

@(private)
take :: proc(p: ^Replay, op: Operation) -> (Entry, bool) {
    if p.error != .None || p.log == nil {
        return {}, false
    }

    if p.index >= len(p.log.entries) {
        p.error = .Exhausted
        return {}, false
    }

    e := p.log.entries[p.index]

    if e.operation != op {
        p.error = .Operation
        return {}, false
    }

    p.index += 1
    return e, true
}

next_mark :: proc(p: ^Replay, label: u64) -> (Entry, bool) {
    if p.error != .None || p.log == nil {
        return {}, false
    }

    for e in p.log.entries[p.index:] {
        if e.operation == .Mark {
            return e, e.peer == label
        }
    }

    return {}, false
}

read_mark :: proc(p: ^Replay, label: u64) -> (Entry, bool) {
    e, ok := take(p, .Mark)

    if !ok {
        return {}, false
    }

    if e.peer != label {
        p.error = .Arguments
        return {}, false
    }

    return e, true
}

@(private)
play_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, data: []u8) -> tr.Send_Result {
    p := cast(^Replay)user
    e, ok := take(p, .Send)

    if !ok {
        return .Disconnected
    }

    if e.peer != u64(to) || e.channel != channel || !bytes.equal(data, payload(p.log, e)) {
        p.error = .Arguments
        return .Invalid
    }

    return tr.Send_Result(e.returned)
}

@(private)
play_receive :: proc(user: rawptr, dst: []u8) -> tr.Received {
    p := cast(^Replay)user
    e, ok := take(p, .Receive)

    if !ok {
        return {state = .Disconnected}
    }

    if e.capacity != u64(len(dst)) {
        p.error = .Arguments
        return {state = .Disconnected}
    }

    data := payload(p.log, e)

    if len(data) > len(dst) {
        p.error = .Invalid
        return {state = .Disconnected}
    }

    copy(dst, data)
    return {
        state = tr.Receive_State(e.returned),
        from = tr.Peer_Id(e.peer),
        channel = e.channel,
        count = int(e.count),
        generation = e.generation,
    }
}

@(private)
play_poll :: proc(user: rawptr) {
    take(cast(^Replay)user, .Poll)
}

@(private)
play_status :: proc(user: rawptr) -> tr.Status {
    p := cast(^Replay)user
    e, ok := take(p, .Status)
    return ok ? tr.Status(e.returned) : .Disconnected
}

@(private)
play_connected :: proc(user: rawptr, peer: tr.Peer_Id) -> bool {
    p := cast(^Replay)user
    e, ok := take(p, .Connected)

    if !ok {
        return false
    }

    if e.peer != u64(peer) {
        p.error = .Arguments
        return false
    }

    return e.returned != 0
}

@(private)
play_generation :: proc(user: rawptr, peer: tr.Peer_Id) -> u64 {
    p := cast(^Replay)user
    e, ok := take(p, .Generation)

    if !ok {
        return 0
    }

    if e.peer != u64(peer) {
        p.error = .Arguments
        return 0
    }

    return e.generation
}

@(private)
play_close :: proc(user: rawptr) {
    p := cast(^Replay)user

    if _, ok := take(p, .Close); ok {
        p.closed = true
    }
}
