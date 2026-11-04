// Generic four-body public admission diagnostic, NOT SDK/32-body acceptance.
package kit_input_admission_test

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import f "godot:tests/kit_box3d_net"

Row :: struct {
    tick, sequence: u64,
    player:         u16,
    class:          u16,
    origin:         k.World_Input_Origin,
    value:          f.Action,
    status:         k.World_Error,
}

Receipt :: struct {
    last_action, births:                u32,
    extra_alive:                        bool,
    occurrence_count, callback_effects: int,
}

Scope :: struct {
    tag, kind:                                  u8,
    channel:                                    s.Channel,
    revision:                                   u32,
    schema:                                     bd.Digest,
    epoch, packet_head, first, source_sequence: u64,
    count, entries:                             int,
    player:                                     n.Player_Id,
    class:                                      u16,
    origin:                                     k.World_Input_Origin,
    action:                                     f.Action,
}

Arm :: struct {
    name:                                                                       string,
    scope:                                                                      Scope,
    packet_sha256:                                                              bd.Digest,
    authority_before, authority_after, client_accepted:                         Row,
    authority_receipt, client_receipt:                                          Receipt,
    fullparts_equal, signature_equal, ready, no_resync:                         bool,
    native_live, wrapper_live, provider_live, checkpoint_live, diagnostic_live: u64,
}

emit :: proc(value: $T) {
    bytes, error := json.marshal(value)
    assert(error == nil)
    fmt.printf("KIT_INPUT_ADMISSION %s\n", string(bytes))
    delete(bytes)
}

write :: proc(name: string, bytes: []u8) {
    assert(os.write_entire_file(name, bytes) == nil)
}

named_write :: proc(arm, owner, suffix: string, bytes: []u8) {
    name := fmt.aprintf("%s.%s.%s", arm, owner, suffix)
    defer delete(name)
    write(name, bytes)
}

is_input :: proc(parcel: f.Parcel) -> bool {
    return len(parcel.bytes) > 2 && parcel.bytes[0] == s.SES_APP && parcel.bytes[2] == k.SIM_WORLD_INPUT
}

take_input :: proc(box: ^f.Box) -> f.Parcel {
    found := -1

    for parcel, i in box.out {
        if is_input(parcel) {
            assert(found < 0)
            found = i
        }
    }

    assert(found >= 0)
    packet := box.out[found]
    ordered_remove(&box.out, found)
    return packet
}

deliver :: proc(t: ^testing.T, from, to: ^f.Box, parcel: f.Parcel) {
    hash := bd.hash_bytes(parcel.bytes)
    reader := n.reader_make(parcel.bytes)
    s.session_handle_packet(&to.ses, from.peer, &reader, parcel.channel)
    testing.expect(t, !reader.err)
    testing.expect_value(t, bd.hash_bytes(parcel.bytes), hash)
}

drain :: proc(t: ^testing.T, from, to: ^f.Box) {
    for parcel in from.out {
        deliver(t, from, to, parcel)
        delete(parcel.bytes)
    }

    clear(&from.out)
}

scope :: proc(box: ^f.Box, parcel: f.Parcel) -> (result: Scope) {
    reader := n.reader_make(parcel.bytes)
    assert(n.read_u8(&reader) == s.SES_APP)
    result.tag = n.read_u8(&reader)
    result.kind = n.read_u8(&reader)
    result.channel = parcel.channel
    result.revision = n.read_u32(&reader)
    copy(result.schema[:], n.reader_view(&reader, 32))
    result.epoch = n.read_u64(&reader)
    result.packet_head = n.read_u64(&reader)
    result.first = n.read_u64(&reader)
    result.count = int(n.read_u8(&reader))
    result.entries = int(n.read_u8(&reader))
    assert(result.count == 1 && result.entries == 2)

    for _ in 0 ..< result.entries {
        driver := int(n.read_u8(&reader))
        origin := k.World_Input_Origin(n.read_u8(&reader))
        sequence := n.read_u64(&reader)
        assert(driver < len(box.lane.world.network.drivers))
        declared := box.lane.world.network.drivers[driver]

        if declared.class == 0 {
            blob := n.reader_view(&reader, box.control.value.wire_bytes)
            value: f.Control
            assert(box.control.value.decode(box.control.value.user, blob, (cast([^]u8)&value)[:size_of(value)]) == .Ok)
            assert(value.axis == 0)
        } else {
            assert(declared.class == 1)
            blob := n.reader_view(&reader, box.action.value.wire_bytes)
            assert(
                box.action.value.decode(
                    box.action.value.user,
                    blob,
                    (cast([^]u8)&result.action)[:size_of(result.action)],
                ) ==
                .Ok,
            )
            result.player = declared.player
            result.class = declared.class
            result.origin = origin
            result.source_sequence = sequence
        }
    }

    assert(!reader.err && len(n.reader_remaining(&reader)) == 0)
    return
}

