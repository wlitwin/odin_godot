package kit_world_protocol_test

import "core:testing"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"

expect_tick1_still_held :: proc(t: ^testing.T, pair: ^Pair) {
	bytes, origin, source, err := k.lane_world_accepted_input(&pair.host.lane, 1, 2, 0)
	testing.expect_value(t, err, k.World_Error.Ok)
	if err != .Ok {return}
	testing.expect_value(t, origin, k.World_Input_Origin.Held)
	testing.expect_value(t, source, u64(0))
	testing.expect_value(t, (cast(^f.Control)raw_data(bytes)).axis, i32(0))
}

@(test)
late_class0_receipt_is_not_admission_and_feedback_validation_is_atomic :: proc(t: ^testing.T) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.client.axis = 1
	if !advance_one(t, &pair.client) {return}
	proposal1 := take_packets(&pair.client)
	defer destroy_packets(&proposal1)
	if !advance_one(t, &pair.client) {return}
	proposal2 := take_packets(&pair.client)
	defer destroy_packets(&proposal2)
	testing.expect(t, count_kind(proposal1[:], k.SIM_WORLD_INPUT) > 0)
	testing.expect(t, count_kind(proposal2[:], k.SIM_WORLD_INPUT) > 0)
	// Actual client proposals are held by the memory transport. Authority tick1
	// therefore accepts Held zero; a later valid receipt must not rewrite it.
	if !advance_one(t, &pair.host) {return}
	old_feedback := take_packets(&pair.host)
	defer destroy_packets(&old_feedback)
	expect_tick1_still_held(t, &pair)
	deliver_all(&pair.host, pair.client.peer, proposal1[:])
	_ = k.lane_frame(&pair.host.lane, 0)
	if !advance_one(t, &pair.host) {return}
	feedback := take_packets(&pair.host)
	defer destroy_packets(&feedback)
	deliver_all(&pair.client, pair.host.peer, old_feedback[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	deliver_all(&pair.client, pair.host.peer, feedback[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	received := k.lane_world_protocol_status(&pair.client.lane)
	testing.expect(t, received.receipt_available)
	testing.expect_value(t, received.receipt_player, pair.client.ses.me)
	testing.expect_value(t, received.receipt_proposal_tick, u64(1))
	testing.expect_value(t, received.receipt_authority_tick, u64(2))
	testing.expect_value(t, received.accepted_through, u64(2))
	testing.expect(t, received.scale >= 0.98 && received.scale <= 1.02)
	expect_tick1_still_held(t, &pair)
	// An older real feedback packet (authority tick1, before receipt1) cannot
	// clear/replace the newer receipt or drive the current scale.
	deliver_all(&pair.client, pair.host.peer, old_feedback[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	stale := k.lane_world_protocol_status(&pair.client.lane)
	testing.expect(t, stale.receipt_available)
	testing.expect_value(t, stale.receipt_proposal_tick, received.receipt_proposal_tick)
	testing.expect_value(t, stale.receipt_authority_tick, received.receipt_authority_tick)
	testing.expect_value(t, stale.scale, received.scale)
	// Now obtain genuinely newer feedback from the authority after actual late
	// proposal2. Corrupt only its trailing boundary; neither rows nor feedback
	// may publish before the whole message is accepted.
	deliver_all(&pair.host, pair.client.peer, proposal2[:])
	_ = k.lane_frame(&pair.host.lane, 0)
	if !advance_one(t, &pair.host) {return}
	newer := take_packets(&pair.host)
	defer destroy_packets(&newer)
	expect_small_normal(t, newer[:])
	found := false
	for parcel in newer {
		kind, ok := app_kind(parcel)
		if !ok || kind != k.SIM_WORLD_ACCEPTED {continue}
		r := packet_receipt(t, parcel, u64(pair.client.ses.me))
		if !r.found || !r.available || r.tick != 2 {continue}
		testing.expect_value(t, r.bootstrap, received.bootstrap_sequence)
		bad := parcel
		bad.bytes = make([]u8, len(parcel.bytes) + 1)
		copy(bad.bytes, parcel.bytes)
		bad.bytes[len(parcel.bytes)] = 0xa5
		deliver(&pair.client, pair.host.peer, bad)
		delete(bad.bytes)
		found = true
	}
	testing.expect(t, found, "actual authority feedback for late class0 proposal2 was not produced")
	_ = k.lane_frame(&pair.client.lane, 0)
	after := k.lane_world_protocol_status(&pair.client.lane)
	testing.expect_value(t, after.accepted_through, received.accepted_through)
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(0))
	if after.receipt_available {
		testing.expect_value(t, after.receipt_proposal_tick, received.receipt_proposal_tick)
		testing.expect_value(t, after.receipt_authority_tick, received.receipt_authority_tick)
	} else {
		// Explicit recovery may invalidate availability; unavailable numbers are
		// not interpreted as acknowledgements or as evidence of a new receipt.
		testing.expect(t, k.lane_world_needs_resync(&pair.client.lane))
	}
	expect_tick1_still_held(t, &pair)
}
