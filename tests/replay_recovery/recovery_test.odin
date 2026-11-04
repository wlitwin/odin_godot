package replay_recovery_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

World :: struct {
    ticks:  u32,
    coins:  u32,
    bags:   [2]u32,
    secret: u64 `replay:"authority"`,
}

Control :: struct {
    axis: i8,
}

Action :: struct {
    take: bool,
}

Event :: struct {
    seat: u16,
}

Model :: net.Model(World, Control, Action, Event, 2)
Checkpoint :: net.Checkpoint(World, Control, Action, 2)
Receiver :: rec.Receiver(World, Control, Action, Event, 2)
SCOPE :: rec.Scope{11, 1, 22, 1}

model :: proc() -> Model {
    return {step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
            w.ticks += 1
        }, action = proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
            if !a.take || w.coins == 0 {
                return false
            }

            w.bags[seat - 1] += w.coins
            w.coins = 0
            r.emit(ctx, u64(seat), 1, Event{seat})
            return true
        }, control_valid = proc(c: Control) -> bool {
            return c.axis >= -1 && c.axis <= 1
        }, action_valid = proc(a: Action) -> bool {
            return a.take
        }, state_valid = proc(w: World) -> bool {
            return w.coins + w.bags[0] + w.bags[1] == 5 && w.secret == 0x123456789
        }, hold = proc(c: Control) -> Control {
            return c
        }}
}

Fixture :: struct {
    server:                   net.Server(World, Control, Action, Event, 2),
    memory:                   tr.Memory,
    endpoints:                [3]tr.Memory_Endpoint,
    sender:                   rec.Sender,
    receiver:                 Receiver,
    tick:                     u64,
    drop_ready, drop_chunks:  bool,
    last_offer, last_ready:   [1200]u8,
    offer_bytes, ready_bytes: int,
}

init :: proc(f: ^Fixture, faults := tr.DEFAULT_FAULTS) {
    assert(tr.memory_init(&f.memory, 42, {3, 128, 1200, 32768}, faults))

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.memory, &endpoint, tr.Peer_Id(i + 1)))
    }

    assert(
        net.server_init(
            &f.server,
            r.Frame(World){state = {coins = 5, secret = 0x123456789}},
            model(),
            {},
            local_seat = 1,
        ) ==
        .None,
    )
    assert(net.server_set_local_token(&f.server, net.Token{0 = 7}) == .None)
    assert(net.server_step(&f.server) == .None)
    net.server_issue(&f.server, Action{take = true})
    assert(net.server_step(&f.server) == .None)
    cfg := rec.DEFAULT_CONFIG
    cfg.timeout_ms = 2000
    assert(rec.sender_init(&f.sender, SCOPE, 2, tr.memory_transport(&f.endpoints[0]), cfg) == .None)
    assert(rec.receiver_init(&f.receiver, SCOPE, 1, tr.memory_transport(&f.endpoints[1]), model(), cfg) == .None)
}

destroy :: proc(f: ^Fixture) {
    rec.sender_destroy(&f.sender)
    rec.receiver_destroy(&f.receiver)
    net.server_destroy(&f.server)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

publish :: proc(f: ^Fixture) {
    assert(net.server_step(&f.server) == .None)
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_capture(&f.server, &cp) == .None)
    assert(rec.sender_publish(&f.sender, &cp, model(), f.tick * 10) == .None)
}

step :: proc(f: ^Fixture) {
    f.tick += 1
    assert(tr.memory_advance(&f.memory, f.tick))
    buffer: [1200]u8

    for &endpoint, i in f.endpoints[:2] {
        wire := tr.memory_transport(&endpoint)

        for _ in 0 ..< 128 {
            packet := tr.receive(&wire, buffer[:])

            if packet.state == .Empty {
                break
            }

            assert(packet.state == .Received)
            bytes := buffer[:packet.count]
            meta, _, _ := sc.inspect(bytes)

            if i == 0 {
                if meta.kind == 0x5104 {
                    copy(f.last_ready[:], bytes)
                    f.ready_bytes = len(bytes)

                    if f.drop_ready {
                        continue
                    }
                }

                rec.sender_receive(&f.sender, packet.from, bytes, f.tick * 10)
            } else {
                if meta.kind == 0x5101 {
                    copy(f.last_offer[:], bytes)
                    f.offer_bytes = len(bytes)
                }

                if meta.kind == 0x5102 && f.drop_chunks {
                    continue
                }

                rec.receiver_receive(&f.receiver, packet.from, bytes, f.tick * 10)
            }
        }
    }

    rec.sender_update(&f.sender, f.tick * 10)
    rec.receiver_update(&f.receiver, f.tick * 10)
}

complete :: proc(f: ^Fixture) {
    for _ in 0 ..< 250 {
        step(f)

        if f.sender.phase == .Complete {
            return
        }
    }

    assert(false, "transfer did not complete")
}

