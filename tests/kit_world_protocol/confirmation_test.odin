package kit_world_protocol_test

import "core:testing"
import s "godot:kit/session"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"

@(test)
matching_signature_confirms_without_normal_full_state_and_effects_repeat :: proc(t: ^testing.T) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.client.axis = 1
	pair.client.action_at = 1
	pair.client.action_kind = 1
	initial := k.lane_world_protocol_status(&pair.host.lane)
	replay: [dynamic]f.Parcel
	defer destroy_packets(&replay)
	for tick := u64(1); tick <= 6; tick += 1 {
		if !advance_one(t, &pair.client) {return}
		f.pump({&pair.host, &pair.client})
		if !advance_one(t, &pair.host) {return}
		packets := take_packets(&pair.host)
		expect_small_normal(t, packets[:])
		if tick % 3 == 0 {
			testing.expect_value(t, count_kind(packets[:], k.SIM_WORLD_SIGNATURE), 1)
		}
		copies := copy_packets(packets[:])
		for parcel in copies {append(&replay, parcel)}
		// Only the container moves here; replay owns every copied byte buffer.
		delete(copies)
		deliver_all(&pair.client, pair.host.peer, packets[:])
		destroy_packets(&packets)
		_ = k.lane_frame(&pair.client.lane, 0)
		if tick % 3 == 0 {
			testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), tick)
			expect_parts(t, &pair, tick)
			expect_known_effect_prefix(t, &pair, tick)
		}
	}
	final := k.lane_world_protocol_status(&pair.host.lane)
	testing.expect_value(t, final.wire_revision, u32(2))
	testing.expect_value(t, final.full_states_sent, initial.full_states_sent)
	testing.expect_value(t, final.signatures_sent - initial.signatures_sent, u64(2))
	before := pair.client.effects
	deliver_all(&pair.client, pair.host.peer, replay[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	testing.expect_value(t, pair.client.effects, before)
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(6))
	expect_parts(t, &pair, 6)
}

@(test)
signature_waits_for_contiguous_accepted_evidence_not_predicted_matches :: proc(t: ^testing.T) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.client.action_at = 1
	pair.client.action_kind = 1
	accepted, signatures: [dynamic]f.Parcel
	defer destroy_packets(&accepted)
	defer destroy_packets(&signatures)
	for _ in 0 ..< 3 {
		if !advance_one(t, &pair.client) {return}
		f.pump({&pair.host, &pair.client})
		if !advance_one(t, &pair.host) {return}
		packets := take_packets(&pair.host)
		expect_small_normal(t, packets[:])
		for parcel in packets {
			kind, ok := app_kind(parcel)
			if ok && kind == k.SIM_WORLD_SIGNATURE {
				append(&signatures, parcel)
			} else if ok && kind == k.SIM_WORLD_ACCEPTED {
				append(&accepted, parcel)
			} else {
				deliver(&pair.client, pair.host.peer, parcel)
				delete(parcel.bytes)
			}
		}
		delete(packets)
	}
	testing.expect_value(t, len(signatures), 1)
	testing.expect(t, len(accepted) > 0)
	// The fixture counter includes predicted dispatch; pending delivery must
	// not add another dispatch to the actual pre-delivery baseline.
	effects_before_delivery := pair.client.effects
	deliver_all(&pair.client, pair.host.peer, signatures[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	status := k.lane_world_protocol_status(&pair.client.lane)
	testing.expect_value(t, status.pending_signature_tick, u64(3))
	testing.expect_value(t, status.accepted_through, u64(0))
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(0))
	testing.expect_value(t, pair.client.effects, effects_before_delivery)
	deliver_all(&pair.client, pair.host.peer, accepted[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	status = k.lane_world_protocol_status(&pair.client.lane)
	testing.expect_value(t, status.accepted_through, u64(3))
	testing.expect_value(t, status.matched_signature_tick, u64(3))
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(3))
	expect_parts(t, &pair, 3)
	expect_known_effect_prefix(t, &pair, 3)
}

@(test)
accepted_catchup_runs_real_complete_simulation_within_eight :: proc(t: ^testing.T) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.host.axis = 2
	for _ in 0 ..< 3 {
		if !advance_one(t, &pair.host) {return}
	}
	packets := take_packets(&pair.host)
	defer destroy_packets(&packets)
	expect_small_normal(t, packets[:])
	testing.expect_value(t, k.lane_now(&pair.client.lane), u64(0))
	deliver_all(&pair.client, s.HOST_PEER, packets[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	testing.expect_value(t, k.lane_now(&pair.client.lane), u64(3))
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(3))
	expect_parts(t, &pair, 3)
	testing.expect_value(t, pair.client.effects, 0)
}
