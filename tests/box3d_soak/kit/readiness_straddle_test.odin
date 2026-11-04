package kit_readiness_straddle_test

import "core:fmt"
import "core:mem"
import "core:testing"
import "base:runtime"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import k "godot:kit/sim"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import f "godot:tests/kit_box3d_net"

Straddle_Header :: struct {
	mode: k.World_Transfer_Mode,
	sequence, epoch, tick: u64,
	total, index, count: int,
}
straddle_header :: proc(parcel: f.Parcel) -> Straddle_Header {
	r := n.reader_make(parcel.bytes)
	assert(n.read_u8(&r) == s.SES_APP)
	_ = n.read_u8(&r)
	assert(n.read_u8(&r) == k.SIM_WORLD_CHUNK)
	assert(n.read_u32(&r) == k.WORLD_NETWORK_REV)
	mode := k.World_Transfer_Mode(n.read_u8(&r))
	sequence, epoch, tick := n.read_u64(&r), n.read_u64(&r), n.read_u64(&r)
	total := int(n.read_u32(&r))
	index, count := int(n.read_u16(&r)), int(n.read_u16(&r))
	assert(!r.err)
	return {mode, sequence, epoch, tick, total, index, count}
}
straddle_hex :: proc(digest: bd.Digest) -> string {
	text: [64]u8
	digits := "0123456789abcdef"
	for byte, i in digest {text[2*i] = digits[byte >> 4]; text[2*i+1] = digits[byte & 15]}
	return fmt.tprintf("%s", string(text[:]))
}
straddle_deliver :: proc(t: ^testing.T, from, to: ^f.Box, parcel: f.Parcel, stage: string) {
	before := bd.hash_bytes(parcel.bytes)
	if len(parcel.bytes) > 2 && parcel.bytes[2] == k.SIM_WORLD_CHUNK {
		h := straddle_header(parcel)
		testing.expect_value(t, parcel.channel, s.Channel.Reliable)
		fmt.printf("STRADDLE_PACKET stage=%s mode=%v sequence=%d epoch=%d tick=%d index=%d count=%d total=%d bytes=%d sha256=%s\n",
			stage, h.mode, h.sequence, h.epoch, h.tick, h.index, h.count, h.total, len(parcel.bytes), straddle_hex(before))
	} else {
		fmt.printf("STRADDLE_PACKET stage=%s channel=%v bytes=%d sha256=%s\n", stage, parcel.channel, len(parcel.bytes), straddle_hex(before))
	}
	r := n.reader_make(parcel.bytes)
	s.session_handle_packet(&to.ses, from.peer, &r, parcel.channel)
	testing.expect(t, !r.err)
	testing.expect_value(t, bd.hash_bytes(parcel.bytes), before)
}
straddle_drain :: proc(t: ^testing.T, from, to: ^f.Box, stage: string) {
	for parcel in from.out {straddle_deliver(t, from, to, parcel, stage); delete(parcel.bytes)}
	clear(&from.out)
}
straddle_pair :: proc(t: ^testing.T, host, client: ^f.Box, tick: u64) {
	a, c: k.World_Diagnostic_Frame
	ae := k.lane_world_diagnostic_frame(&host.lane, tick, &a)
	ce := k.lane_world_diagnostic_frame(&client.lane, tick, &c)
	testing.expect_value(t, ae, k.World_Error.Ok)
	testing.expect_value(t, ce, k.World_Error.Ok)
	if ae == .Ok && ce == .Ok {
		testing.expect_value(t, bd.compare(a.signature, c.signature), bd.Difference.Match)
		for part in bd.Part {testing.expect_value(t, mem.compare(a.view.parts[part], c.view.parts[part]), 0)}
	}
	k.world_diagnostic_frame_destroy(&a); k.world_diagnostic_frame_destroy(&c)
}
straddle_preserved :: proc(t: ^testing.T, client: ^f.Box, before: ^k.World_Checkpoint, fields: [32]f.Proxy, side: f.Side, effects: int) {
	after, ae := k.lane_world_checkpoint(&client.lane, client.lane.ticker.tick)
	testing.expect_value(t, ae, k.World_Error.Ok)
	same, se := k.world_checkpoint_equal(before, &after)
	testing.expect_value(t, se, k.World_Error.Ok); testing.expect(t, same)
	now, pe := p.read(&client.physics)
	testing.expect(t, pe)
	testing.expect_value(t, now, side); testing.expect_value(t, client.proxies, fields)
	testing.expect_value(t, client.effects, effects)
	k.world_checkpoint_destroy(&after)
}