@(test)
validated_receipt_restores_private_state_and_action_dedup_frontier :: proc(t: ^testing.T) {
    f: Fixture
    init(&f, {latency_ticks = 2, jitter_ticks = 4, loss_permyriad = 2000, duplicate_permyriad = 5000, retry_ticks = 3})
    defer destroy(&f)
    publish(&f)
    complete(&f)
    receipt, found := rec.receiver_latest(&f.receiver)
    testing.expect(t, found)
    testing.expect_value(t, receipt.archive, f.sender.acknowledged.archive)
    cp, usable := rec.receiver_checkpoint(&f.receiver, f.sender.acknowledged.archive)
    testing.expect(t, usable)
    restored: net.Server(World, Control, Action, Event, 2)
    defer net.server_destroy(&restored)
    testing.expect_value(
        t,
        net.server_restore(&restored, cp, model(), {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    frame, _ := r.current(&restored.timeline)
    truth, _ := r.current(&f.server.timeline)
    testing.expect(t, reflect.equal(frame, truth))
    sequence, err := net.server_issue(&restored, Action{take = true})
    testing.expect_value(t, sequence, u64(2))
    testing.expect_value(t, err, net.Error.None)
    net.server_step(&restored)
    frame, _ = r.current(&restored.timeline)
    testing.expect_value(t, frame.state.bags[0], u32(5))
    testing.expect_value(t, f.receiver.stats.validated, u64(1))
}

@(test)
lost_ready_and_replaced_transfer_keep_the_authoritys_acknowledged_archive :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    publish(&f)
    complete(&f)
    anchor := f.sender.acknowledged.archive
    f.drop_ready = true
    publish(&f)

    for _ in 0 ..< 40 {
        step(&f)
    }

    unacknowledged, _ := rec.receiver_latest(&f.receiver)
    testing.expect_value(t, unacknowledged.archive.sequence, u64(2))
    testing.expect_value(t, f.sender.acknowledged.archive, anchor)
    rec.sender_cancel(&f.sender)
    publish(&f)

    for _ in 0 ..< 40 {
        step(&f)
    }

    latest, _ := rec.receiver_latest(&f.receiver)
    testing.expect_value(t, latest.archive.sequence, u64(3))
    _, present := rec.receiver_checkpoint(&f.receiver, anchor)
    testing.expect(t, present)
    _, present = rec.receiver_checkpoint(&f.receiver, unacknowledged.archive)
    testing.expect(t, !present)
    f.drop_ready = false
    complete(&f)
    testing.expect_value(t, f.sender.acknowledged.archive, latest.archive)
    publish(&f)
    complete(&f)
    _, present = rec.receiver_checkpoint(&f.receiver, latest.archive)
    testing.expect(t, present)
    _, present = rec.receiver_checkpoint(&f.receiver, anchor)
    testing.expect(t, !present)
}

@(test)
failed_and_timed_out_candidates_never_replace_a_usable_archive :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    publish(&f)
    complete(&f)
    anchor := f.sender.acknowledged.archive
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    cp.frame.state.coins = 100 // canonical bytes, invalid game state
    permissive := model()
    permissive.state_valid = proc(w: World) -> bool {
        return true
    }
    bytes, err := net.checkpoint_encode(&cp, permissive)
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, rec.sender_begin(&f.sender, bytes, f.tick * 10), rec.Error.None)

    for _ in 0 ..< 40 {
        step(&f)
    }

    testing.expect_value(t, f.sender.phase, rec.Phase.Failed)
    testing.expect_value(t, f.sender.remote_failure, rec.Failure.Archive)
    latest, _ := rec.receiver_latest(&f.receiver)
    testing.expect_value(t, latest.archive, anchor)
    f.drop_chunks = true
    publish(&f)

    for _ in 0 ..< 220 {
        step(&f)
    }

    testing.expect_value(t, f.sender.error, rec.Error.Timeout)
    latest, _ = rec.receiver_latest(&f.receiver)
    testing.expect_value(t, latest.archive, anchor)
    f.drop_chunks = false
    publish(&f)
    complete(&f)
    testing.expect(t, f.sender.acknowledged.archive.sequence > anchor.sequence)
}

