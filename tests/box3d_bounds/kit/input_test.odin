package kit_bounds_test

import "core:mem"
import "core:testing"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"
import wp "godot:tests/kit_world_protocol"

// Only current, publicly serialized World2 packets are mutated. Offsets include
// SES_APP + Lane tag + kind, then rev/schema/epoch/bootstrap/head/first/count.
INPUT_SCOPE :: 47
INPUT_FIRST :: 63
INPUT_COUNT :: 71
INPUT_ENTRIES :: 72
INPUT_ROWS :: 73
FIXTURE_ROW_BYTES :: 32 // Control(driver/origin/seq/i32) + Action(.../u32/u32)

overwrite_u64 :: proc(bytes: []u8, offset: int, value: u64) {
	w := n.writer_make(8); defer n.writer_destroy(&w)
	n.write_u64(&w, value); copy(bytes[offset:offset + 8], n.writer_bytes(&w))
}

overwrite_u32 :: proc(bytes: []u8, offset: int, value: u32) {
	w := n.writer_make(4); defer n.writer_destroy(&w)
	n.write_u32(&w, value); copy(bytes[offset:offset + 4], n.writer_bytes(&w))
}

read_u64_at :: proc(bytes: []u8, offset: int) -> u64 {
	r := n.reader_make(bytes[offset:offset + 8]); return n.read_u64(&r)
}

saved_frame :: proc(t: ^testing.T, box: ^f.Box, tick: u64, out: ^k.World_Diagnostic_Frame) -> bool {
	e := k.lane_world_diagnostic_frame(&box.lane, tick, out)
	testing.expect_value(t, e, k.World_Error.Ok)
	return e == .Ok
}

expect_saved_frame :: proc(t: ^testing.T, box: ^f.Box, before: ^k.World_Diagnostic_Frame) {
	after: k.World_Diagnostic_Frame
	if !saved_frame(t, box, before.view.tick, &after) {return}
	defer k.world_diagnostic_frame_destroy(&after)
	for part in bd.Part {testing.expect_value(t, mem.compare(before.view.parts[part], after.view.parts[part]), 0)}
	testing.expect_value(t, bd.compare(before.signature, after.signature), bd.Difference.Match)
}

last_input :: proc(t: ^testing.T, packets: []f.Parcel, count: u8) -> f.Parcel {
	for i := len(packets) - 1; i >= 0; i -= 1 {
		packet := packets[i]; kind, ok := wp.app_kind(packet)
		if ok && kind == k.SIM_WORLD_INPUT && len(packet.bytes) > INPUT_ENTRIES && packet.bytes[INPUT_COUNT] == count {
			testing.expect_value(t, packet.bytes[INPUT_ENTRIES], u8(2))
			testing.expect_value(t, len(packet.bytes), INPUT_ROWS + int(count) * FIXTURE_ROW_BYTES)
			return wp.clone_packet(packet)
		}
	}
	testing.expect(t, false, "actual public INPUT batch was unavailable")
	return {}
}

expect_control :: proc(t: ^testing.T, box: ^f.Box, tick: u64, origin: k.World_Input_Origin, sequence: u64, axis: i32) {
	value, actual_origin, actual_sequence, e := k.lane_world_accepted_input(&box.lane, tick, 2, 0)
	testing.expect_value(t, e, k.World_Error.Ok)
	if e != .Ok {return}
	testing.expect_value(t, actual_origin, origin)
	testing.expect_value(t, actual_sequence, sequence)
	testing.expect_value(t, (cast(^f.Control)raw_data(value)).axis, axis)
}

