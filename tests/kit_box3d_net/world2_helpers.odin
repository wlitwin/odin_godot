package kit_box3d_net_test

import "core:mem"
import "core:testing"
import bd "godot:box3d/diagnostics"
import s "godot:kit/session"
import k "godot:kit/sim"

// Real elapsed time, with no tick/accumulator/scale assignment. One fixed dt
// need not produce one step after the existing receipt controller changes scale.
advance_one :: proc(t: ^testing.T, box: ^Box) -> bool {
	target := k.lane_now(&box.lane) + 1
	for _ in 0 ..< 4 {
		before := k.lane_world_protocol_status(&box.lane)
		testing.expect(t, before.scale >= .98 && before.scale <= 1.02)
		returned := k.lane_frame(&box.lane, 1.0 / 120)
		testing.expect_value(t, k.lane_world_protocol_status(&box.lane).scale, before.scale)
		testing.expect(t, returned == 0 || returned == 1)
		if k.lane_now(&box.lane) >= target {
			testing.expect_value(t, k.lane_now(&box.lane), target)
			return k.lane_now(&box.lane) == target
		}
	}
	testing.expect(t, false, "real bounded public calls did not advance one tick")
	return false
}

expect_ordinary :: proc(t: ^testing.T, box: ^Box) {
	for packet in box.out {
		if len(packet.bytes) < 3 || packet.bytes[0] != s.SES_APP {continue}
		kind := packet.bytes[2]
		testing.expect(t, kind != k.SIM_WORLD_CHUNK, "ordinary World2 traffic must not send bulk checkpoints")
		if kind == k.SIM_WORLD_ACCEPTED || kind == k.SIM_WORLD_SIGNATURE {testing.expect_value(t, packet.channel, s.Channel.Reliable)}
		if kind == k.SIM_WORLD_SIGNATURE {testing.expect_value(t, len(packet.bytes), 3 + 4 + bd.SIGNATURE_BYTES)}
	}
}

advance_pair_to :: proc(t: ^testing.T, host, client: ^Box, target: u64) -> bool {
	for k.lane_now(&host.lane) < target {
		if !advance_one(t, client) {return false}
		pump({host, client})
		if !advance_one(t, host) {return false}
		expect_ordinary(t, host)
		pump({host, client}); _ = k.lane_frame(&client.lane, 0)
	}
	return true
}

expect_full5 :: proc(t: ^testing.T, host, client: ^Box, tick: u64) {
	authority, replica: k.World_Diagnostic_Frame
	ae := k.lane_world_diagnostic_frame(&host.lane, tick, &authority)
	testing.expect_value(t, ae, k.World_Error.Ok); if ae != .Ok {return}
	defer k.world_diagnostic_frame_destroy(&authority)
	ce := k.lane_world_diagnostic_frame(&client.lane, tick, &replica)
	testing.expect_value(t, ce, k.World_Error.Ok); if ce != .Ok {return}
	defer k.world_diagnostic_frame_destroy(&replica)
	for part in bd.Part {testing.expect_value(t, mem.compare(authority.view.parts[part], replica.view.parts[part]), 0)}
	testing.expect_value(t, bd.compare(authority.signature, replica.signature), bd.Difference.Match)
}
