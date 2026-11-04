package replay_p2p

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
Archive_Part :: enum {
    Header,
    Settings,
    Peers,
    Frame,
    Held,
    Event,
    Tick,
    Input,
    Hash,
}

@(private)
Archive_Codecs :: struct {
    parts:       [Archive_Part]sc.Schema,
    fingerprint: u64,
}

@(private)
archive_codecs_init :: proc(c: ^Archive_Codecs, $S, $I, $E: typeid, $N: int, allocator: mem.Allocator) -> bool {
    if sc.init(&c.parts[.Header], Archive_Header, allocator = allocator).error != .None ||
       sc.init(&c.parts[.Settings], Archive_Settings, allocator = allocator).error != .None ||
       sc.init(&c.parts[.Peers], Archive_Peers(N), allocator = allocator).error != .None ||
       sc.init(&c.parts[.Frame], r.Frame(S), allocator = allocator).error != .None ||
       sc.init(&c.parts[.Held], [N]I, allocator = allocator).error != .None ||
       sc.init(&c.parts[.Event], r.Occurrence(E), allocator = allocator).error != .None ||
       sc.init(&c.parts[.Tick], Archive_Tick(I, N), allocator = allocator).error != .None ||
       sc.init(&c.parts[.Input], Archive_Input(I), allocator = allocator).error != .None ||
       sc.init(&c.parts[.Hash], Archive_Hash, allocator = allocator).error != .None {
        return false
    }

    c.fingerprint = u64(ARCHIVE_VERSION)

    for codec in c.parts {
        c.fingerprint = mix(c.fingerprint, codec.fingerprint)
    }

    return true
}

@(private)
archive_codecs_destroy :: proc(c: ^Archive_Codecs) {
    for &codec in c.parts {
        sc.destroy(&codec)
    }
}

@(private)
archive_body_size :: proc(
    c: ^Archive_Codecs,
    h: Archive_Header,
    settings: Archive_Settings,
    seats: int,
) -> (
    int,
    bool,
) {
    if settings.history < 32 ||
       settings.history > 1024 ||
       settings.events_per_tick > 256 ||
       h.base_events > settings.events_per_tick ||
       h.ticks >= settings.history ||
       h.inputs > u32(seats) * settings.history ||
       h.hashes > settings.history {
        return 0, false
    }

    size := u64(
        c.parts[.Header].wire_size +
        c.parts[.Settings].wire_size +
        c.parts[.Peers].wire_size +
        c.parts[.Frame].wire_size +
        c.parts[.Held].wire_size,
    )
    size +=
        u64(h.base_events) * u64(c.parts[.Event].wire_size) +
        u64(h.ticks) * u64(c.parts[.Tick].wire_size) +
        u64(h.inputs) * u64(c.parts[.Input].wire_size) +
        u64(h.hashes) * u64(c.parts[.Hash].wire_size)

    if size + sc.HEADER_BYTES > MAX_ARCHIVE_BYTES {
        return 0, false
    }

    return int(size), true
}

archive_encode :: proc(
    a: ^Archive($S, $I, $E, $N),
    model: Model(S, I, E, N),
    allocator := context.allocator,
) -> (
    []u8,
    Error,
) {
    if !archive_valid(a, model) {
        return nil, .Invalid_Archive
    }

    c: Archive_Codecs
    defer archive_codecs_destroy(&c)

    if !archive_codecs_init(&c, S, I, E, N, allocator) {
        return nil, .Schema
    }

    size, ok := archive_body_size(&c, a.header, a.settings, N)

    if !ok {
        return nil, .Capacity
    }

    bytes := make([]u8, size + sc.HEADER_BYTES, allocator)
    committed := false

    defer if !committed {
        delete(bytes, allocator)
    }

    w := Archive_Cursor {
        bytes = bytes[sc.HEADER_BYTES:],
    }
    archive_put(&w, &c.parts[.Header], a.header)
    archive_put(&w, &c.parts[.Settings], a.settings)
    archive_put(&w, &c.parts[.Peers], a.peers)
    archive_put(&w, &c.parts[.Frame], a.base)
    archive_put(&w, &c.parts[.Held], a.base_held)

    for event in a.base_events {
        archive_put(&w, &c.parts[.Event], event)
    }

    for tick in a.ticks {
        archive_put(&w, &c.parts[.Tick], tick)
    }

    for input in a.inputs {
        archive_put(&w, &c.parts[.Input], input)
    }

    for hash in a.hashes {
        archive_put(&w, &c.parts[.Hash], hash)
    }

    if w.failed || w.at != size {
        return nil, .Invalid_Archive
    }

    if sc.pack_bytes(c.fingerprint, {kind = ARCHIVE_KIND, epoch = a.settings.epoch, content = a.settings.content, tick = a.header.head}, bytes[sc.HEADER_BYTES:], bytes).error !=
       .None {
        return nil, .Invalid_Archive
    }

    committed = true
    return bytes, .None
}

