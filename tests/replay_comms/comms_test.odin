package replay_comms_test
import "core:testing"
import "core:reflect"
import co "godot:replay/comms"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import lb "godot:replay/lobby"

// The adversarial fixture describes the wire independently of package internals.
// Schema type names are not part of the fingerprint; logical field names are.
WIRE_PACKET_KIND :: u16(0x434d)

Wire_Kind :: enum u8 {
    None,
    Request,
    Ack,
    Deliver,
}

Wire_Delivery :: struct {
    entry:      co.Entry,
    historical: bool,
}

Wire_Packet :: struct {
    version:                u16,
    room, binding, request: u64,
    kind:                   Wire_Kind,
    result:                 co.Result,
    delivery:               Wire_Delivery,
}

wire_schema :: proc(schema: ^sc.Schema, chat: ^co.Comms) {
    assert(sc.init(schema, Wire_Packet).error == .None)
    assert(schema.fingerprint == chat.codec.fingerprint)
}

Fixture :: struct {
    memory:              tr.Memory,
    ep:                  [3]tr.Memory_Endpoint,
    chat:                [3]co.Comms,
    tick:                u64,
    epoch:               u64,
    observer_generation: u64,
    observer_names:      bool,
    observer_name:       lb.Name,
}

HOST :: co.Binding {
    peer = 1,
    generation = 11,
    seat = 1,
    identity = {0 = 1},
}
GUEST :: co.Binding {
    peer = 2,
    generation = 22,
    seat = 2,
    identity = {0 = 2},
}
OBSERVER :: co.Binding {
    peer = 3,
    generation = 33,
    identity = {0 = 3},
    spectator = true,
}

start :: proc(f: ^Fixture) {
    assert(
        tr.memory_init(
            &f.memory,
            941,
            {3, 512, 8192, 65536},
            {latency_ticks = 2, jitter_ticks = 2, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3},
        ),
    )

    for &ep, i in f.ep {
        assert(tr.memory_open(&f.memory, &ep, tr.Peer_Id(i + 1)))
        assert(co.init(&f.chat[i]))
    }

    f.epoch = 1
    f.observer_generation = 33
    step(f)
}

finish :: proc(f: ^Fixture) {
    for &chat in f.chat {
        co.destroy(&chat)
    }

    for &ep in f.ep {
        wire := tr.memory_transport(&ep)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

step :: proc(f: ^Fixture) {
    f.tick += 1
    assert(tr.memory_advance(&f.memory, f.tick))
    scope := co.Scope{4, f.epoch, 19}
    connections := [2]co.Binding{GUEST, OBSERVER}
    connections[1].generation = f.observer_generation
    connections[1].observer_name_allowed = f.observer_names
    assert(
        co.configure(&f.chat[0], tr.memory_transport(&f.ep[0]), scope, true, HOST, connections[:], true, f.tick * 20),
    )

    for i in 1 ..< 3 {
        binding := HOST
        binding.generation = connections[i - 1].generation
        local := connections[i - 1]

        if i == 2 {
            local.name = f.observer_name
        }

        assert(
            co.configure(
                &f.chat[i],
                tr.memory_transport(&f.ep[i]),
                scope,
                false,
                local,
                []co.Binding{binding},
                true,
                f.tick * 20,
            ),
        )
    }

    for &chat in f.chat {
        co.frame(&chat)
    }
}

@(test)
ordered_echo_markers_and_generation_rebinding :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    testing.expect_value(t, co.say(&f.chat[0], "found a torch"), co.Result.None)
    testing.expect_value(t, co.say(&f.chat[1], "on my way"), co.Result.None)
    testing.expect_value(t, co.mark(&f.chat[1], 1, {330, 210, 0}), co.Result.None)
    testing.expect_value(t, co.mark(&f.chat[2], 1, {1, 2, 0}), co.Result.Permission)

    for _ in 0 ..< 80 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect_value(t, chat.line_count, 2)
        testing.expect(t, reflect.equal(chat.lines[:2], f.chat[0].lines[:2], true))
        marker, ok := co.poll_marker(&chat)
        testing.expect(t, ok && marker.seat == 2 && marker.value.position == ([3]f32{330, 210, 0}))
        _, again := co.poll_marker(&chat)
        testing.expect(t, !again)
    }

    old := f.chat[0].lines[0]
    co.say(&f.chat[1], "unsent at handoff")
    f.epoch = 2
    step(&f)
    testing.expect_value(t, f.chat[1].scope_drops, u64(1))
    testing.expect(t, f.chat[1].lines[0] == old)
    co.say(&f.chat[1], "after handoff")

    for _ in 0 ..< 70 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect_value(t, chat.line_count, 3)
        testing.expect_value(t, chat.lines[2].id.epoch, u64(2))
    }
}