// Standalone nil-Owner real Native/public Session+Lane diagnostic; NOT an
// actual-Core/SDK or ENet acceptance run. No bytes are forged, lost or reordered.
@(test)
correction_prefix_ignored_before_reset_must_not_strand_after_ready :: proc(t: ^testing.T) {
	fmt.println("STRADDLE_MODE standalone_nil_owner_public_session_native32 noGodot noTiming")
	host, client: f.Box; f.start_pair(&host, &client); cat := f.catalog()
	f.setup(&host, 32, &cat); f.setup(&client, 32, &cat); f.bootstrap(t, &host, &client)
	before, be := k.lane_world_checkpoint(&client.lane, 0)
	testing.expect_value(t, be, k.World_Error.Ok)
	fields, fx := client.proxies, client.effects; side, pe := p.read(&client.physics)
	testing.expect(t, pe)
	// Public request makes the client unready. Delay its actual request packet
// while authority advances normally; do not assign readiness/head/ticker.
	testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
	testing.expect(t, !k.lane_world_network_status(&client.lane).ready)
	for _ in 0..<3 {testing.expect_value(t, k.lane_frame(&host.lane, 1.0/60), 1)}
	straddle_drain(t, &host, &client, "earlier_authority_while_unready")
	straddle_drain(t, &client, &host, "public_reset_request")
	_ = k.lane_frame(&host.lane, 0) // actual request response R at tick3
	testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction), k.World_Error.Ok)
	reset, correction: [dynamic]f.Parcel
	for parcel in host.out {
		h := straddle_header(parcel)
		if h.mode == .Reset {append(&reset, parcel)} else {assert(h.mode == .Correction); append(&correction, parcel)}
	}
	clear(&host.out)
	assert(len(reset) > 0 && len(correction) > 1)
	rh, ch := straddle_header(reset[0]), straddle_header(correction[0])
	assert(rh.tick == 3 && ch.tick == 3 && ch.sequence > rh.sequence && ch.index == 0)
	for parcel in reset {straddle_deliver(t, &host, &client, parcel, "R_complete_before_frame")}
	straddle_deliver(t, &host, &client, correction[0], "C_prefix_while_unready")
	straddle_preserved(t, &client, &before, fields, side, fx)
	k.world_checkpoint_destroy(&before)
	testing.expect(t, !k.lane_world_network_status(&client.lane).ready)
	_ = k.lane_frame(&client.lane, 0)
	status := k.lane_world_network_status(&client.lane)
	testing.expect(t, status.ready && !status.needs_resync)
	testing.expect_value(t, status.confirmed, u64(3))
	testing.expect_value(t, client.effects, fx)
	straddle_pair(t, &host, &client, 3)
	fmt.printf("STRADDLE_RESET_PUBLISHED R_seq=%d C_seq=%d received=%d ready=%t head=%d confirmed=%d\n", rh.sequence, ch.sequence, client.lane.world.network.received_sequence, status.ready, status.head, status.confirmed)

	// Only normal public prediction and proposals make the newer D eligible.
	for _ in 0..<3 {testing.expect_value(t, k.lane_frame(&client.lane, 1.0/60), 1)}
	straddle_drain(t, &client, &host, "normal_input_proposals")
	for _ in 0..<3 {testing.expect_value(t, k.lane_frame(&host.lane, 1.0/60), 1)}
	before, be = k.lane_world_checkpoint(&client.lane, 6)
	testing.expect_value(t, be, k.World_Error.Ok)
	fields, fx = client.proxies, client.effects; side, pe = p.read(&client.physics)
	testing.expect(t, pe)
	for parcel in correction[1:] {straddle_deliver(t, &host, &client, parcel, "C_remainder_after_ready")}
	// Authority auto-sends real complete D at tick6 after its accepted Stream
