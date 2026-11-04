package replay_transport_trace_test
import "core:testing"
import "core:bytes"
import "core:mem"
import "base:runtime"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import tape "godot:replay/transport/trace"

Source :: struct {
    sent, polls, closed, generations, receives: int,
    packet:                                     [3]u8,
}

source_wire :: proc(s: ^Source) -> tr.Transport {
    return {user = s, send = proc(p: rawptr, to: tr.Peer_Id, ch: tr.Channel, b: []u8) -> tr.Send_Result {
            s := cast(^Source)p
            s.sent += 1
            return .Backpressure
        }, receive = proc(p: rawptr, dst: []u8) -> tr.Received {
            s := cast(^Source)p
            s.receives += 1

            if len(dst) < 3 {
                return {state = .Buffer_Too_Small, from = 7, count = 3}
            }

            copy(dst, s.packet[:])
            return {state = .Received, from = 7, channel = .Unreliable, count = 3}
        }, poll = proc(p: rawptr) {
            (cast(^Source)p).polls += 1
        }, status = proc(p: rawptr) -> tr.Status {
            return .Connected
        }, generation = proc(p: rawptr, peer: tr.Peer_Id) -> u64 {
            s := cast(^Source)p
            s.generations += 1
            return 0
        }, close = proc(p: rawptr) {
            (cast(^Source)p).closed += 1
        }}
}

exercise :: proc(t: ^testing.T, wire: ^tr.Transport) {
    tr.poll(wire)
    testing.expect_value(t, tr.status(wire), tr.Status.Connected)
    testing.expect(t, tr.peer_connected(wire, 7)) // missing callback falls back to status
    b := [3]u8{1, 2, 3}
    testing.expect_value(t, tr.send(wire, 7, .Reliable, b[:]), tr.Send_Result.Backpressure)
    tiny: [1]u8
    r := tr.receive(wire, tiny[:])
    testing.expect_value(t, r.state, tr.Receive_State.Buffer_Too_Small)
    full: [3]u8
    r = tr.receive(wire, full[:])
    testing.expect_value(t, r.state, tr.Receive_State.Received)
    testing.expect(t, bytes.equal(full[:], b[:]))
    testing.expect_value(t, r.generation, u64(0))
    tr.close(wire)
}

@(test)
round_trip_preserves_calls_bytes_nil_callbacks_and_zero_generations :: proc(t: ^testing.T) {
    log: tape.Log
    testing.expect(t, tape.init(&log))
    defer tape.destroy(&log)
    source := Source {
        packet = {1, 2, 3},
    }
    capture: tape.Capture
    wire := tape.capture(&capture, &log, source_wire(&source))
    testing.expect(t, wire.connected == nil)
    exercise(t, &wire)
    testing.expect_value(t, source.generations, 2)
    testing.expect_value(t, source.receives, 2)
    testing.expect_value(t, source.closed, 1)
    tape.mark(&log, 42, 99)
    encoded, err := tape.encode(&log)
    testing.expect_value(t, err, tape.Error.None)
    defer delete(encoded)
    decoded: tape.Log
    defer tape.destroy(&decoded)
    testing.expect_value(t, tape.decode(&decoded, encoded), tape.Error.None)
    replay: tape.Replay
    wire = tape.replay(&replay, &decoded)
    testing.expect(t, wire.connected == nil)
    exercise(t, &wire)
    e, ok := tape.read_mark(&replay, 42)
    testing.expect(t, ok && e.generation == 99 && tape.finished(&replay))
    testing.expect_value(t, source.sent, 1)
    testing.expect_value(t, source.polls, 1) // replay touched no source
}

@(test)
capacity_failure_keeps_forwarding_and_cannot_masquerade_as_a_complete_log :: proc(t: ^testing.T) {
    log: tape.Log
    testing.expect(t, tape.init(&log, {1, 1}))
    defer tape.destroy(&log)
    s := Source {
        packet = {1, 2, 3},
    }
    c: tape.Capture
    wire := tape.capture(&c, &log, source_wire(&s))
    data := [3]u8{1, 2, 3}
    testing.expect_value(t, tr.send(&wire, 7, .Reliable, data[:]), tr.Send_Result.Backpressure)
    testing.expect_value(t, log.error, tape.Error.Capacity)
    tr.poll(&wire)
    testing.expect_value(t, s.polls, 1)
    _, e := tape.encode(&log)
    testing.expect_value(t, e, tape.Error.Invalid)
    p: tape.Replay
    tape.replay(&p, &log)
    testing.expect_value(t, p.error, tape.Error.Invalid)
}

