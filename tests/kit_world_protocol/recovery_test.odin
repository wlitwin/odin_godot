package kit_world_protocol_test

import "core:testing"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"

@(test)
valid_mismatching_signature_is_atomic_and_public_reset_preserves_effects :: proc(t: ^testing.T) {
    pair: Pair
    open_pair(t, &pair)
    defer close_pair(t, &pair)
    pair.client.action_at = 1
    pair.client.action_kind = 1
    prior := advance_pair_to(t, &pair, 6)
    destroy_packets(&prior)
    expect_parts(t, &pair, 6)
    expect_known_effect_prefix(t, &pair, 6)
    held := hold_final_signature(t, &pair, 9)
    defer destroy_packets(&held)

    if len(held) != 1 {
        return
    }

    frame: k.World_Diagnostic_Frame
    err := k.lane_world_diagnostic_frame(&pair.host.lane, 9, &frame)
    testing.expect_value(t, err, k.World_Error.Ok)

    if err != .Ok {
        return
    }

    defer k.world_diagnostic_frame_destroy(&frame)
    original, de := bd.signature_decode(held[0].bytes[7:])
    testing.expect_value(t, de, bd.Error.None)
    testing.expect_value(t, bd.compare(original, frame.signature), bd.Difference.Match)
    // Deliberately claim a different public canonical Side, using the actual
    // signature codec. No World image, head, accepted row or flag is assigned.
    view := frame.view
    changed := make([]u8, len(view.parts[.Side]))
    defer delete(changed)

    if len(changed) == 0 {
        testing.expect(t, false)
        return
    }

    copy(changed, view.parts[.Side])
    changed[0] ~= 1
    view.parts[.Side] = changed
    wrong, we := bd.sign(view)
    testing.expect_value(t, we, bd.Error.None)

    if we != .None {
        return
    }

    testing.expect_value(t, bd.compare(original, wrong), bd.Difference.Side)
    bad := clone_packet(held[0])
    defer delete(bad.bytes)
    _, encode_error := bd.signature_encode(wrong, bad.bytes[7:])
    testing.expect_value(t, encode_error, bd.Error.None)

    if encode_error != .None {
        return
    }

    before := k.lane_world_protocol_status(&pair.client.lane)
    deliver(&pair.client, pair.host.peer, bad)
    _ = k.lane_frame(&pair.client.lane, 0)
    testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(6))
    testing.expect_value(t, k.lane_world_protocol_status(&pair.client.lane).matched_signature_tick, u64(6))
    testing.expect(t, k.lane_world_needs_resync(&pair.client.lane))
    testing.expect_value(t, pair.client.effects, 2)
    expect_parts(t, &pair, 6)
    public_reset(t, &pair)
    testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(9))
    testing.expect(t, k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence > before.bootstrap_sequence)
    expect_parts(t, &pair, 9)
    testing.expect_value(t, pair.client.effects, 2)
    future := advance_pair_to(t, &pair, 12)
    defer destroy_packets(&future)
    expect_parts(t, &pair, 12)
    expect_known_effect_prefix(t, &pair, 12)
}

@(test)
old_scope_feedback_and_old_epoch_packets_cannot_reactivate_timing :: proc(t: ^testing.T) {
    pair: Pair
    open_pair(t, &pair)
    defer close_pair(t, &pair)
    pair.client.action_at = 1
    pair.client.action_kind = 1
    old := advance_pair_to(t, &pair, 3)
    defer destroy_packets(&old)
    initial := k.lane_world_protocol_status(&pair.client.lane)
    testing.expect(t, initial.receipt_available)
    public_reset(t, &pair) // same epoch, different actual bootstrap scope
    reset := k.lane_world_protocol_status(&pair.client.lane)
    testing.expect(t, reset.bootstrap_sequence > initial.bootstrap_sequence)
    testing.expect(t, !reset.receipt_available)
    deliver_all(&pair.client, pair.host.peer, old[:])
    _ = k.lane_frame(&pair.client.lane, 0)
    after := k.lane_world_protocol_status(&pair.client.lane)
    testing.expect_value(t, after.bootstrap_sequence, reset.bootstrap_sequence)
    testing.expect_value(t, after.accepted_through, reset.accepted_through)
    testing.expect_value(t, after.scale, reset.scale)
    testing.expect(t, !after.receipt_available)
    testing.expect_value(t, pair.client.effects, 1)
    testing.expect_value(t, k.lane_world_begin_epoch(&pair.host.lane, 2), k.World_Error.Ok)
    testing.expect_value(t, k.lane_world_send_checkpoint(&pair.host.lane, pair.client.peer, .Reset), k.World_Error.Ok)
    f.pump({&pair.host, &pair.client})
    _ = k.lane_frame(&pair.client.lane, 0)
    current := k.lane_world_protocol_status(&pair.client.lane)
    testing.expect_value(t, k.lane_world_network_status(&pair.client.lane).epoch, u64(2))
    deliver_all(&pair.client, pair.host.peer, old[:])
    _ = k.lane_frame(&pair.client.lane, 0)
    after = k.lane_world_protocol_status(&pair.client.lane)
    testing.expect(t, !after.receipt_available)
    testing.expect_value(t, after.bootstrap_sequence, current.bootstrap_sequence)
    testing.expect_value(t, after.accepted_through, current.accepted_through)
    testing.expect_value(t, after.scale, current.scale)
    expect_parts(t, &pair, 3)
    testing.expect_value(t, pair.client.effects, 1)
    future := advance_pair_to(t, &pair, 6)
    defer destroy_packets(&future)
    expect_parts(t, &pair, 6)
    expect_known_effect_prefix(t, &pair, 6)
    testing.expect(t, k.lane_world_protocol_status(&pair.client.lane).receipt_available)
}