// rows. Preserve that order too; no direct receive/transfer state mutation.
	d_chunks := 0; d_sequence: u64
	for parcel in host.out {
		if len(parcel.bytes) > 2 && parcel.bytes[2] == k.SIM_WORLD_CHUNK {
			h := straddle_header(parcel); assert(h.mode == .Correction && h.tick == 6 && h.sequence > ch.sequence)
			d_chunks += 1; d_sequence = h.sequence
		}
		straddle_deliver(t, &host, &client, parcel, "newer_D_in_sender_order")
	}
	testing.expect(t, d_chunks > 1)
	straddle_preserved(t, &client, &before, fields, side, fx)
	_ = k.lane_frame(&client.lane, 0)
	status = k.lane_world_network_status(&client.lane); net := client.lane.world.network
	fmt.printf("STRADDLE_ALL_DELIVERED R=%d C=%d D=%d D_chunks=%d received_sequence=%d held_seq=%d held_tick=%d held=%d/%d seen0=%t ready=%t resync=%t status=%v head=%d confirmed=%d eligible_depth=%d fx=%d authority_fx=%d\n",
		rh.sequence, ch.sequence, d_sequence, d_chunks, net.received_sequence, net.transfer_sequence, net.transfer_tick, net.transfer_received, net.transfer_chunks, net.transfer_seen[0], status.ready, status.needs_resync, status.error, status.head, status.confirmed, status.head-u64(3), client.effects, host.effects)
	// Expected RED: C loses its ignored prefix, opens on index1, and rejects
// every complete D chunk despite no Reliable bytes being lost or reordered.
	testing.expect_value(t, status.confirmed, u64(6))
	if status.confirmed == 6 {straddle_pair(t, &host, &client, 6); testing.expect_value(t, client.effects, host.effects)} else {straddle_preserved(t, &client, &before, fields, side, fx)}
	k.world_checkpoint_destroy(&before)
	for parcel in reset {delete(parcel.bytes)}; delete(reset)
	for parcel in correction {delete(parcel.bytes)}; delete(correction)
	f.destroy(&client); f.destroy(&host); b.recovery_catalog_destroy(&cat)
	engine, _ := b.engine_allocation_stats(); wrapper, _ := b.snapshot_allocation_stats()
	fmt.printf("STRADDLE_TEARDOWN native=%d wrapper=%d provider=%d checkpoints=%d diagnostics=%d\n", engine.live_bytes, wrapper.live_bytes, p.owned_bytes(), k.world_checkpoint_owned_bytes(), k.world_diagnostic_frame_owned_bytes())
	testing.expect(t, engine.live_bytes == 0 && wrapper.live_bytes == 0 && p.owned_bytes() == 0 && k.world_checkpoint_owned_bytes() == 0 && k.world_diagnostic_frame_owned_bytes() == 0)
}

straddle_open :: proc(t: ^testing.T, host, client: ^f.Box, cat: ^b.Recovery_Catalog, count := 3) {
	f.start_pair(host, client); cat^ = f.catalog()
	f.setup(host, count, cat); f.setup(client, count, cat); f.bootstrap(t, host, client)
}
straddle_take :: proc(box: ^f.Box) -> [dynamic]f.Parcel {
	packets := box.out; box.out = nil; return packets
}
straddle_release :: proc(packets: ^[dynamic]f.Parcel) {
	for packet in packets^ {delete(packet.bytes)}
	delete(packets^); packets^ = nil
}
straddle_close :: proc(t: ^testing.T, host, client: ^f.Box, cat: ^b.Recovery_Catalog) {
	f.destroy(client); f.destroy(host); b.recovery_catalog_destroy(cat)
	a, _ := b.engine_allocation_stats(); z, _ := b.snapshot_allocation_stats()
	testing.expect(t, a.live_bytes == 0 && z.live_bytes == 0 && p.owned_bytes() == 0 && k.world_checkpoint_owned_bytes() == 0 && k.world_diagnostic_frame_owned_bytes() == 0)
	fmt.printf("STRADDLE_CONTROL_TEARDOWN native=%d wrapper=%d provider=%d checkpoints=%d diagnostics=%d\n", a.live_bytes, z.live_bytes, p.owned_bytes(), k.world_checkpoint_owned_bytes(), k.world_diagnostic_frame_owned_bytes())
}
straddle_request :: proc(t: ^testing.T, host, client: ^f.Box) -> [dynamic]f.Parcel {
	testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
	straddle_drain(t, client, host, "control_public_request")
	_ = k.lane_frame(&host.lane, 0)
	return straddle_take(host)
}
straddle_correction :: proc(t: ^testing.T, host, client: ^f.Box) -> [dynamic]f.Parcel {
	testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction), k.World_Error.Ok)
	return straddle_take(host)
}