row :: proc(box: ^f.Box) -> (result: Row) {
    result.tick = 1
    result.player = 2
    result.class = 1
    bytes, origin, sequence, error := k.lane_world_accepted_input(&box.lane, 1, 2, 1)
    result.origin = origin
    result.sequence = sequence
    result.status = error

    if error == .Ok {
        assert(len(bytes) == size_of(f.Action))
        copy((cast([^]u8)&result.value)[:size_of(result.value)], bytes)
    }

    return
}

receipt :: proc(t: ^testing.T, box: ^f.Box) -> Receipt {
    checkpoint, error := k.lane_world_checkpoint(&box.lane, 1)
    testing.expect_value(t, error, k.World_Error.Ok)
    defer k.world_checkpoint_destroy(&checkpoint)
    side, se := p.checkpoint_side(&checkpoint, f.Side)
    testing.expect_value(t, se, k.World_Error.Ok)
    return {side.last_action[1], side.births, side.alive[side.initial], checkpoint.effect_count, box.effects}
}

compare :: proc(t: ^testing.T, name: string, host, client: ^f.Box) -> (parts_equal, signature_equal: bool) {
    a, c: k.World_Diagnostic_Frame
    testing.expect_value(t, k.lane_world_diagnostic_frame(&host.lane, 1, &a), k.World_Error.Ok)
    testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 1, &c), k.World_Error.Ok)
    defer k.world_diagnostic_frame_destroy(&a)
    defer k.world_diagnostic_frame_destroy(&c)
    signature_equal = bd.compare(a.signature, c.signature) == .Match
    parts_equal = true

    for part in bd.Part {
        parts_equal = parts_equal && mem.compare(a.view.parts[part], c.view.parts[part]) == 0
        suffix := fmt.aprintf("part%d.bin", int(part))
        named_write(name, "authority", suffix, a.view.parts[part])
        named_write(name, "client", suffix, c.view.parts[part])
        delete(suffix)
    }

    testing.expect(t, parts_equal && signature_equal)
    return
}