@(test)
canonical_text_and_marker_validation :: proc(t: ^testing.T) {
    for text in ([]string{"", "two\nlines", "tab\tline", "bad\xff", "two\u2028lines", "next\u0085line"}) {
        _, ok := co.text_payload(text)
        testing.expect(t, !ok)
    }

    long: [242]u8

    for &b in long {
        b = 'a'
    }

    long[238], long[239], long[240], long[241] = 0xf0, 0x9f, 0xaa, 0xa8
    payload, ok := co.text_payload(string(long[:]))
    testing.expect(t, ok && payload.length == 238 && co.valid(payload))
    payload.text[239] = 1
    testing.expect(t, !co.valid(payload))
    testing.expect(t, !co.valid(co.Payload{kind = .Marker, tag = 1, position = {1e8, 0, 0}}))
}

@(test)
forged_speaker_stale_binding_and_duplicate_ack_are_rejected :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    payload, _ := co.text_payload("forged")
    packet := Wire_Packet {
        version = 2,
        room = 4,
        binding = 22,
        request = 1,
        kind = .Request,
        delivery = {entry = {seat = 1, value = payload}},
    }
    codec_storage: sc.Schema
    wire_schema(&codec_storage, &f.chat[0])
    defer sc.destroy(&codec_storage)
    bytes: [1024]u8
    codec := &codec_storage
    size := codec.wire_size + sc.HEADER_BYTES

    pack :: proc(codec: ^sc.Schema, p: Wire_Packet, bytes: []u8) {
        assert(sc.pack(codec, p, {kind = WIRE_PACKET_KIND, epoch = 1, content = 19}, bytes).error == .None)
    }

    pack(codec, packet, bytes[:])
    co.receive(&f.chat[0], 2, .Reliable, bytes[:size])
    testing.expect_value(t, f.chat[0].line_count, 0)
    packet.delivery.entry.seat = 0
    packet.binding = 21
    pack(codec, packet, bytes[:])
    co.receive(&f.chat[0], 2, .Reliable, bytes[:size])
    packet.binding = 22
    pack(codec, packet, bytes[:])
    co.receive(&f.chat[0], 99, .Reliable, bytes[:size])
    testing.expect_value(t, f.chat[0].rejected, u64(3))
    co.say(&f.chat[1], "first")
    co.say(&f.chat[1], "second")
    co.frame(&f.chat[1])
    testing.expect(t, f.chat[1].request_active)
    packet = {
        version = 2,
        room    = 4,
        binding = 22,
        request = 1,
        kind    = .Ack,
    }
    pack(codec, packet, bytes[:])
    co.receive(&f.chat[1], 1, .Reliable, bytes[:size])
    co.receive(&f.chat[1], 1, .Reliable, bytes[:size])
    testing.expect_value(t, f.chat[1].pending_count, 1)
    testing.expect_value(t, f.chat[1].result_serial, u64(1))
}

@(test)
backpressure_is_atomic_and_rate_limit_is_per_sender :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    f.chat[0].peers[0].count = co.OUTBOX
    co.say(&f.chat[0], "cannot fan out")
    co.frame(&f.chat[0])
    testing.expect_value(t, f.chat[0].last_result, co.Result.Capacity)
    testing.expect_value(t, f.chat[0].line_count, 0)
    f.chat[0].peers[0].count = 0

    for _ in 0 ..< 5 {
        co.say(&f.chat[0], "burst")
    }

    co.frame(&f.chat[0])
    testing.expect_value(t, f.chat[0].last_result, co.Result.Rate_Limited)
    co.say(&f.chat[1], "other sender")

    for _ in 0 ..< 60 {
        step(&f)
    }

    testing.expect(t, f.chat[0].lines[f.chat[0].line_count - 1].seat == 2)
}

@(test)
late_join_replays_bounded_history_without_markers_and_fencing_drops_pending :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)

    for _ in 0 ..< 90 {
        testing.expect_value(t, co.system(&f.chat[0], "retained system line"), co.Result.None)

        for _ in 0 ..< 3 {
            step(&f)
        }
    }

    co.mark(&f.chat[0], 1, {1, 2, 0})

    for _ in 0 ..< 30 {
        step(&f)
    }

    co.destroy(&f.chat[2])
    assert(co.init(&f.chat[2]))
    f.observer_generation += 1

    for _ in 0 ..< 50 {
        step(&f)
    }

    testing.expect_value(t, f.chat[2].line_count, co.HISTORY)
    testing.expect_value(t, f.chat[2].marker_count, 0)
    testing.expect(t, reflect.equal(f.chat[2].lines[:], f.chat[0].lines[:], true))
    co.say(&f.chat[1], "waiting at fence")
    local := GUEST
    peer := HOST
    peer.generation = local.generation
    testing.expect(
        t,
        co.configure(
            &f.chat[1],
            tr.memory_transport(&f.ep[1]),
            {4, 1, 19},
            false,
            local,
            []co.Binding{peer},
            false,
            f.tick * 20,
        ),
    )
    testing.expect_value(t, co.say(&f.chat[1], "not allowed"), co.Result.Not_Ready)
    testing.expect_value(t, f.chat[1].pending_count, 0)
    testing.expect_value(t, f.chat[1].scope_drops, u64(1))
    f.epoch = 2
    step(&f)
    testing.expect(
        t,
        !co.configure(
            &f.chat[1],
            tr.memory_transport(&f.ep[1]),
            {4, 1, 19},
            false,
            local,
            []co.Binding{peer},
            true,
            f.tick * 20,
        ),
    )
}

