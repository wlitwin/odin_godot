package kit_world_protocol_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import f "godot:tests/kit_box3d_net"

DT :: 1.0 / 60.0

Usage :: struct {
	engine, snapshots, provider: u64,
}

Pair :: struct {
	host, client: f.Box,
	catalog:      b.Recovery_Catalog,
	before:       Usage,
}

usage :: proc(t: ^testing.T) -> Usage {
	engine, ee := b.engine_allocation_stats()
	snapshots, se := b.snapshot_allocation_stats()
	testing.expect_value(t, ee, b.Status.Ok)
	testing.expect_value(t, se, b.Status.Ok)
	return {u64(engine.live_bytes), u64(snapshots.live_bytes), u64(p.owned_bytes())}
}

// Initialize in place: Session, Lane and provider callbacks retain Box addresses.
open_pair :: proc(t: ^testing.T, pair: ^Pair) {
	pair.before = usage(t)
	pair.catalog = f.catalog()
	f.start_pair(&pair.host, &pair.client)
	f.setup(&pair.host, 3, &pair.catalog)
	f.setup(&pair.client, 3, &pair.catalog)
	f.bootstrap(t, &pair.host, &pair.client)
}

close_pair :: proc(t: ^testing.T, pair: ^Pair) {
	f.destroy(&pair.client)
	f.destroy(&pair.host)
	testing.expect_value(t, b.recovery_catalog_destroy(&pair.catalog), b.Status.Ok)
	testing.expect_value(t, usage(t), pair.before)
}

// Supply real elapsed time in bounded half-tick calls. Feedback may change the
// scale at zero ingress; never force ticker state or assume 1/60 always steps.
advance_one :: proc(t: ^testing.T, box: ^f.Box) -> bool {
	target := k.lane_now(&box.lane) + 1
	for _ in 0 ..< 4 {
		before := k.lane_world_protocol_status(&box.lane)
		testing.expect(t, before.scale >= 0.98 && before.scale <= 1.02)
		returned := k.lane_frame(&box.lane, DT / 2)
		after := k.lane_world_protocol_status(&box.lane)
		testing.expect_value(t, after.scale, before.scale)
		testing.expect(t, returned == 0 || returned == 1)
		if k.lane_now(&box.lane) >= target {
			testing.expect_value(t, k.lane_now(&box.lane), target)
			return k.lane_now(&box.lane) == target
		}
	}
	testing.expect(t, false, "bounded real Lane calls did not advance one tick")
	return false
}

// These buffers are copies made by the actual Session send callback. Only the
// test transport's owned queue is moved; no World/Session state is synthesized.
take_packets :: proc(box: ^f.Box) -> [dynamic]f.Parcel {
	packets := box.out
	box.out = nil
	return packets
}

destroy_packets :: proc(packets: ^[dynamic]f.Parcel) {
	for parcel in packets^ {delete(parcel.bytes)}
	delete(packets^)
	packets^ = nil
}

deliver :: proc(to: ^f.Box, from: s.Peer_Id, parcel: f.Parcel) {
	reader := n.reader_make(parcel.bytes)
	s.session_handle_packet(&to.ses, from, &reader)
}

deliver_all :: proc(to: ^f.Box, from: s.Peer_Id, packets: []f.Parcel) {
	for parcel in packets {deliver(to, from, parcel)}
}

copy_packets :: proc(packets: []f.Parcel) -> [dynamic]f.Parcel {
	result: [dynamic]f.Parcel
	for parcel in packets {
		bytes := make([]u8, len(parcel.bytes))
		copy(bytes, parcel.bytes)
		append(&result, f.Parcel{parcel.to, bytes, parcel.channel})
	}
	return result
}

app_kind :: proc(parcel: f.Parcel) -> (kind: u8, ok: bool) {
	if len(parcel.bytes) < 3 || parcel.bytes[0] != s.SES_APP {return 0, false}
	return parcel.bytes[2], true
}

count_kind :: proc(packets: []f.Parcel, expected: u8) -> int {
	count := 0
	for parcel in packets {
		kind, ok := app_kind(parcel)
		if ok && kind == expected {count += 1}
	}
	return count
}

clone_packet :: proc(parcel: f.Parcel) -> f.Parcel {
	result := parcel
	result.bytes = make([]u8, len(parcel.bytes))
	copy(result.bytes, parcel.bytes)
	return result
}

expect_small_normal :: proc(t: ^testing.T, packets: []f.Parcel) {
	testing.expect_value(t, count_kind(packets, k.SIM_WORLD_CHUNK), 0)
	for parcel in packets {
		kind, ok := app_kind(parcel)
		if !ok {continue}
		if kind == k.SIM_WORLD_ACCEPTED || kind == k.SIM_WORLD_SIGNATURE {
			testing.expect_value(t, parcel.channel, s.Channel.Reliable)
		}
		if kind == k.SIM_WORLD_SIGNATURE {
			testing.expect_value(t, len(parcel.bytes), 3 + 4 + bd.SIGNATURE_BYTES)
		}
	}
}

// Advance the genuine pair, leaving copies of only the final authority batch.
advance_pair_to :: proc(t: ^testing.T, pair: ^Pair, target: u64) -> [dynamic]f.Parcel {
	last: [dynamic]f.Parcel
	for k.lane_now(&pair.host.lane) < target {
		if !advance_one(t, &pair.client) {return last}
		f.pump({&pair.host, &pair.client})
		if !advance_one(t, &pair.host) {return last}
		packets := take_packets(&pair.host)
		expect_small_normal(t, packets[:])
		destroy_packets(&last)
		last = copy_packets(packets[:])
		deliver_all(&pair.client, pair.host.peer, packets[:])
		destroy_packets(&packets)
		_ = k.lane_frame(&pair.client.lane, 0)
	}
	return last
}