@(test)
replay_reports_wrong_order_arguments_and_exhaustion :: proc(t: ^testing.T) {
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    s := Source{}
    c: tape.Capture
    wire := tape.capture(&c, &log, source_wire(&s))
    tr.poll(&wire)
    p: tape.Replay
    wire = tape.replay(&p, &log)
    tr.status(&wire)
    testing.expect_value(t, p.error, tape.Error.Operation)
    wire = tape.replay(&p, &log)
    tr.poll(&wire)
    tr.poll(&wire)
    testing.expect_value(t, p.error, tape.Error.Exhausted)
}

@(test)
decode_rejects_corruption_and_limits_without_replacing_existing_data :: proc(t: ^testing.T) {
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    tape.mark(&log, 1, 2, ([]u8{1, 2, 3}))
    encoded, e := tape.encode(&log)
    testing.expect_value(t, e, tape.Error.None)
    defer delete(encoded)
    destination: tape.Log
    tape.init(&destination)
    defer tape.destroy(&destination)
    tape.mark(&destination, 99, 100)

    for i in 0 ..< len(encoded) {
        saved := encoded[i]
        encoded[i] ~= 0x80
        err := tape.decode(&destination, encoded)
        testing.expect(t, err != .None)
        testing.expect_value(t, destination.entries[0].peer, u64(99))
        encoded[i] = saved
    }

    testing.expect_value(t, tape.decode(&destination, encoded, {1, 2}), tape.Error.Capacity)
    testing.expect_value(t, destination.entries[0].peer, u64(99))
}

@(test)
replay_checks_send_bytes_and_receive_capacity :: proc(t: ^testing.T) {
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    s := Source {
        packet = {1, 2, 3},
    }
    c: tape.Capture
    wire := tape.capture(&c, &log, source_wire(&s))
    data := [3]u8{1, 2, 3}
    tr.send(&wire, 7, .Unreliable, data[:])
    dst: [3]u8
    tr.receive(&wire, dst[:])
    player: tape.Replay
    wire = tape.replay(&player, &log)
    data[1] = 9
    tr.send(&wire, 7, .Unreliable, data[:])
    testing.expect_value(t, player.error, tape.Error.Arguments)
    wire = tape.replay(&player, &log)
    data[1] = 2
    tr.send(&wire, 7, .Unreliable, data[:])
    short: [2]u8
    tr.receive(&wire, short[:])
    testing.expect_value(t, player.error, tape.Error.Arguments)
}

@(test)
captured_bytes_are_owned_and_absent_generation_drops_raw_metadata :: proc(t: ^testing.T) {
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    original := tr.Transport {
        receive = proc(p: rawptr, dst: []u8) -> tr.Received {
            dst[0] = 42
            return {state = .Received, from = 1, count = 1, generation = 99}
        },
    }
    c: tape.Capture
    wire := tape.capture(&c, &log, original)
    dst: [1]u8
    r := tr.receive(&wire, dst[:])
    testing.expect_value(t, r.generation, u64(0))
    dst[0] = 7
    player: tape.Replay
    wire = tape.replay(&player, &log)
    r = tr.receive(&wire, dst[:])
    testing.expect_value(t, r.generation, u64(0))
    testing.expect_value(t, dst[0], u8(42))
    testing.expect(t, tape.finished(&player))
}

