package replay_net

import "core:mem"
import r "godot:replay"
import sc "godot:replay/schema"
import bd "godot:box3d/diagnostics"

// Reusable immutable schema programs. Own by pointer and destroy once. It caches
// type metadata only: content, frame, policy, and protocol checks still run for
// every archive. No state or allocator from an archive is retained here.
Checkpoint_Codec :: struct {
    lifetime:             Container_Lifetime,
    ready, network_ready: bool,
    types:                [4]typeid,
    seats:                int,
    archive:              Checkpoint_Codecs,
    network:              Codecs,
}

checkpoint_codec_init :: proc(
    c: ^Checkpoint_Codec,
    $S, $C, $A, $E: typeid,
    $N: int,
    network: bool = true,
    allocator := context.allocator,
    ownership: Container_Ownership = {},
) -> Error {
    return checkpoint_codec_init_owned(c, S, C, A, E, N, network, allocator, ownership, false)
}

@(private)
checkpoint_codec_init_owned :: proc(
    c: ^Checkpoint_Codec,
    $S, $C, $A, $E: typeid,
    $N: int,
    network: bool,
    allocator: mem.Allocator,
    ownership: Container_Ownership,
    temporary: bool,
) -> Error {
    if error := container_access(&c.lifetime); error != .None {
        return error
    }

    if c.lifetime.cleanup || c.ready {
        return .Wrong_Phase
    }

    if N < 1 || N > 8 {
        return .Invalid_Config
    }

    if error := container_acquire(
        &c.lifetime,
        ownership,
        allocator,
        temporary ? nil : rawptr(c),
        #config(BOX3D_REQUIRE_DOMAIN, false),
    ); error != .None {
        checkpoint_codec_destroy(c)
        return error
    }

    if !checkpoint_codecs_init(&c.archive, S, C, A, N, allocator) {
        checkpoint_codec_destroy(c)
        return .Invalid_Schema
    }

    if network && !codecs_init(&c.network, S, C, A, E, N, allocator) {
        checkpoint_codec_destroy(c)
        return .Invalid_Schema
    }

    c.types, c.seats, c.ready, c.network_ready = {S, C, A, E}, N, true, network
    return .None
}

// Borrow the immutable Frame schema and canonical section offset. The codec
// must remain at a stable address for the borrow's lifetime.
checkpoint_frame_layout :: proc(c: ^Checkpoint_Codec) -> (schema: ^sc.Schema, offset: int, ok: bool) {
    if c == nil || container_access(&c.lifetime) != .None || !c.ready {
        return
    }

    return &c.archive.parts[.Frame],
        sc.HEADER_BYTES + c.archive.parts[.Header].wire_size + c.archive.parts[.Settings].wire_size,
        true
}

checkpoint_codec_destroy :: proc(c: ^Checkpoint_Codec) -> Error {
    if error := container_access(&c.lifetime); error != .None {
        return error
    }

    life := c.lifetime

    if !life.cleanup {
        checkpoint_codecs_destroy(&c.archive)
        codecs_destroy(&c.network)
    }

    c^ = {}

    if error := container_drop(&life); error != .None {
        life.cleanup = true
        c.lifetime = life
        return error
    }

    return .None
}

@(private)
checkpoint_codec_matches :: proc(c: ^Checkpoint_Codec, $S, $C, $A, $E: typeid, $N: int) -> bool {
    return(
        c != nil &&
        container_access(&c.lifetime) == .None &&
        c.ready &&
        c.seats == N &&
        c.types[0] == S &&
        c.types[1] == C &&
        c.types[2] == A &&
        c.types[3] == E \
    )
}