@(test)
successor_rebinding_clears_receipts_and_rejects_delayed_old_connection_packets :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    publish(&f)
    complete(&f)
    old_offer, old_ready := f.last_offer, f.last_ready
    old_offer_bytes, old_ready_bytes := f.offer_bytes, f.ready_bytes
    scope := SCOPE
    scope.binding += 1
    rec.sender_destroy(&f.sender)
    rec.receiver_destroy(&f.receiver)
    rec.sender_init(&f.sender, scope, 2, tr.memory_transport(&f.endpoints[0]))
    rec.receiver_init(&f.receiver, scope, 1, tr.memory_transport(&f.endpoints[1]), model())
    testing.expect_value(t, f.sender.acknowledged.archive.sequence, u64(0))
    testing.expect_value(
        t,
        rec.receiver_receive(&f.receiver, 1, old_offer[:old_offer_bytes], f.tick * 10),
        rec.Received.Rejected,
    )
    // Same archive/sequence/tick after rebinding: the binding check itself must
    // reject the old Ready, rather than relying on a coincidental newer tick.
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    rec.sender_publish(&f.sender, &cp, model(), f.tick * 10)
    testing.expect_value(
        t,
        rec.sender_receive(&f.sender, 2, old_ready[:old_ready_bytes], f.tick * 10),
        rec.Received.Rejected,
    )
    complete(&f)
    testing.expect_value(t, f.sender.acknowledged.archive.sequence, u64(1))
}

@(test)
wrong_peer_corrupt_header_and_invalid_time_do_not_advance_transfer_state :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    f.drop_ready = true
    publish(&f)

    for _ in 0 ..< 40 {
        step(&f)
    }

    ready := f.last_ready
    size := f.ready_bytes
    testing.expect(t, size > 0)
    testing.expect_value(
        t,
        rec.receiver_receive(&f.receiver, 3, f.last_offer[:f.offer_bytes], f.tick * 10),
        rec.Received.Rejected,
    )
    testing.expect_value(t, rec.sender_receive(&f.sender, 3, ready[:size], f.tick * 10), rec.Received.Rejected)
    ready[size - 1] ~= 1
    testing.expect_value(t, rec.sender_receive(&f.sender, 2, ready[:size], f.tick * 10), rec.Received.Rejected)
    testing.expect_value(t, rec.sender_update(&f.sender, f.tick * 10 - 1), rec.Error.Invalid_Time)
    testing.expect_value(t, f.sender.phase, rec.Phase.Sending)
    ready[size - 1] ~= 1
    testing.expect_value(
        t,
        rec.sender_receive(&f.sender, 2, ready[:size], f.tick * 10 + f.sender.cfg.timeout_ms),
        rec.Received.Rejected,
    )
    testing.expect_value(t, f.sender.error, rec.Error.Timeout)
}

@(test)
custom_room_policy_requires_explicit_successor_support_before_acknowledgement :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    f.server.admission = proc(user: rawptr, digest: [32]u8, observer: bool) -> bool {
        return true
    }
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    policy := [2]u8{4, 2}
    net.checkpoint_capture(&f.server, &cp, 99, policy[:])
    rec.sender_publish(&f.sender, &cp, model(), 0)

    for _ in 0 ..< 40 {
        step(&f)
    }

    testing.expect_value(t, f.sender.remote_failure, rec.Failure.Archive)
    _, ready := rec.receiver_latest(&f.receiver)
    testing.expect(t, !ready)
    f.receiver.policy_valid = proc(user: rawptr, id: u64, bytes: []u8) -> bool {
        return id == 99 && len(bytes) == 2 && bytes[0] == 4 && bytes[1] == 2
    }
    rec.sender_publish(&f.sender, &cp, model(), f.tick * 10)
    complete(&f)
    _, ready = rec.receiver_latest(&f.receiver)
    testing.expect(t, ready)
}

@(test)
offer_bounds_version_and_retention_claims_reject_before_reassembly_changes :: proc(t: ^testing.T) {
    f: Fixture
    init(&f)
    defer destroy(&f)
    publish(&f)
    complete(&f)
    anchor := f.sender.acknowledged.archive
    schema: sc.Schema
    defer sc.destroy(&schema)
    sc.init(&schema, type_of(f.receiver.offer))
    buffer: [1200]u8
    cases := [4]int{0, 1, 2, 3}

    for scenario in cases {
        packet := f.receiver.offer
        packet.archive.sequence += 1

        switch scenario {
        case 0:
            packet.archive.bytes = net.MAX_CHECKPOINT_BYTES + 1
        case 1:
            packet.version += 1
        case 2:
            packet.chunk_bytes = 2048
        case 3:
            packet.retain_sequence = 1234
        }

        sc.pack(
            &schema,
            packet,
            {kind = 0x5101, epoch = SCOPE.epoch, tick = packet.archive.tick, content = SCOPE.content},
            buffer[:],
        )
        testing.expect_value(
            t,
            rec.receiver_receive(&f.receiver, 1, buffer[:sc.HEADER_BYTES + schema.wire_size], f.tick * 10),
            rec.Received.Rejected,
        )
        latest, _ := rec.receiver_latest(&f.receiver)
        testing.expect_value(t, latest.archive, anchor)
        testing.expect(t, !f.receiver.active)
        testing.expect_value(t, len(f.receiver.bytes), net.MAX_CHECKPOINT_BYTES)
    }
}