@(test)
forged_valid_digest_cannot_admit_oversized_receive_or_replace_destination :: proc(t: ^testing.T) {
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    source := Source {
        packet = {1, 2, 3},
    }
    capture: tape.Capture
    wire := tape.capture(&capture, &log, source_wire(&source))
    dst: [3]u8
    tr.receive(&wire, dst[:])
    data, e := tape.encode(&log)
    testing.expect_value(t, e, tape.Error.None)
    defer delete(data)
    hc, ec: sc.Schema
    sc.init(&hc, tape.Header)
    sc.init(&ec, tape.Entry)
    defer sc.destroy(&hc)
    defer sc.destroy(&ec)
    h: tape.Header
    entry: tape.Entry
    sc.decode(&hc, &h, data[:hc.wire_size])
    sc.decode(&ec, &entry, data[hc.wire_size:hc.wire_size + ec.wire_size])
    entry.count = 4
    sc.encode(&ec, entry, data[hc.wire_size:hc.wire_size + ec.wire_size])
    h.digest = sc.digest(data[:hc.wire_size - 8]) ~ sc.digest(data[hc.wire_size:])
    sc.encode(&hc, h, data[:hc.wire_size])
    kept: tape.Log
    tape.init(&kept)
    defer tape.destroy(&kept)
    tape.mark(&kept, 55, 66)
    testing.expect_value(t, tape.decode(&kept, data), tape.Error.Invalid)
    testing.expect_value(t, kept.entries[0].peer, u64(55))
}

Allocation_Gate :: struct {
    base: mem.Allocator,
    fail: bool,
}

gate_allocator :: proc(g: ^Allocation_Gate) -> mem.Allocator {
    return {
        data = g,
        procedure = proc(
            data: rawptr,
            mode: mem.Allocator_Mode,
            size, alignment: int,
            old: rawptr,
            old_size: int,
            location: runtime.Source_Code_Location,
        ) -> (
            []u8,
            mem.Allocator_Error,
        ) {
            gate := cast(^Allocation_Gate)data

            if gate.fail &&
               (mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed) {
                return nil, .Out_Of_Memory
            }

            return gate.base.procedure(gate.base.data, mode, size, alignment, old, old_size, location)
        },
    }
}

@(test)
allocation_failure_stops_recording_without_changing_transport_results :: proc(t: ^testing.T) {
    gate := Allocation_Gate {
        base = context.allocator,
    }
    log: tape.Log
    testing.expect(t, tape.init(&log, {2048, 65536}, gate_allocator(&gate)))
    defer tape.destroy(&log)
    source := Source{}
    capture: tape.Capture
    wire := tape.capture(&capture, &log, source_wire(&source))

    for _ in 0 ..< 1024 {
        tr.poll(&wire)
    }

    gate.fail = true
    tr.poll(&wire)
    testing.expect_value(t, log.error, tape.Error.Allocation)
    tr.poll(&wire)
    testing.expect_value(t, source.polls, 1026)
    testing.expect_value(t, len(log.entries), 1024)
}

@(test)
explicit_connectivity_and_pretagged_generation_round_trip_without_extra_queries :: proc(t: ^testing.T) {
    source := Source{}
    base := tr.Transport {
        user = &source,
        connected = proc(p: rawptr, id: tr.Peer_Id) -> bool {
            return id == 7
        },
        generation = proc(p: rawptr, id: tr.Peer_Id) -> u64 {
            (cast(^Source)p).generations += 1
            return 19
        },
        receive = proc(p: rawptr, dst: []u8) -> tr.Received {
            dst[0] = 8
            return {state = .Received, from = 7, count = 1, generation = 23}
        },
    }
    log: tape.Log
    tape.init(&log)
    defer tape.destroy(&log)
    capture: tape.Capture
    wire := tape.capture(&capture, &log, base)
    testing.expect(t, tr.peer_connected(&wire, 7) && !tr.peer_connected(&wire, 8))
    testing.expect_value(t, tr.peer_generation(&wire, 7), u64(19))
    dst: [1]u8
    packet := tr.receive(&wire, dst[:])
    testing.expect_value(t, packet.generation, u64(23))
    testing.expect_value(t, source.generations, 1)
    player: tape.Replay
    wire = tape.replay(&player, &log)
    testing.expect(t, tr.peer_connected(&wire, 7) && !tr.peer_connected(&wire, 8))
    testing.expect_value(t, tr.peer_generation(&wire, 7), u64(19))
    packet = tr.receive(&wire, dst[:])
    testing.expect_value(t, packet.generation, u64(23))
    testing.expect(t, tape.finished(&player))
    testing.expect_value(t, source.generations, 1)
}