@(test)
unread_results_reserve_capacity_and_preserve_each_payload :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)

    for _ in 0 ..< co.PENDING {
        testing.expect_value(t, co.say(&f.chat[0], "queued"), co.Result.None)
    }

    co.frame(&f.chat[0])
    testing.expect_value(t, co.say(&f.chat[0], "would overwrite results"), co.Result.Capacity)

    for i in 0 ..< co.PENDING {
        receipt, ok := co.poll_result(&f.chat[0])
        testing.expect(t, ok && receipt.submission == u64(i + 1))
        testing.expect_value(t, receipt.result, i < 4 ? co.Result.None : co.Result.Rate_Limited)
        testing.expect_value(t, receipt.value.length, u16(6))
    }

    testing.expect_value(t, co.say(&f.chat[0], "capacity released"), co.Result.None)
}

@(test)
observer_names_are_captured_per_submission_without_changing_identity_or_permissions :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    f.observer_names = true
    f.observer_name, _ = lb.name("Mira 🦉")
    step(&f)
    first := f.observer_name
    testing.expect_value(t, co.say(&f.chat[2], "watching"), co.Result.None)
    f.observer_name, _ = lb.name("Mira renamed")

    for _ in 0 ..< 60 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect_value(t, chat.line_count, 1)
        entry := chat.lines[0]
        testing.expect(t, entry.name == first && entry.identity == OBSERVER.identity && entry.seat == 0)
    }

    testing.expect_value(t, co.mark(&f.chat[2], 1, {1, 2, 0}), co.Result.Permission)
    testing.expect_value(t, co.say(&f.chat[2], "new label"), co.Result.None)

    for _ in 0 ..< 60 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect(t, chat.line_count == 2 && chat.lines[1].name == f.observer_name && chat.lines[0].name == first)
    }

    f.epoch = 2
    step(&f)
    testing.expect_value(t, co.say(&f.chat[2], "after handoff"), co.Result.None)

    for _ in 0 ..< 60 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect(
            t,
            chat.line_count == 3 &&
            chat.lines[2].name == f.observer_name &&
            chat.lines[2].id.epoch == 2 &&
            chat.lines[2].identity == OBSERVER.identity,
        )
    }
}

@(test)
legacy_observer_requests_keep_the_empty_claimed_name :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    f.observer_name, _ = lb.name("local name")
    step(&f)
    co.say(&f.chat[2], "legacy")

    for _ in 0 ..< 60 {
        step(&f)
    }

    for &chat in f.chat {
        testing.expect(
            t,
            chat.line_count == 1 && chat.lines[0].name == (lb.Name{}) && chat.lines[0].identity == OBSERVER.identity,
        )
    }
}

@(test)
observer_display_metadata_cannot_forge_players_or_bypass_name_validation :: proc(t: ^testing.T) {
    for mode in 0 ..< 6 {
        f: Fixture
        start(&f)
        defer finish(&f)
        f.observer_names = mode != 1
        step(&f)
        name, _ := lb.name("claimed")
        payload, _ := co.text_payload("message")
        packet := Wire_Packet {
            version = 2,
            room = 4,
            binding = 33,
            request = 1,
            kind = .Request,
            delivery = {entry = {name = name, value = payload}},
        }
        from := tr.Peer_Id(3)

        switch mode {
        case 0:
            from = 2
            packet.binding = 22 // Even an advertised capability cannot override a player name.

            for &peer in f.chat[0].peers {
                if peer.binding.peer == 2 {
                    peer.binding.observer_name_allowed = true
                }
            }
        case 1: // Observer without permission cannot claim a name.
        case 2:
            packet.delivery.entry.name.bytes[0] = '\n'
        case 3:
            packet.binding = 32
        case 4:
            packet.delivery.entry.identity = HOST.identity
        case 5:
            packet.delivery.entry.seat = 1
        }

        codec_storage: sc.Schema
        wire_schema(&codec_storage, &f.chat[0])
        defer sc.destroy(&codec_storage)
        bytes: [1024]u8
        codec := &codec_storage
        assert(sc.pack(codec, packet, {kind = WIRE_PACKET_KIND, epoch = 1, content = 19}, bytes[:]).error == .None)
        co.receive(&f.chat[0], from, .Reliable, bytes[:sc.HEADER_BYTES + codec.wire_size])
        testing.expect(t, f.chat[0].rejected > 0 && f.chat[0].line_count == 0)
    }
}