// Owned canonical archive bytes. All sections use authority projection, including
// fields deliberately omitted from ordinary client snapshots. This archive must
// only be disclosed to an authority trusted to read the entire world.
checkpoint_encode :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    model: Model(S, C, A, $E, N),
    allocator := context.allocator,
    codec: ^Checkpoint_Codec = nil,
) -> (
    bytes: []u8,
    error: Error,
) {
    if error := container_access(&cp.lifetime); error != .None {
        return nil, error
    }

    if r.owner_contexts_check(
           {
               owner = cp.lifetime.ownership.allocator.owner,
               owner_allocator_data = cp.lifetime.ownership.allocator.data,
           },
           allocator,
       ) !=
       .None {
        return nil, .Invalid_Model
    }

    if model.complete_state {
        return checkpoint_encode_physics(cp, model, allocator, codec)
    }

    if !checkpoint_valid(cp, model) {
        return nil, .Invalid_Checkpoint
    }

    temporary: Checkpoint_Codec
    defer checkpoint_codec_destroy(&temporary)
    active := codec

    if active == nil {
        if err := checkpoint_codec_init_owned(
            &temporary,
            S,
            C,
            A,
            E,
            N,
            false,
            allocator,
            {allocator = cp.lifetime.ownership.allocator},
            true,
        ); err != .None {
            return nil, err
        }

        active = &temporary
    }

    if !checkpoint_codec_matches(active, S, C, A, E, N) {
        return nil, .Invalid_Schema
    }

    codecs := &active.archive
    size, ok := checkpoint_body_size(codecs, cp.header, cp.settings)

    if !ok {
        return nil, .Capacity
    }

    bytes = make([]u8, sc.HEADER_BYTES + size, allocator)
    allocation := bytes
    committed := false

    defer if !committed {
        delete(allocation, allocator)
    }

    w := Checkpoint_Cursor {
        bytes = bytes[sc.HEADER_BYTES:],
    }
    checkpoint_put(&w, &codecs.parts[.Header], cp.header)
    checkpoint_put(&w, &codecs.parts[.Settings], cp.settings)
    checkpoint_put(&w, &codecs.parts[.Frame], cp.frame)
    checkpoint_put(&w, &codecs.parts[.Held], Checkpoint_Held(C, N){cp.held, cp.held_views})

    for peer in cp.peers {
        checkpoint_put(&w, &codecs.parts[.Peer], peer)
    }

    for action in cp.actions {
        checkpoint_put(&w, &codecs.parts[.Action], action)
    }

    for input in cp.inputs {
        checkpoint_put(&w, &codecs.parts[.Input], input)
    }

    for outcome in cp.outcomes {
        checkpoint_put(&w, &codecs.parts[.Outcome], outcome)
    }

    for hash in cp.banned {
        checkpoint_put(&w, &codecs.parts[.Ban], hash)
    }

    if w.failed {
        return nil, .Invalid_Checkpoint
    }

    copy(w.bytes[w.offset:], cp.policy_data)
    meta := sc.Envelope_Meta {
        kind    = CHECKPOINT_KIND,
        epoch   = cp.header.epoch,
        tick    = cp.header.tick,
        content = cp.header.content,
    }

    if sc.pack_bytes(codecs.fingerprint, meta, w.bytes, bytes).error != .None {
        return nil, .Invalid_Checkpoint
    }

    committed = true
    return bytes, .None
}

// No allocation is driven by section counts until their bounds AND the exact
// body size have been checked. Failure leaves the destination empty. Applications
// must supply their expected content ID; archives cannot choose game definitions.
checkpoint_decode :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    bytes: []u8,
    model: Model(S, C, A, $E, N),
    content: u64,
    allocator := context.allocator,
    codec: ^Checkpoint_Codec = nil,
    ownership: Container_Ownership = {},
) -> Error {
    ownership := ownership

    if model.complete_state {
        ownership = model.complete_codec.ownership
    }

    if model.complete_state {
        return checkpoint_decode_physics(cp, bytes, model, content, allocator, codec, ownership)
    }

    return checkpoint_decode_protocol(
        cp,
        bytes,
        model,
        content,
        PROTOCOL_VERSION,
        allocator,
        codec,
        ownership = ownership,
    )
}