@(test)
ignored_multiple_duplicates_retain_marker_and_pending_reset_ownership :: proc(t: ^testing.T) {
	host, client: f.Box; cat: b.Recovery_Catalog
	straddle_open(t, &host, &client, &cat, 32)
	reset := straddle_request(t, &host, &client)
	c := straddle_correction(t, &host, &client); d := straddle_correction(t, &host, &client)
	rh, ch, dh := straddle_header(reset[0]), straddle_header(c[0]), straddle_header(d[0])
	assert(ch.sequence > rh.sequence && dh.sequence > ch.sequence && len(d) > 1)
	net := client.lane.world.network
	received := net.received_sequence
	for packet in reset {straddle_deliver(t, &host, &client, packet, "pending_R")}
	owned := k.lane_world_network_status(&client.lane).owned_bytes
	selected := raw_data(net.completed[net.completed_head].bytes)
	for packet in c {straddle_deliver(t, &host, &client, packet, "ignored_C_all")}
	straddle_deliver(t, &host, &client, d[0], "ignored_D_prefix")
	testing.expect_value(t, net.ignored_correction_epoch, u64(1))
	testing.expect_value(t, net.ignored_correction_sequence, dh.sequence)
	testing.expect_value(t, net.received_sequence, received)
	testing.expect_value(t, net.completed_count, 1)
	testing.expect_value(t, raw_data(net.completed[net.completed_head].bytes), selected)
	testing.expect_value(t, k.lane_world_network_status(&client.lane).owned_bytes, owned)
	_ = k.lane_frame(&client.lane, 0)
	testing.expect(t, net.ready && !k.lane_world_needs_resync(&client.lane))
	testing.expect_value(t, net.received_sequence, rh.sequence)
	testing.expect_value(t, net.ignored_correction_sequence, dh.sequence)
	straddle_pair(t, &host, &client, 0)
	a, _ := b.engine_allocation_stats(); z, _ := b.snapshot_allocation_stats()
	owned = k.lane_world_network_status(&client.lane).owned_bytes
	duplicates := net.duplicates
	for packet in d[1:] {straddle_deliver(t, &host, &client, packet, "held_D_tail")}
	for packet in c {straddle_deliver(t, &host, &client, packet, "duplicate_older_C")}
	after_a, _ := b.engine_allocation_stats(); after_z, _ := b.snapshot_allocation_stats()
	testing.expect_value(t, after_a.total_calls, a.total_calls)
	testing.expect_value(t, after_z.total_calls, z.total_calls)
	testing.expect_value(t, k.lane_world_network_status(&client.lane).owned_bytes, owned)
	testing.expect(t, net.duplicates > duplicates && len(net.transfer) == 0 && net.completed_count == 0)
	testing.expect_value(t, net.received_sequence, rh.sequence)
	newer := straddle_correction(t, &host, &client)
	for packet in newer {straddle_deliver(t, &host, &client, packet, "new_complete_after_retired")}
	_ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, net.received_sequence, straddle_header(newer[0]).sequence)
	testing.expect_value(t, net.status, k.World_Error.Ok)
	straddle_pair(t, &host, &client, 0)
	// Explicit recovery cleanup and its same-epoch publication retain the mark.
	again := straddle_request(t, &host, &client)
	testing.expect_value(t, net.ignored_correction_sequence, dh.sequence)
	for packet in again {straddle_deliver(t, &host, &client, packet, "same_epoch_R_again")}
	_ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, net.ignored_correction_sequence, dh.sequence)
	testing.expect(t, net.ready && !k.lane_world_needs_resync(&client.lane))
	straddle_pair(t, &host, &client, 0)
	fmt.printf("STRADDLE_MULTI received=%d ignored_epoch=%d ignored_sequence=%d pending_preserved=true late_allocations=0\n", net.received_sequence, net.ignored_correction_epoch, net.ignored_correction_sequence)
	straddle_release(&reset); straddle_release(&c); straddle_release(&d); straddle_release(&newer); straddle_release(&again)
	straddle_close(t, &host, &client, &cat)
}

