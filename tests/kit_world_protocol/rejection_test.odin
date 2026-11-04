package kit_world_protocol_test

import "core:testing"
import n "godot:kit/net"
import k "godot:kit/sim"

Signature_Rejection :: enum {Old_Revision, Corrupt_Encoding, Foreign_Peer}

check_signature_rejection :: proc(t: ^testing.T, variant: Signature_Rejection) {
	pair: Pair
	open_pair(t, &pair)
	defer close_pair(t, &pair)
	pair.client.action_at = 1
	pair.client.action_kind = 1
	held := hold_final_signature(t, &pair, 3)
	defer destroy_packets(&held)
	if len(held) != 1 {return}
	bad := clone_packet(held[0])
	defer delete(bad.bytes)
	from := pair.host.peer
	switch variant {
	case .Old_Revision:
		writer := n.writer_make()
		n.write_u32(&writer, k.WORLD_NETWORK_REV - 1)
		copy(bad.bytes[3:7], writer.buf[:])
		n.writer_destroy(&writer)
	case .Corrupt_Encoding:
		bad.bytes[len(bad.bytes) - 1] ~= 1
	case .Foreign_Peer:
		from = pair.client.peer
	}
	before := k.lane_world_network_status(&pair.client.lane)
	// Normal prediction may already dispatch; rejection must add no dispatch.
	effects_before_delivery := pair.client.effects
	deliver(&pair.client, from, bad)
	_ = k.lane_frame(&pair.client.lane, 0)
	if variant != .Foreign_Peer {
		testing.expect(t, k.lane_world_network_status(&pair.client.lane).rejected > before.rejected)
	}
	// A foreign peer may be rejected by Session before World sees its payload.
	testing.expect_value(t, k.lane_world_confirmed(&pair.client.lane), u64(0))
	testing.expect_value(t, k.lane_world_protocol_status(&pair.client.lane).matched_signature_tick, u64(0))
	testing.expect_value(t, pair.client.effects, effects_before_delivery)
	expect_parts(t, &pair, 0)
}

@(test)
old_revision_corrupt_and_foreign_signatures_cannot_confirm :: proc(t: ^testing.T) {
	for variant in Signature_Rejection {check_signature_rejection(t, variant)}
}
