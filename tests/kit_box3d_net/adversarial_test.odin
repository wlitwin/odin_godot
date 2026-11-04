package kit_box3d_net_test

import "core:fmt"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

proposal :: proc(client: ^Box, tick: u64, axis: i32, epoch: u64 = 1, sequence: u64 = 0, driver: u8 = 2) {
    writer := s.session_app_begin(&client.ses, client.lane.tag)
    n.write_u8(writer, k.SIM_WORLD_INPUT)
    n.write_u32(writer, k.WORLD_NETWORK_REV)

    for byte in client.network.identity.input_schema {
        n.write_u8(writer, byte)
    }

    n.write_u64(writer, epoch)
    n.write_u64(writer, k.lane_world_protocol_status(&client.lane).bootstrap_sequence)
    n.write_u64(writer, tick)
    n.write_u64(writer, tick)
    n.write_u8(writer, 1)
    n.write_u8(writer, 2)
    n.write_u8(writer, driver)
    n.write_u8(writer, u8(k.World_Input_Origin.Submitted))
    n.write_u64(writer, sequence == 0 ? tick : sequence)
    control := Control{axis}
    wire: [4]u8
    assert(client.control.value.encode(&client.control, (cast([^]u8)&control)[:size_of(Control)], wire[:]) == .Ok)

    for byte in wire {
        n.write_u8(writer, byte)
    }

    n.write_u8(writer, 3)
    n.write_u8(writer, u8(k.World_Input_Origin.Submitted))
    n.write_u64(writer, tick)

    for _ in 0 ..< 8 {
        n.write_u8(writer, 0)
    }

    s.session_app_flush(&client.ses, s.HOST_PEER, .Stream)
}

send_wire :: proc(host, client: ^Box, wire: []u8, mode: k.World_Transfer_Mode, tick: u64) {
    sequence := host.lane.world.network.sequence + 1
    host.lane.world.network.sequence = sequence
    hash := bd.hash_bytes(wire)
    chunks := (len(wire) + k.WORLD_NETWORK_CHUNK - 1) / k.WORLD_NETWORK_CHUNK

    for index in 0 ..< chunks {
        writer := s.session_app_begin(&host.ses, host.lane.tag)
        n.write_u8(writer, k.SIM_WORLD_CHUNK)
        n.write_u32(writer, k.WORLD_NETWORK_REV)
        n.write_u8(writer, u8(mode))
        n.write_u64(writer, sequence)
        n.write_u64(writer, host.lane.world.network.epoch)
        n.write_u64(writer, tick)
        n.write_u32(writer, u32(len(wire)))
        n.write_u16(writer, u16(index))
        n.write_u16(writer, u16(chunks))

        for byte in hash {
            n.write_u8(writer, byte)
        }

        for byte in wire[index * k.WORLD_NETWORK_CHUNK:min(len(wire), (index + 1) * k.WORLD_NETWORK_CHUNK)] {
            n.write_u8(writer, byte)
        }

        s.session_app_flush(&host.ses, client.peer, .Reliable)
    }
}

resign :: proc(wire: []u8) -> bool {
    sig, e := bd.signature_decode(wire[:bd.SIGNATURE_BYTES])

    if e != .None {
        return false
    }

    r := n.reader_make(wire[bd.SIGNATURE_BYTES:])
    recovery_size := int(n.read_u32(&r))
    parts: [bd.Part][]u8
    at := bd.SIGNATURE_BYTES + 4 + recovery_size

    for part in bd.Part {
        parts[part] = wire[at:at + int(sig.lengths[part])]
        at += int(sig.lengths[part])
    }

    sig, e = bd.sign({sig.identity, sig.epoch, sig.tick, parts})

    if e != .None {
        return false
    }

    _, e = bd.signature_encode(sig, wire[:bd.SIGNATURE_BYTES])
    return e == .None
}