@(private)
checkpoint_decode_protocol :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    bytes: []u8,
    model: Model(S, C, A, $E, N),
    content, protocol: u64,
    allocator: mem.Allocator,
    codec: ^Checkpoint_Codec,
    complete_identity: ^bd.Identity = nil,
    ownership: Container_Ownership = {},
) -> Error {
    if error := container_access(&cp.lifetime); error != .None {
        return error
    }

    if !checkpoint_empty(cp) {
        return .Wrong_Phase
    }

    if len(bytes) > MAX_CHECKPOINT_BYTES || content == 0 {
        return .Invalid_Checkpoint
    }

    meta, _, report := sc.inspect(bytes)

    if report.error != .None {
        return .Invalid_Checkpoint
    }

    temporary: Checkpoint_Codec
    defer checkpoint_codec_destroy(&temporary)
    active := codec

    if active == nil {
        if err := checkpoint_codec_init_owned(
            &temporary,
            S,
            C,
            A,
            E,
            N,
            true,
            allocator,
            {allocator = ownership.allocator},
            true,
        ); err != .None {
            return err
        }

        active = &temporary
    }

    if !checkpoint_codec_matches(active, S, C, A, E, N) {
        return .Invalid_Schema
    }

    if !active.network_ready {
        if !codecs_init(&active.network, S, C, A, E, N, active.archive.parts[.Header].allocator) {
            codecs_destroy(&active.network)
            return .Invalid_Schema
        }

        active.network_ready = true
    }

    codecs := &active.archive
    _, body, checked := sc.unpack_bytes(
        codecs.fingerprint,
        bytes,
        {kind = CHECKPOINT_KIND, epoch = meta.epoch, content = content},
    )

    if checked.error != .None {
        return .Invalid_Checkpoint
    }

    tmp: Checkpoint(S, C, A, N)
    tmp.allocator = allocator

    if error := container_acquire(
        &tmp.lifetime,
        ownership,
        allocator,
        ownership.data_context.data,
        #config(BOX3D_REQUIRE_DOMAIN, false),
    ); error != .None {
        checkpoint_destroy(&tmp)
        return error
    }

    committed := false

    defer if !committed {
        checkpoint_destroy(&tmp)
    }

    cursor := Checkpoint_Cursor {
        bytes = body,
    }
    checkpoint_get(&cursor, &codecs.parts[.Header], &tmp.header)
    checkpoint_get(&cursor, &codecs.parts[.Settings], &tmp.settings)

    if cursor.failed {
        return .Invalid_Checkpoint
    }

    size, ok := checkpoint_body_size(codecs, tmp.header, tmp.settings, protocol)

    if !ok ||
       size != len(body) ||
       tmp.header.content != content ||
       tmp.header.epoch != meta.epoch ||
       tmp.header.tick != meta.tick {
        return .Invalid_Checkpoint
    }

    checkpoint_get(&cursor, &codecs.parts[.Frame], &tmp.frame)
    held: Checkpoint_Held(C, N)
    checkpoint_get(&cursor, &codecs.parts[.Held], &held)
    tmp.held, tmp.held_views = held.controls, held.views

    if cursor.failed {
        return .Invalid_Checkpoint
    }

    tmp.peers = make([dynamic]Checkpoint_Peer, int(tmp.header.peers), allocator)
    tmp.actions = make([dynamic]Checkpoint_Action(A), int(tmp.header.actions), allocator)
    tmp.inputs = make([dynamic]Checkpoint_Input(C), int(tmp.header.inputs), allocator)
    tmp.outcomes = make([dynamic]Checkpoint_Outcome, int(tmp.header.outcomes), allocator)
    tmp.banned = make([dynamic][32]u8, int(tmp.header.bans), allocator)

    for &peer in tmp.peers {
        checkpoint_get(&cursor, &codecs.parts[.Peer], &peer)
    }

    for &action in tmp.actions {
        checkpoint_get(&cursor, &codecs.parts[.Action], &action)
    }

    for &input in tmp.inputs {
        checkpoint_get(&cursor, &codecs.parts[.Input], &input)
    }

    for &outcome in tmp.outcomes {
        checkpoint_get(&cursor, &codecs.parts[.Outcome], &outcome)
    }

    for &hash in tmp.banned {
        checkpoint_get(&cursor, &codecs.parts[.Ban], &hash)
    }

    if cursor.failed {
        return .Invalid_Checkpoint
    }

    tmp.policy_data = make([]u8, int(tmp.header.policy_bytes), allocator)
    copy(tmp.policy_data, body[cursor.offset:])
    tmp.ready = true

    if !checkpoint_valid_protocol(&tmp, model, protocol) {
        return .Invalid_Checkpoint
    }

    network_codecs := &active.network
    maximum :=
        max(network_codecs.welcome.wire_size, max(network_codecs.snapshot.wire_size, network_codecs.facts.wire_size)) +
        sc.HEADER_BYTES

    if int(tmp.settings.egress_bytes_per_pump) < maximum {
        return .Invalid_Checkpoint
    }

    contract := contract_hash(
        network_codecs,
        checkpoint_config(tmp.header, tmp.settings),
        N,
        model.control_timing,
        protocol,
        model.replication.id,
        model.action_timing,
        model.action_schedule.id,
        model.authority.id,
    )

    if complete_identity != nil {
        contract = physics_contract(contract, complete_identity^)
    }

    if contract != tmp.header.contract {
        return .Checkpoint_Contract
    }

    cp^ = tmp // ownership transfer, never an initialized server or aliased owner
    committed = true
    return .None
}

