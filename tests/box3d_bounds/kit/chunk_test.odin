package kit_bounds_test

import "core:testing"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"
import wp "godot:tests/kit_world_protocol"

CHUNK_TOTAL :: 32
CHUNK_INDEX :: 36
CHUNK_COUNT :: 38
CHUNK_BODY :: 72

overwrite_u16 :: proc(bytes: []u8, offset: int, value: u16) {
    bytes[offset] = u8(value)
    bytes[offset + 1] = u8(value >> 8)
}

@(test)
reset_chunks_reject_foreign_oversize_index_and_conflicting_duplicate_then_resume :: proc(t: ^testing.T) {
    // Same existing public fixture, with its supported dense32 Native world so
    // the actual encoder must emit multiple chunks. No test packet assembler.
    pair: wp.Pair
    pair.before = wp.usage(t)
    pair.catalog = f.catalog()
    f.start_pair(&pair.host, &pair.client)
    f.setup(&pair.host, 32, &pair.catalog)
    f.setup(&pair.client, 32, &pair.catalog)
    defer wp.close_pair(t, &pair)
    f.bootstrap(t, &pair.host, &pair.client)
    before: k.World_Diagnostic_Frame

    if !saved_frame(t, &pair.client, 0, &before) {
        return
    }

    defer k.world_diagnostic_frame_destroy(&before)
    testing.expect_value(t, k.lane_world_request_reset(&pair.client.lane), k.World_Error.Ok)
    request := wp.take_packets(&pair.client)
    wp.deliver_all(&pair.host, pair.client.peer, request[:])
    wp.destroy_packets(&request)
    _ = k.lane_frame(&pair.host.lane, 0)
    response := wp.take_packets(&pair.host)
    defer wp.destroy_packets(&response)
    testing.expect(t, wp.count_kind(response[:], k.SIM_WORLD_CHUNK) > 1)
    first: f.Parcel

    for packet in response {
        kind, ok := wp.app_kind(packet)

        if ok && kind == k.SIM_WORLD_CHUNK {
            first = packet
            break
        }
    }

    if len(first.bytes) <= CHUNK_BODY {
        testing.expect(t, false)
        return
    }

    testing.expect(t, first.bytes[CHUNK_COUNT] > 1)
    owned := k.lane_world_owned_bytes(&pair.client.lane)
    // Genuine packet from a non-authority transport peer must not start assembly.
    wp.deliver(&pair.client, pair.client.peer, first)
    _ = k.lane_frame(&pair.client.lane, 0)
    testing.expect_value(t, k.lane_world_owned_bytes(&pair.client.lane), owned)
    expect_saved_frame(t, &pair.client, &before)

    for variant in 0 ..< 2 {
        bad := wp.clone_packet(first)

        if variant == 0 {
            overwrite_u32(bad.bytes, CHUNK_TOTAL, u32(k.WORLD_NETWORK_BYTES) + 1)
        } else {
            // Actual encoded count is bounded <=32, so its low byte is exact.
            overwrite_u16(bad.bytes, CHUNK_INDEX, u16(first.bytes[CHUNK_COUNT]))
        }

        status := k.lane_world_network_status(&pair.client.lane)
        wp.deliver(&pair.client, pair.host.peer, bad)
        delete(bad.bytes)
        _ = k.lane_frame(&pair.client.lane, 0)
        testing.expect(t, k.lane_world_network_status(&pair.client.lane).rejected > status.rejected)
        testing.expect_value(t, k.lane_world_owned_bytes(&pair.client.lane), owned)
        expect_saved_frame(t, &pair.client, &before)
    }

    wp.deliver(&pair.client, pair.host.peer, first)
    prefix_owned := k.lane_world_owned_bytes(&pair.client.lane)
    testing.expect(t, prefix_owned > owned && prefix_owned - owned <= u64(k.WORLD_NETWORK_BYTES))
    status := k.lane_world_network_status(&pair.client.lane)
    wp.deliver(&pair.client, pair.host.peer, first) // byte-exact duplicate
    testing.expect(t, k.lane_world_network_status(&pair.client.lane).duplicates > status.duplicates)
    testing.expect_value(t, k.lane_world_owned_bytes(&pair.client.lane), prefix_owned)
    conflict := wp.clone_packet(first)
    conflict.bytes[CHUNK_BODY] ~= 1
    wp.deliver(&pair.client, pair.host.peer, conflict)
    delete(conflict.bytes)
    _ = k.lane_frame(&pair.client.lane, 0)
    testing.expect(t, k.lane_world_network_status(&pair.client.lane).rejected > status.rejected)
    testing.expect(t, k.lane_world_owned_bytes(&pair.client.lane) <= prefix_owned)
    testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(0))
    testing.expect_value(t, pair.client.effects, 0)
    expect_saved_frame(t, &pair.client, &before)
    // Conflict may discard the owned prefix. Re-deliver the COMPLETE unchanged
    // real Reset, rather than assuming any damaged assembly survived.
    wp.deliver_all(&pair.client, pair.host.peer, response[:])
    _ = k.lane_frame(&pair.client.lane, 0)
    testing.expect(t, k.lane_world_network_status(&pair.client.lane).ready)
    testing.expect(t, !k.lane_world_needs_resync(&pair.client.lane))
    wp.expect_parts(t, &pair, 0)
    pair.client.axis = 1
    future := wp.advance_pair_to(t, &pair, 6)
    defer wp.destroy_packets(&future)
    wp.expect_parts(t, &pair, 6)
    testing.expect_value(t, pair.host.effects, 1)
    testing.expect_value(t, pair.client.effects, 1)
    testing.expect(t, k.lane_world_owned_bytes(&pair.client.lane) < k.WORLD_MEMORY_BYTES)
}