Straddle_Alloc :: struct {
	backing: mem.Allocator,
	deny: bool,
	network_allocations, denied: int,
}
straddle_alloc :: proc(data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old: rawptr, old_size: int, location: runtime.Source_Code_Location) -> ([]u8, mem.Allocator_Error) {
	observer := cast(^Straddle_Alloc)data
	allocating := mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed
	if observer.deny && allocating && size > 0 {observer.denied += 1; return nil, .Out_Of_Memory}
	bytes, error := observer.backing.procedure(observer.backing.data, mode, size, alignment, old, old_size, location)
	if error == nil && (mode == .Alloc || mode == .Alloc_Non_Zeroed) && size == size_of(k.World_Network) {observer.network_allocations += 1}
	return bytes, error
}

@(test)
epoch_guards_failed_recovery_and_actual_inline_charge_preserve_state :: proc(t: ^testing.T) {
	old_allocator := context.allocator
	observer := Straddle_Alloc{backing = old_allocator}
	context.allocator = {data = &observer, procedure = straddle_alloc}
	defer {context.allocator = old_allocator}
	host, client: f.Box; cat: b.Recovery_Catalog
	straddle_open(t, &host, &client, &cat)
	testing.expect_value(t, size_of(k.World_Network), 99432)
	testing.expect_value(t, observer.network_allocations, 2)
	fmt.printf("STRADDLE_SIZE old_measured=99416 current=%d actual_network_allocations=%d added_inline=%d\n", size_of(k.World_Network), observer.network_allocations, size_of(k.World_Network)-99416)
	reset := straddle_request(t, &host, &client)
	c := straddle_correction(t, &host, &client)
	extra := straddle_correction(t, &host, &client)
	for packet in reset {straddle_deliver(t, &host, &client, packet, "guard_R")}
	for packet in c {straddle_deliver(t, &host, &client, packet, "guard_ignored_C")}
	for packet in extra {straddle_deliver(t, &host, &client, packet, "guard_ignored_C_later")}
	_ = k.lane_frame(&client.lane, 0)
	net := client.lane.world.network
	mark_epoch, mark_sequence, received := net.ignored_correction_epoch, net.ignored_correction_sequence, net.received_sequence
	before, be := k.lane_world_checkpoint(&client.lane, 0); testing.expect_value(t, be, k.World_Error.Ok)
	fields, fx := client.proxies, client.effects; side, pe := p.read(&client.physics); testing.expect(t, pe)
	bad := make([]u8, len(c[0].bytes)); copy(bad, c[0].bytes)
	bad[38] = 0; bad[39] = 0 // invalid chunk count, even though sequence is retired
	r := n.reader_make(bad); s.session_handle_packet(&client.ses, s.HOST_PEER, &r, .Reliable)
	testing.expect(t, r.err); testing.expect_value(t, net.status, k.World_Error.Invalid)
	copy(bad, c[0].bytes); bad[16] = 2 // future ordinary epoch still rejects before marker
	r = n.reader_make(bad); s.session_handle_packet(&client.ses, s.HOST_PEER, &r, .Reliable)
	testing.expect_value(t, net.status, k.World_Error.Incompatible)
	r = n.reader_make(c[0].bytes); s.session_handle_packet(&client.ses, 999, &r, .Reliable)
	testing.expect_value(t, net.ignored_correction_epoch, mark_epoch)
	testing.expect_value(t, net.ignored_correction_sequence, mark_sequence)
	testing.expect_value(t, net.received_sequence, received)
	testing.expect(t, net.ready && !k.lane_world_needs_resync(&client.lane))
	straddle_preserved(t, &client, &before, fields, side, fx)
	delete(bad)
	newer := straddle_correction(t, &host, &client)
	for packet in newer {straddle_deliver(t, &host, &client, packet, "guard_valid_D")}
	_ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, net.status, k.World_Error.Ok)
	straddle_pair(t, &host, &client, 0)
	// Authority changes epoch only through its public complete-state path.
	testing.expect_value(t, k.lane_world_begin_epoch(&host.lane, 2), k.World_Error.Ok)
	testing.expect_value(t, host.lane.world.network.ignored_correction_sequence, u64(0))
	testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Reset), k.World_Error.Ok)
	failed_reset := straddle_take(&host)
	fh := straddle_header(failed_reset[0]); testing.expect_value(t, fh.sequence, u64(1))
	// Real receive-buffer allocation failure: no old publication or marker loss.
	observer.deny = true
	r = n.reader_make(failed_reset[0].bytes); s.session_handle_packet(&client.ses, s.HOST_PEER, &r, .Reliable)
	observer.deny = false
	testing.expect_value(t, observer.denied, 1)
	testing.expect_value(t, net.status, k.World_Error.Allocation_Failed)
	testing.expect_value(t, net.epoch, u64(1))
	testing.expect_value(t, net.ignored_correction_epoch, mark_epoch)
	testing.expect_value(t, net.ignored_correction_sequence, mark_sequence)
	straddle_preserved(t, &client, &before, fields, side, fx)
	testing.expect(t, len(net.transfer) == 0 && net.completed_count == 0)
	// One new public recovery request; no status/epoch/head setter or old-input retry.
	accepted_reset := straddle_request(t, &host, &client)
	for packet in accepted_reset {straddle_deliver(t, &host, &client, packet, "accepted_new_epoch_R")}
	testing.expect_value(t, net.epoch, u64(1)) // receipt alone cannot retire state
	testing.expect_value(t, net.ignored_correction_sequence, mark_sequence)
	_ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, net.epoch, u64(2))
	testing.expect_value(t, net.ignored_correction_epoch, u64(0))
	testing.expect_value(t, net.ignored_correction_sequence, u64(0))
	testing.expect(t, net.ready && !k.lane_world_needs_resync(&client.lane))
	straddle_pair(t, &host, &client, 0)
	lower := straddle_correction(t, &host, &client)
	lh := straddle_header(lower[0]); testing.expect(t, lh.sequence < mark_sequence && lh.epoch == 2)
	for packet in lower {straddle_deliver(t, &host, &client, packet, "lower_numeric_new_epoch_C")}
	_ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, net.received_sequence, lh.sequence)
	testing.expect_value(t, net.status, k.World_Error.Ok)
	straddle_pair(t, &host, &client, 0)
	received = net.received_sequence
	for packet in c {straddle_deliver(t, &host, &client, packet, "old_epoch_tail")}
	testing.expect_value(t, net.received_sequence, received)
	testing.expect_value(t, net.ignored_correction_epoch, u64(0))
	testing.expect(t, net.ready && !k.lane_world_needs_resync(&client.lane))
	straddle_pair(t, &host, &client, 0)
	// Even malformed stale-epoch packets pass framing validation before ignore.
	stale_bad := make([]u8, len(c[0].bytes)); copy(stale_bad, c[0].bytes)
	stale_bad[38] = 0; stale_bad[39] = 0
	r = n.reader_make(stale_bad); s.session_handle_packet(&client.ses, s.HOST_PEER, &r, .Reliable)
	delete(stale_bad)
	testing.expect(t, r.err); testing.expect_value(t, net.status, k.World_Error.Invalid)
	testing.expect_value(t, net.epoch, u64(2)); testing.expect_value(t, net.received_sequence, received)
	testing.expect_value(t, net.ignored_correction_sequence, u64(0))
	// A healthy new-epoch suffix still executes normal input + physics/effects,
	// then both real complete checkpoints apply one per ingest through tick6.
	for _ in 0..<6 {testing.expect_value(t, k.lane_frame(&client.lane, 1.0/60), 1)}
	straddle_drain(t, &client, &host, "new_epoch_suffix_inputs")
	for _ in 0..<6 {testing.expect_value(t, k.lane_frame(&host.lane, 1.0/60), 1)}
	straddle_drain(t, &host, &client, "new_epoch_suffix_authority")
	_ = k.lane_frame(&client.lane, 0); _ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(6))
	testing.expect_value(t, net.status, k.World_Error.Ok)
	straddle_pair(t, &host, &client, 6)
	testing.expect_value(t, client.effects, host.effects); testing.expect(t, client.effects > 0)
	k.world_checkpoint_destroy(&before)
	straddle_release(&reset); straddle_release(&c); straddle_release(&extra); straddle_release(&newer); straddle_release(&failed_reset); straddle_release(&accepted_reset); straddle_release(&lower)
	straddle_close(t, &host, &client, &cat)
}