hold_final_signature :: proc(t: ^testing.T, pair: ^Pair, target: u64) -> [dynamic]f.Parcel {
	held: [dynamic]f.Parcel
	for k.lane_now(&pair.host.lane) < target {
		if !advance_one(t, &pair.client) {return held}
		f.pump({&pair.host, &pair.client})
		if !advance_one(t, &pair.host) {return held}
		packets := take_packets(&pair.host)
		expect_small_normal(t, packets[:])
		for parcel in packets {
			kind, ok := app_kind(parcel)
			if k.lane_now(&pair.host.lane) == target && ok && kind == k.SIM_WORLD_SIGNATURE {
				append(&held, parcel)
			} else {
				deliver(&pair.client, pair.host.peer, parcel)
				delete(parcel.bytes)
			}
		}
		delete(packets)
		_ = k.lane_frame(&pair.client.lane, 0)
	}
	testing.expect_value(t, len(held), 1)
	return held
}

// Inspect the new public ACCEPTED format for this fixture's four drivers.
// This is not an alternative acceptance parser: receiver behavior is checked
// separately through public Lane getters. Payload bytes are never rewritten.
Receipt :: struct {
	found, available: bool,
	bootstrap, tick:  u64,
}

packet_receipt :: proc(t: ^testing.T, packet: f.Parcel, player: u64) -> Receipt {
	r := n.reader_make(packet.bytes)
	if n.read_u8(&r) != s.SES_APP {testing.expect(t, false); return {}}
	_ = n.read_u8(&r) // actual Lane tag
	if n.read_u8(&r) != k.SIM_WORLD_ACCEPTED {testing.expect(t, false); return {}}
	testing.expect_value(t, n.read_u32(&r), u32(2))
	for _ in 0 ..< 32 {_ = n.read_u8(&r)} // actual input schema
	for _ in 0 ..< 3 {_ = n.read_u64(&r)} // epoch/head/first
	count, entries := int(n.read_u8(&r)), int(n.read_u8(&r))
	if count > 8 || entries != 4 {testing.expect(t, false); return {}}
	for _ in 0 ..< count {
		for _ in 0 ..< entries {
			driver := int(n.read_u8(&r))
			if driver >= 4 {testing.expect(t, false); return {}}
			_ = n.read_u8(&r) // origin
			_ = n.read_u64(&r)
			width := driver % 2 == 0 ? 4 : 8 // Control i32; Action u32,u32
			for _ in 0 ..< width {_ = n.read_u8(&r)}
		}
	}
	receipts := int(n.read_u8(&r))
	if receipts > 2 {testing.expect(t, false); return {}}
	result: Receipt
	for _ in 0 ..< receipts {
		seat, scope := n.read_u64(&r), n.read_u64(&r)
		available, tick := n.read_u8(&r), n.read_u64(&r)
		testing.expect(t, available <= 1)
		if seat == player {
			testing.expect(t, !result.found)
			result = {true, available == 1, scope, tick}
		}
	}
	testing.expect(t, !r.err && len(n.reader_remaining(&r)) == 0)
	return result
}

public_reset :: proc(t: ^testing.T, pair: ^Pair) {
	testing.expect_value(t, k.lane_world_request_reset(&pair.client.lane), k.World_Error.Ok)
	f.pump({&pair.host, &pair.client})
	_ = k.lane_frame(&pair.host.lane, 0)
	response := take_packets(&pair.host)
	defer destroy_packets(&response)
	testing.expect(t, count_kind(response[:], k.SIM_WORLD_CHUNK) > 0)
	deliver_all(&pair.client, pair.host.peer, response[:])
	_ = k.lane_frame(&pair.client.lane, 0)
	testing.expect(t, k.lane_world_network_status(&pair.client.lane).ready)
	testing.expect(t, !k.lane_world_needs_resync(&pair.client.lane))
}

expect_parts :: proc(t: ^testing.T, pair: ^Pair, tick: u64) {
	authority, replica: k.World_Diagnostic_Frame
	ae := k.lane_world_diagnostic_frame(&pair.host.lane, tick, &authority)
	testing.expect_value(t, ae, k.World_Error.Ok)
	if ae != .Ok {return}
	defer k.world_diagnostic_frame_destroy(&authority)
	ce := k.lane_world_diagnostic_frame(&pair.client.lane, tick, &replica)
	testing.expect_value(t, ce, k.World_Error.Ok)
	if ce != .Ok {return}
	defer k.world_diagnostic_frame_destroy(&replica)
	for part in bd.Part {
		testing.expect_value(t, mem.compare(authority.view.parts[part], replica.view.parts[part]), 0)
	}
	testing.expect_value(t, bd.compare(authority.signature, replica.signature), bd.Difference.Match)
	a, aerr := k.lane_world_confirmed_signature(&pair.host.lane, tick)
	c, cerr := k.lane_world_confirmed_signature(&pair.client.lane, tick)
	testing.expect_value(t, aerr, k.World_Error.Ok)
	testing.expect_value(t, cerr, k.World_Error.Ok)
	if aerr == .Ok && cerr == .Ok {
		testing.expect_value(t, bd.compare(a, c), bd.Difference.Match)
	}
}

// A known fixture action at tick1 emits key102 once; tick5 emits key1 once.
// Checking each confirmed prefix and replaying its original transport packets
// prevents an aggregate host/client count comparison from hiding duplicates.
expect_known_effect_prefix :: proc(t: ^testing.T, pair: ^Pair, tick: u64) {
	expected := int(tick / 5)
	if tick >= 1 {expected += 1}
	testing.expect_value(t, pair.host.effects, expected)
	testing.expect_value(t, pair.client.effects, expected)
}