@(test)
source_epoch_sequence_duplicate_conflict_and_bounds_precede_effects :: proc(t: ^testing.T) {
    host, client: Box
    start_pair(&host, &client)
    cat := catalog()
    defer b.recovery_catalog_destroy(&cat)
    setup(&host, 3, &cat)
    setup(&client, 3, &cat)
    defer destroy(&host)
    defer destroy(&client)
    bootstrap(t, &host, &client)
    baseline, be := k.lane_world_checkpoint(&host.lane, 0)
    testing.expect_value(t, be, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&baseline)
    proposal(&client, 1, 1)
    proposal(&client, 1, 1)
    proposal(&client, 1, 2) // duplicate then equivocation
    proposal(&client, 2, 1, driver = 0) // client cannot drive authority's class
    proposal(&client, 2, 1, epoch = 2)
    proposal(&client, 2, 1, sequence = 99)
    proposal(&client, 9, 1)
    proposal(&client, 2, 99)
    pump({&host, &client})
    _ = k.lane_frame(&host.lane, 0)
    status := k.lane_world_network_status(&host.lane)
    testing.expect(t, status.rejected >= 5)
    testing.expect(t, status.conflicts >= 1)
    testing.expect(t, status.duplicates >= 1)
    testing.expect(t, !status.needs_resync)
    current, ce := k.lane_world_checkpoint(&host.lane, 0)
    testing.expect_value(t, ce, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&current)
    same, e := k.world_checkpoint_equal(&baseline, &current)
    testing.expect_value(t, e, k.World_Error.Ok)
    testing.expect(t, same)
    testing.expect_value(t, host.effects, 0)
    testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)
    accepted, origin, _, ae := k.lane_world_accepted_input(&host.lane, 1, 2, 0)
    testing.expect_value(t, ae, k.World_Error.Ok)
    testing.expect_value(t, origin, k.World_Input_Origin.Submitted)
    testing.expect_value(t, (cast(^Control)raw_data(accepted)).axis, i32(1))
    prior := k.lane_world_network_status(&host.lane).rejected

    for _ in 0 ..< 20 {
        proposal(&client, 2, 0)
    }

    pump({&host, &client})
    _ = k.lane_frame(&host.lane, 0)
    testing.expect(t, k.lane_world_network_status(&host.lane).rejected > prior)
    testing.expect(t, !k.lane_world_needs_resync(&host.lane))
}