@(test)
input8_current_scope_rejects_invalid_whole_batches_before_any_receipt_or_row :: proc(t: ^testing.T) {
	// Each mutation has a fresh real Session/Native pair and a real valid packet
	// immediately afterwards. kind3 is invalid for THIS fixture's Action schema,
	// not a claimed generic game rule or an authoritative-input validator.
	for variant in 0 ..< 4 {
		pair: wp.Pair; wp.open_pair(t, &pair)
		defer wp.close_pair(t, &pair)
		pair.client.axis = 1
		for _ in 0 ..< 8 {if !wp.advance_one(t, &pair.client) {return}}
		packets := wp.take_packets(&pair.client); defer wp.destroy_packets(&packets)
		good := last_input(t, packets[:], 8); defer delete(good.bytes)
		if len(good.bytes) != INPUT_ROWS + 8 * FIXTURE_ROW_BYTES {return}
		scope := k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence
		testing.expect(t, scope != 0)
		testing.expect_value(t, read_u64_at(good.bytes, INPUT_SCOPE), scope)
		testing.expect_value(t, read_u64_at(good.bytes, INPUT_FIRST), u64(1))
		bad := wp.clone_packet(good); defer delete(bad.bytes)
		switch variant {
		case 0: bad.bytes[INPUT_COUNT] = 9
		case 1: overwrite_u64(bad.bytes, INPUT_FIRST, max(u64) - 3)
		case 2: overwrite_u32(bad.bytes, INPUT_ROWS + 7 * FIXTURE_ROW_BYTES + 14 + 10, 3)
		case 3: overwrite_u64(bad.bytes, INPUT_SCOPE, scope + 1)
		}
		before: k.World_Diagnostic_Frame
		if !saved_frame(t, &pair.host, 0, &before) {return}
		defer k.world_diagnostic_frame_destroy(&before)
		status := k.lane_world_network_status(&pair.host.lane)
		wp.deliver(&pair.host, pair.client.peer, bad)
		testing.expect_value(t, k.lane_frame(&pair.host.lane, 0), 0)
		testing.expect(t, k.lane_world_network_status(&pair.host.lane).rejected > status.rejected)
		testing.expect_value(t, k.lane_now(&pair.host.lane), u64(0))
		testing.expect_value(t, k.lane_world_confirmed(&pair.host.lane), u64(0))
		testing.expect_value(t, pair.host.effects, 0)
		expect_saved_frame(t, &pair.host, &before)
		// Advancing authority before the valid resend observes the actual ledger:
		// even the first seven valid rows of a malformed batch must be absent.
		if !wp.advance_one(t, &pair.host) {return}
		expect_control(t, &pair.host, 1, .Held, 0, 0)
		authority := wp.take_packets(&pair.host)
		found := false
		for packet in authority {
			kind, ok := wp.app_kind(packet)
			if ok && kind == k.SIM_WORLD_ACCEPTED {
				receipt := wp.packet_receipt(t, packet, u64(pair.client.ses.me))
				testing.expect(t, receipt.found && !receipt.available && receipt.tick == 0)
				found = true
			}
		}
		testing.expect(t, found)
		wp.deliver_all(&pair.client, pair.host.peer, authority[:]); wp.destroy_packets(&authority)
		_ = k.lane_frame(&pair.client.lane, 0)
		wp.deliver(&pair.host, pair.client.peer, good)
		_ = k.lane_frame(&pair.host.lane, 0)
		for _ in 0 ..< 7 {
			if !wp.advance_one(t, &pair.host) {return}
			response := wp.take_packets(&pair.host)
			wp.deliver_all(&pair.client, pair.host.peer, response[:]); wp.destroy_packets(&response)
			_ = k.lane_frame(&pair.client.lane, 0)
		}
		expect_control(t, &pair.host, 1, .Held, 0, 0) // late receipt never rewrites admission
		expect_control(t, &pair.host, 8, .Submitted, 8, 1)
		future := wp.advance_pair_to(t, &pair, 9); defer wp.destroy_packets(&future)
		wp.expect_parts(t, &pair, 9)
		testing.expect_value(t, pair.host.effects, 1)
		testing.expect_value(t, pair.client.effects, 1)
		testing.expect(t, k.lane_world_owned_bytes(&pair.host.lane) < k.WORLD_MEMORY_BYTES)
	}
}

@(test)
input_history128_accepts_retained_edge_and_rejects_one_tick_outside :: proc(t: ^testing.T) {
	pair: wp.Pair; wp.open_pair(t, &pair); defer wp.close_pair(t, &pair)
	pair.client.axis = 1
	outside, edge: f.Parcel
	defer delete(outside.bytes); defer delete(edge.bytes)
	for tick in u64(1) ..= u64(136) {
		if !wp.advance_one(t, &pair.client) {return}
		proposals := wp.take_packets(&pair.client)
		if tick == 15 {outside = last_input(t, proposals[:], 8)}
		if tick == 16 {edge = last_input(t, proposals[:], 8)}
		wp.deliver_all(&pair.host, pair.client.peer, proposals[:]); wp.destroy_packets(&proposals)
		if !wp.advance_one(t, &pair.host) {return}
		response := wp.take_packets(&pair.host)
		wp.deliver_all(&pair.client, pair.host.peer, response[:]); wp.destroy_packets(&response)
		_ = k.lane_frame(&pair.client.lane, 0)
	}
	if len(outside.bytes) < INPUT_ROWS || len(edge.bytes) < INPUT_ROWS {testing.expect(t, false); return}
	testing.expect_value(t, read_u64_at(outside.bytes, INPUT_FIRST), u64(8))
	testing.expect_value(t, read_u64_at(edge.bytes, INPUT_FIRST), u64(9))
	before: k.World_Diagnostic_Frame
	if !saved_frame(t, &pair.host, 136, &before) {return}
	defer k.world_diagnostic_frame_destroy(&before)
	status := k.lane_world_network_status(&pair.host.lane)
	wp.deliver(&pair.host, pair.client.peer, edge); _ = k.lane_frame(&pair.host.lane, 0)
	testing.expect_value(t, k.lane_world_network_status(&pair.host.lane).rejected, status.rejected)
	expect_control(t, &pair.host, 9, .Submitted, 9, 1)
	wp.deliver(&pair.host, pair.client.peer, outside); _ = k.lane_frame(&pair.host.lane, 0)
	testing.expect(t, k.lane_world_network_status(&pair.host.lane).rejected > status.rejected)
	testing.expect_value(t, k.lane_now(&pair.host.lane), u64(136))
	testing.expect_value(t, k.lane_world_confirmed(&pair.host.lane), u64(136))
	testing.expect_value(t, pair.host.effects, 27)
	expect_saved_frame(t, &pair.host, &before)
	future := wp.advance_pair_to(t, &pair, 138); defer wp.destroy_packets(&future)
	wp.expect_parts(t, &pair, 138)
	testing.expect_value(t, pair.host.effects, 27)
	testing.expect_value(t, pair.client.effects, 27)
}
