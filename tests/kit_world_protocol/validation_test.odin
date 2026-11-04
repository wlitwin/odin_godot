package kit_world_protocol_test

import "core:testing"
import p "godot:kit/physics"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"

@(test)
malformed_whole_proposal_cannot_admit_control_or_action :: proc(t: ^testing.T) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.client.axis = 1
	pair.client.action_at = 1
	pair.client.action_kind = 1
	if !advance_one(t, &pair.client) {return}
	packets := take_packets(&pair.client)
	defer destroy_packets(&packets)
	testing.expect(t, count_kind(packets[:], k.SIM_WORLD_INPUT) > 0)
	before := k.lane_world_network_status(&pair.host.lane)
	for parcel in packets {
		kind, ok := app_kind(parcel)
		if !ok || kind != k.SIM_WORLD_INPUT {continue}
		// Preserve the actual source peer and complete encoded proposal, but
		// append one forbidden trailing byte. Validation must be transactional.
		bad := parcel
		bad.bytes = make([]u8, len(parcel.bytes) + 1)
		copy(bad.bytes, parcel.bytes)
		bad.bytes[len(parcel.bytes)] = 0xa5
		deliver(&pair.host, pair.client.peer, bad)
		delete(bad.bytes)
	}
	testing.expect_value(t, k.lane_frame(&pair.host.lane, 0), 0)
	testing.expect(t, k.lane_world_network_status(&pair.host.lane).rejected > before.rejected)
	testing.expect_value(t, k.lane_world_confirmed(&pair.host.lane), u64(0))
	testing.expect_value(t, pair.host.effects, 0)
	expect_parts(t, &pair, 0)
	if !advance_one(t, &pair.host) {return}
	control, origin, sequence, ce := k.lane_world_accepted_input(&pair.host.lane, 1, 2, 0)
	testing.expect_value(t, ce, k.World_Error.Ok)
	if ce == .Ok {
		testing.expect_value(t, origin, k.World_Input_Origin.Held)
		testing.expect_value(t, sequence, u64(0))
		testing.expect_value(t, (cast(^f.Control)raw_data(control)).axis, i32(0))
	}
	action, _, _, ae := k.lane_world_accepted_input(&pair.host.lane, 1, 2, 1)
	testing.expect_value(t, ae, k.World_Error.Ok)
	if ae == .Ok {
		testing.expect_value(t, (cast(^f.Action)raw_data(action)).kind, u32(0))
	}
	side, se := p.read(&pair.host.physics)
	testing.expect(t, se)
	if se {testing.expect_value(t, side.births, u32(0))}
	testing.expect_value(t, pair.host.effects, 0)
}