@(test)
settled_complete_conflict_stops_with_owned_first_divergence :: proc(t: ^testing.T) {
    host, client: Box
    start_pair(&host, &client)
    cat := catalog()
    defer b.recovery_catalog_destroy(&cat)
    setup(&host, 3, &cat)
    setup(&client, 3, &cat)
    defer destroy(&host)
    defer destroy(&client)
    bootstrap(t, &host, &client)
    wire, e := k.lane_world_export(&host.lane, 0)
    testing.expect_value(t, e, k.World_Error.Ok)
    defer delete(wire)
    sig, se := bd.signature_decode(wire[:bd.SIGNATURE_BYTES])
    testing.expect_value(t, se, bd.Error.None)
    r := n.reader_make(wire[bd.SIGNATURE_BYTES:])
    recovery_size := int(n.read_u32(&r))
    at := bd.SIGNATURE_BYTES + 4 + recovery_size + int(sig.lengths[.Solver]) + 12 // Game count/id/len then Proxy position.x
    wire[at] = 0
    wire[at + 1] = 0
    wire[at + 2] = 128
    wire[at + 3] = 63
    testing.expect(t, resign(wire))
    before, be := k.lane_world_checkpoint(&client.lane, 0)
    testing.expect_value(t, be, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&before)
    fields, fx := client.proxies, client.effects
    send_wire(&host, &client, wire, .Correction, 0)
    pump({&host, &client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_network_status(&client.lane).error, k.World_Error.Conflict)
    after, ae := k.lane_world_checkpoint(&client.lane, 0)
    testing.expect_value(t, ae, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&after)
    same, ee := k.world_checkpoint_equal(&before, &after)
    testing.expect_value(t, ee, k.World_Error.Ok)
    testing.expect(t, same)
    testing.expect_value(t, fields, client.proxies)
    testing.expect_value(t, fx, client.effects)
    trace := k.lane_world_network_trace(&client.lane)
    testing.expect(t, trace != nil && trace.ready)
    testing.expect_value(t, trace.difference, bd.Difference.Game)
    required, te := bd.trace_encode(trace, nil)
    testing.expect_value(t, te, bd.Error.None)
    artifact := make([]u8, required)
    defer delete(artifact)
    _, te = bd.trace_encode(trace, artifact)
    testing.expect_value(t, te, bd.Error.None)
    TRACE_PATH :: #config(KIT_NETWORK_TRACE_PATH, "")

    when len(TRACE_PATH) > 0 {
        testing.expect(t, os.write_entire_file(TRACE_PATH, artifact) == nil)
    }

    fmt.printf(
        "KIT_NETWORK_TRACE difference=Game bytes=%d first_byte=%d accepted_bytes=%d predicted_bytes=%d same_accepted_history=1 classification=confirmed_conflict\n",
        required,
        trace.first_byte,
        len(trace.input_context.accepted_inputs),
        len(trace.input_context.predicted_inputs),
    )
    first := trace.expected.complete
    send_wire(&host, &client, wire, .Correction, 0)
    pump({&host, &client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, trace.expected.complete, first)
    // Explicit server epoch is the separate recovery boundary. Older settled
    // truth never rewrites the current epoch and local forged resets are refused.
    testing.expect_value(t, k.lane_world_reset(&client.lane, &before).error, k.World_Error.Rejected)
    // A newer authoritative epoch may retire an incomplete old assembly.
    partial := make([]u8, k.WORLD_NETWORK_CHUNK + 1)
    send_wire(&host, &client, partial, .Correction, 0)
    delete(partial)
    last := len(host.out) - 1
    delete(host.out[last].bytes)
    ordered_remove(&host.out, last)
    pump({&host, &client})
    testing.expect(t, len(client.lane.world.network.transfer) > 0)
    testing.expect_value(t, k.lane_world_begin_epoch(&host.lane, 2), k.World_Error.Ok)
    testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Reset), k.World_Error.Ok)
    pump({&host, &client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_network_status(&client.lane).epoch, u64(2))
    testing.expect(t, !k.lane_world_needs_resync(&client.lane))
    send_wire(&host, &client, wire, .Correction, 0)
    pump({&host, &client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_network_status(&client.lane).epoch, u64(2))
}

@(test)
normalized_diagnostic_bytes_are_never_a_native_import_attachment :: proc(t: ^testing.T) {
    host, client: Box
    start_pair(&host, &client)
    cat := catalog()
    defer b.recovery_catalog_destroy(&cat)
    setup(&host, 3, &cat)
    setup(&client, 3, &cat)
    defer destroy(&host)
    defer destroy(&client)
    bootstrap(t, &host, &client)
    wire, e := k.lane_world_export(&host.lane, 0)
    testing.expect_value(t, e, k.World_Error.Ok)
    defer delete(wire)
    sig, se := bd.signature_decode(wire[:bd.SIGNATURE_BYTES])
    testing.expect_value(t, se, bd.Error.None)
    r := n.reader_make(wire[bd.SIGNATURE_BYTES:])
    recovery_size := int(n.read_u32(&r))
    // Corrupt only the signed logical dump, leaving the independently validated
    // native canonical recovery attachment intact. No logical byte is imported.
    at := bd.SIGNATURE_BYTES + 4 + recovery_size + int(sig.lengths[.Solver]) - 1
    wire[at] ~= 1
    testing.expect(t, resign(wire))
    before, be := k.lane_world_checkpoint(&client.lane, 0)
    testing.expect_value(t, be, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&before)
    fields, fx := client.proxies, client.effects
    testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
    // Discard request: inject the controlled, authoritative malformed response.
    discard(&client)
    send_wire(&host, &client, wire, .Reset, 0)
    pump({&host, &client})
    _ = k.lane_frame(&client.lane, 0)
    testing.expect_value(t, k.lane_world_network_status(&client.lane).error, k.World_Error.Incompatible)
    after, ae := k.lane_world_checkpoint(&client.lane, 0)
    testing.expect_value(t, ae, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&after)
    same, ee := k.world_checkpoint_equal(&before, &after)
    testing.expect_value(t, ee, k.World_Error.Ok)
    testing.expect(t, same)
    testing.expect_value(t, fields, client.proxies)
    testing.expect_value(t, fx, client.effects)
    testing.expect(t, !k.lane_world_network_trace(&client.lane).ready)
    // A legacy pose/entity snapshot is never a complete physics attachment.
    writer := s.session_app_begin(&host.ses, host.lane.tag)
    n.write_u8(writer, k.SIM_SNAP)
    s.session_app_flush(&host.ses, client.peer)
    pump({&host, &client})
    testing.expect_value(t, k.lane_world_network_status(&client.lane).error, k.World_Error.Missing_Attachment)
}