run_arm :: proc(t: ^testing.T, late: bool) -> (result: Arm, packet_copy: []u8) {
    result.name = late ? "settled_late" : "timely"
    host, client: f.Box
    f.start_pair(&host, &client)
    cat := f.catalog()
    f.setup(&host, 4, &cat)
    f.setup(&client, 4, &cat)
    f.bootstrap(t, &host, &client)
    client.action_at = 1
    client.action_kind = 1

    if late {
        testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)
        result.authority_before = row(&host)

        // Forward authority's actual accepted Stream. No checkpoint is due at1.
        for parcel in host.out {
            assert(len(parcel.bytes) < 3 || parcel.bytes[2] != k.SIM_WORLD_CHUNK)
        }

        drain(t, &host, &client)
        testing.expect_value(t, k.lane_frame(&client.lane, 0), 0)
    }

    testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
    packet := take_input(&client)
    result.scope = scope(&client, packet)
    result.packet_sha256 = bd.hash_bytes(packet.bytes)
    packet_copy = make([]u8, len(packet.bytes))
    copy(packet_copy, packet.bytes)
    named_write(result.name, "client", "input.bin", packet.bytes)
    testing.expect_value(t, result.scope.action, f.Action{1, 1})
    testing.expect_value(t, result.scope.player, n.Player_Id(2))
    testing.expect_value(t, result.scope.class, u16(1))
    testing.expect_value(t, result.scope.channel, s.Channel.Stream)
    testing.expect_value(t, result.scope.kind, k.SIM_WORLD_INPUT)
    testing.expect_value(t, result.scope.epoch, u64(1))
    testing.expect_value(t, result.scope.first, u64(1))
    testing.expect_value(t, result.scope.packet_head, u64(1))
    testing.expect_value(t, result.scope.source_sequence, u64(1))
    testing.expect_value(t, result.scope.origin, k.World_Input_Origin.Submitted)
    deliver(t, &client, &host, packet)
    delete(packet.bytes)
    testing.expect_value(t, k.lane_frame(&host.lane, 0), 0)

    if !late {
        testing.expect_value(t, k.lane_frame(&host.lane, 1.0 / 60), 1)
    }

    result.authority_after = row(&host)

    if late {
        testing.expect_value(t, result.authority_after, result.authority_before)
        testing.expect_value(t, result.authority_after.value, f.Action{})
        testing.expect_value(t, result.authority_after.origin, k.World_Input_Origin.Held)
        testing.expect_value(t, result.authority_after.sequence, u64(0))
    } else {
        testing.expect_value(t, result.authority_after.value, f.Action{1, 1})
        testing.expect_value(t, result.authority_after.origin, k.World_Input_Origin.Submitted)
        testing.expect_value(t, result.authority_after.sequence, u64(1))
    }

    testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction), k.World_Error.Ok)
    drain(t, &host, &client)
    testing.expect_value(t, k.lane_frame(&client.lane, 0), 0)
    result.client_accepted = row(&client)
    testing.expect_value(t, result.client_accepted, result.authority_after)
    result.authority_receipt = receipt(t, &host)
    result.client_receipt = receipt(t, &client)
    testing.expect_value(t, result.authority_receipt, result.client_receipt)
    testing.expect_value(t, result.authority_receipt.last_action, late ? u32(0) : u32(1))
    testing.expect_value(t, result.authority_receipt.births, late ? u32(0) : u32(1))
    testing.expect_value(t, result.authority_receipt.extra_alive, !late)
    testing.expect_value(t, result.authority_receipt.callback_effects, late ? 0 : 1)
    testing.expect_value(t, result.authority_receipt.occurrence_count, late ? 0 : 1)
    result.fullparts_equal, result.signature_equal = compare(t, result.name, &host, &client)
    status := k.lane_world_network_status(&client.lane)
    result.ready = status.ready
    result.no_resync = !status.needs_resync
    testing.expect(
        t,
        status.ready && !status.needs_resync && status.epoch == 1 && status.head == 1 && status.confirmed == 1,
    )
    f.destroy(&client)
    f.destroy(&host)
    testing.expect_value(t, b.recovery_catalog_destroy(&cat), b.Status.Ok)
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    testing.expect_value(t, es, b.Status.Ok)
    testing.expect_value(t, ws, b.Status.Ok)
    result.native_live = engine.live_bytes
    result.wrapper_live = wrapper.live_bytes
    result.provider_live = p.owned_bytes()
    result.checkpoint_live = k.world_checkpoint_owned_bytes()
    result.diagnostic_live = k.world_diagnostic_frame_owned_bytes()
    testing.expect(
        t,
        result.native_live == 0 &&
        result.wrapper_live == 0 &&
        result.provider_live == 0 &&
        result.checkpoint_live == 0 &&
        result.diagnostic_live == 0,
    )
    emit(result)
    return
}

@(test)
same_real_spawn_packet_timely_admitted_or_settled_late_ignored :: proc(t: ^testing.T) {
    // This is an in-memory owned Parcel queue, not ENet/actualCore or a second runtime.
    emit(struct {
        schema: u32,
        scope:  string,
        bodies: u32,
        action: string,
    }{1, "generic4_static_native9c66_nil_owner_public_Session_Lane_memory_queue_no_timing", 4, "Spawn(kind1,serial1)"})
    tracking: mem.Tracking_Allocator
    backing := context.allocator
    mem.tracking_allocator_init(&tracking, backing, backing)
    context.allocator = mem.tracking_allocator(&tracking)
    a, early := run_arm(t, false)
    c, late := run_arm(t, true)
    identical := mem.compare(early, late) == 0 && a.packet_sha256 == c.packet_sha256 && a.scope == c.scope
    testing.expect(t, identical)
    delete(early)
    delete(late)
    live := tracking.current_memory_allocated
    testing.expect(t, live == 0)
    context.allocator = backing
    mem.tracking_allocator_destroy(&tracking)
    emit(struct {
        identical_packets: bool,
        odin_live:         i64,
    }{identical, i64(live)})
}