@(private)
Checkpoint_Part :: enum {
    Header,
    Settings,
    Frame,
    Held,
    Peer,
    Action,
    Input,
    Outcome,
    Ban,
}

@(private)
Checkpoint_Codecs :: struct {
    parts:       [Checkpoint_Part]sc.Schema,
    fingerprint: u64,
}

@(private)
checkpoint_codecs_init :: proc(c: ^Checkpoint_Codecs, $S, $C, $A: typeid, $N: int, allocator: mem.Allocator) -> bool {
    if sc.init(&c.parts[.Header], Checkpoint_Header, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Settings], Checkpoint_Settings, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Frame], r.Frame(S), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Held], Checkpoint_Held(C, N), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Peer], Checkpoint_Peer, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Action], Checkpoint_Action(A), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Input], Checkpoint_Input(C), allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Outcome], Checkpoint_Outcome, allocator = allocator).error != .None {
        return false
    }

    if sc.init(&c.parts[.Ban], [32]u8, allocator = allocator).error != .None {
        return false
    }

    c.fingerprint = 0xcbf29ce484222325
    c.fingerprint = (c.fingerprint ~ u64(CHECKPOINT_VERSION)) * 0x100000001b3

    for part in c.parts {
        c.fingerprint = (c.fingerprint ~ part.fingerprint) * 0x100000001b3
    }

    return true
}

@(private)
checkpoint_codecs_destroy :: proc(c: ^Checkpoint_Codecs) {
    for &part in c.parts {
        sc.destroy(&part)
    }

    c^ = {}
}

@(private)
checkpoint_body_size :: proc(
    c: ^Checkpoint_Codecs,
    h: Checkpoint_Header,
    s: Checkpoint_Settings,
    protocol: u64 = PROTOCOL_VERSION,
) -> (
    int,
    bool,
) {
    if h.version != CHECKPOINT_VERSION ||
       h.protocol != protocol ||
       !config_valid(checkpoint_config(h, s)) ||
       h.peers > MAX_PEERS ||
       h.actions > MAX_PEERS * ACTION_CAPACITY ||
       h.outcomes > MAX_PEERS * ACTION_CAPACITY ||
       h.bans > 64 ||
       h.policy_bytes > 65536 ||
       h.inputs > MAX_PEERS * s.max_future {
        return 0, false
    }

    counts: [Checkpoint_Part]u64
    counts[.Header], counts[.Settings], counts[.Frame], counts[.Held] = 1, 1, 1, 1
    counts[.Peer], counts[.Action], counts[.Input] = u64(h.peers), u64(h.actions), u64(h.inputs)
    counts[.Outcome], counts[.Ban] = u64(h.outcomes), u64(h.bans)
    size := u64(h.policy_bytes)

    for part, i in c.parts {
        size += u64(part.wire_size) * counts[i]
    }

    if size > MAX_CHECKPOINT_BYTES - sc.HEADER_BYTES {
        return 0, false
    }

    return int(size), true
}

@(private)
Checkpoint_Cursor :: struct {
    bytes:  []u8,
    offset: int,
    failed: bool,
}

@(private)
checkpoint_put :: proc(c: ^Checkpoint_Cursor, schema: ^sc.Schema, value: $T) {
    if c.failed {
        return
    }

    if schema.wire_size > len(c.bytes) - c.offset {
        c.failed = true
        return
    }

    c.failed = sc.encode(schema, value, c.bytes[c.offset:c.offset + schema.wire_size]).error != .None
    c.offset += schema.wire_size
}

@(private)
checkpoint_get :: proc(c: ^Checkpoint_Cursor, schema: ^sc.Schema, value: ^$T) {
    if c.failed {
        return
    }

    if schema.wire_size > len(c.bytes) - c.offset {
        c.failed = true
        return
    }

    c.failed = sc.decode(schema, value, c.bytes[c.offset:c.offset + schema.wire_size]).error != .None
    c.offset += schema.wire_size
}

// Requested bytes retained by this immutable schema cache. Compiler-owned type
// information and allocator headers/rounding are separate host overhead.
checkpoint_codec_owned_bytes :: proc(c: ^Checkpoint_Codec) -> u64 {
    if c == nil {
        return 0
    }

    bytes := u64(size_of(Checkpoint_Codec)) + physics_codecs_bytes(&c.network)

    for &schema in c.archive.parts {
        bytes += complete_schema_owned_bytes(&schema)
    }

    return bytes
}