archive_decode :: proc(
    a: ^Archive($S, $I, $E, $N),
    bytes: []u8,
    model: Model(S, I, E, N),
    content: u64,
    allocator := context.allocator,
) -> Error {
    if !archive_empty(a) {
        return .Not_Ready
    }

    if len(bytes) > MAX_ARCHIVE_BYTES {
        return .Invalid_Archive
    }

    meta, _, report := sc.inspect(bytes)

    if report.error != .None || meta.content != content || meta.kind != ARCHIVE_KIND {
        return .Invalid_Archive
    }

    c: Archive_Codecs
    defer archive_codecs_destroy(&c)

    if !archive_codecs_init(&c, S, I, E, N, allocator) {
        return .Schema
    }

    _, body, valid := sc.unpack_bytes(
        c.fingerprint,
        bytes,
        {kind = ARCHIVE_KIND, epoch = meta.epoch, content = content},
    )

    if valid.error != .None {
        return .Invalid_Archive
    }

    tmp: Archive(S, I, E, N)
    tmp.allocator = allocator
    committed := false

    defer if !committed {
        archive_destroy(&tmp)
    }

    w := Archive_Cursor {
        bytes = body,
    }
    archive_get(&w, &c.parts[.Header], &tmp.header)
    archive_get(&w, &c.parts[.Settings], &tmp.settings)
    size, bounded := archive_body_size(&c, tmp.header, tmp.settings, N)

    if w.failed ||
       !bounded ||
       size != len(body) ||
       tmp.settings.content != content ||
       tmp.settings.epoch != meta.epoch ||
       tmp.header.head != meta.tick {
        return .Invalid_Archive
    }

    archive_get(&w, &c.parts[.Peers], &tmp.peers)
    archive_get(&w, &c.parts[.Frame], &tmp.base)
    archive_get(&w, &c.parts[.Held], &tmp.base_held)

    if w.failed {
        return .Invalid_Archive
    }

    tmp.base_events = make([]r.Occurrence(E), int(tmp.header.base_events), allocator)
    tmp.ticks = make([]Archive_Tick(I, N), int(tmp.header.ticks), allocator)
    tmp.inputs = make([dynamic]Archive_Input(I), int(tmp.header.inputs), allocator)
    tmp.hashes = make([dynamic]Archive_Hash, int(tmp.header.hashes), allocator)

    for &event in tmp.base_events {
        archive_get(&w, &c.parts[.Event], &event)
    }

    for &tick in tmp.ticks {
        archive_get(&w, &c.parts[.Tick], &tick)
    }

    for &input in tmp.inputs {
        archive_get(&w, &c.parts[.Input], &input)
    }

    for &hash in tmp.hashes {
        archive_get(&w, &c.parts[.Hash], &hash)
    }

    if w.failed || w.at != size {
        return .Invalid_Archive
    }

    tmp.ready = true

    if !archive_valid(&tmp, model) {
        return .Invalid_Archive
    }

    a^ = tmp
    committed = true
    return .None
}

@(private)
Archive_Cursor :: struct {
    bytes:  []u8,
    at:     int,
    failed: bool,
}

@(private)
archive_put :: proc(w: ^Archive_Cursor, codec: ^sc.Schema, value: $T) {
    if w.failed || codec.wire_size > len(w.bytes) - w.at {
        w.failed = true
        return
    }

    w.failed = sc.encode(codec, value, w.bytes[w.at:w.at + codec.wire_size]).error != .None
    w.at += codec.wire_size
}

@(private)
archive_get :: proc(w: ^Archive_Cursor, codec: ^sc.Schema, value: ^$T) {
    if w.failed || codec.wire_size > len(w.bytes) - w.at {
        w.failed = true
        return
    }

    w.failed = sc.decode(codec, value, w.bytes[w.at:w.at + codec.wire_size]).error != .None
    w.at += codec.wire_size
}
