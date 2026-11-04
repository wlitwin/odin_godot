package kit_box3d_net_test

import "core:fmt"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"

@(test)
stale_epoch_accepted_packet_is_fully_validated_then_ignored :: proc(t: ^testing.T) {
	host, client: Box; start_pair(&host, &client); cat := catalog()
	setup(&host, 3, &cat); setup(&client, 3, &cat); bootstrap(t, &host, &client)
	if !advance_one(t, &client) {return}; pump({&host, &client})
	if !advance_one(t, &host) {return}
	old: []u8
	for parcel in host.out {if len(parcel.bytes) > 2 && parcel.bytes[0] == s.SES_APP && parcel.bytes[2] == k.SIM_WORLD_ACCEPTED {old = make([]u8, len(parcel.bytes)); copy(old, parcel.bytes)}}
	testing.expect(t, len(old) > 67)
	pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
	testing.expect_value(
		t,
		k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction),
		k.World_Error.Ok,
	); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, k.lane_world_begin_epoch(&host.lane, 3), k.World_Error.Ok)
	testing.expect_value(
		t,
		k.lane_world_send_checkpoint(&host.lane, client.peer, .Reset),
		k.World_Error.Ok,
	); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
	// The old packet is also older than H128, proving stale validation does not
	// accidentally use current-epoch age/future-window admission.
	_ = advance_pair_to(t, &host, &client, 132)
	testing.expect_value(t, k.lane_world_confirmed(&client.lane), u64(132))
	initial := k.lane_world_network_status(&client.lane)
	testing.expect(t, initial.ready && !initial.needs_resync && initial.epoch == 3 && initial.head == 132 && initial.confirmed == 132,
		"stale replay requires a real healthy current-scope baseline first")
	protocol := k.lane_world_protocol_status(&client.lane)
	before: k.World_Diagnostic_Frame; testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 132, &before), k.World_Error.Ok)
	net := client.lane.world.network
	accepted, proposed, used := net.accepted, net.proposed, net.used
	accepted_data := make([]u8, len(net.accepted_data)); copy(accepted_data, net.accepted_data)
	proposed_data := make([]u8, len(net.proposed_data)); copy(proposed_data, net.proposed_data)
	used_data := make([]u8, len(net.used_data)); copy(used_data, net.used_data)
	fields, fx :=
		client.proxies,
		client.effects; side, _ := p.read(&client.physics); received, batches, resims := net.received_sequence, net.accepted_batches, client.lane.stat_resims
	engine_before, _ := b.engine_allocation_stats(
		
	); wrapper_before, _ := b.snapshot_allocation_stats(); provider_before := p.owned_bytes()
	// Replay the exact captured legitimate authority payload as a NEW transport
	// delivery, rather than relying on transport stale-sequence suppression.
	reader := n.reader_make(
		old,
	); s.session_handle_packet(&client.ses, s.HOST_PEER, &reader); _ = k.lane_frame(&client.lane, 0)
	testing.expect_value(t, k.lane_world_protocol_status(&client.lane), protocol)
	status := k.lane_world_network_status(&client.lane)
	healthy :=
		status.ready &&
		!status.needs_resync &&
		status.epoch == 3 &&
		status.head == 132 &&
		status.confirmed == 132
	testing.expect(
		t,
		healthy,
		"validated obsolete accepted input must not poison the current epoch",
	)
	after: k.World_Diagnostic_Frame; testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 132, &after), k.World_Error.Ok)
	for part in bd.Part {testing.expect_value(t, mem.compare(before.view.parts[part], after.view.parts[part]), 0)}
	testing.expect_value(t, bd.compare(before.signature, after.signature), bd.Difference.Match)
	testing.expect_value(
		t,
		net.accepted,
		accepted,
	); testing.expect_value(t, net.proposed, proposed); testing.expect_value(t, net.used, used)
	testing.expect_value(
		t,
		mem.compare(net.accepted_data, accepted_data),
		0,
	); testing.expect_value(t, mem.compare(net.proposed_data, proposed_data), 0); testing.expect_value(t, mem.compare(net.used_data, used_data), 0)
	testing.expect_value(
		t,
		net.received_sequence,
		received,
	); testing.expect_value(t, net.accepted_batches, batches); testing.expect_value(t, client.lane.stat_resims, resims)
	now, _ := p.read(
		&client.physics,
	); testing.expect_value(t, now, side); testing.expect_value(t, client.proxies, fields); testing.expect_value(t, client.effects, fx)
	engine_after, _ := b.engine_allocation_stats(
		
	); wrapper_after, _ := b.snapshot_allocation_stats()
	fmt.printf(
		"KIT_STALE_EPOCH healthy=%t ready=%t resync=%t status=%v epoch=%d head=%d confirmed=%d old_epoch=1 old_tick=1 current_window_lapped=true fullparts_unchanged=%t engine_before=%d engine_after=%d wrapper_before=%d wrapper_after=%d provider_before=%d provider_after=%d\n",
		healthy,
		status.ready,
		status.needs_resync,
		status.error,
		status.epoch,
		status.head,
		status.confirmed,
		bd.compare(before.signature, after.signature) == .Match,
		engine_before.live_bytes,
		engine_after.live_bytes,
		wrapper_before.live_bytes,
		wrapper_after.live_bytes,
		provider_before,
		p.owned_bytes(),
	)
	k.world_diagnostic_frame_destroy(&before); k.world_diagnostic_frame_destroy(&after)
	delete(accepted_data); delete(proposed_data); delete(used_data)
	if healthy {
		// Continue healthy ordinary suffix BEFORE negative controls; no status clear,
		// reset retry or manual state repair participates in this proof.
		_ = advance_pair_to(t, &host, &client, 140)
		testing.expect_value(
			t,
			k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction),
			k.World_Error.Ok,
		); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
		expect_same(
			t,
			&host,
			&client,
			140,
		); testing.expect(t, k.lane_world_network_status(&client.lane).ready && !k.lane_world_needs_resync(&client.lane))
		// Old-epoch status is not a structural-validation bypass. Header version,
		// schema, nonzero/future epoch, driver/origin/sequence and trailing checks
		// remain observable rejected controls, even after the valid stale ignore.
		protected: k.World_Diagnostic_Frame; testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 140, &protected), k.World_Error.Ok)
		for control in 0 ..< 8 {
			bad := make([]u8, len(old) + 1); copy(bad, old); payload := bad[:len(old)]
			switch control {
			case 0:
				bad[3] ~= 1 // wire version
			case 1:
				bad[7] ~= 1 // schema digest
			case 2:
				for i in 0 ..< 8 {bad[39 + i] = 0} 	// epoch0
			case 3:
				for i in 0 ..< 8 {bad[39 + i] = 0}; bad[39] = 4 	// future epoch
			case 4:
				bad[65] = 255 // driver index
			case 5:
				bad[66] = 255 // origin
			case 6:
				bad[67] = 2 // source sequence != rowtick1
			case 7:
				payload = bad[:] // trailing byte
			}
			rejected := net.rejected; ignored := net.duplicates
			r := n.reader_make(
				payload,
			); s.session_handle_packet(&client.ses, s.HOST_PEER, &r); _ = k.lane_frame(&client.lane, 0)
			testing.expect(
				t,
				net.rejected > rejected,
			); testing.expect_value(t, net.duplicates, ignored); testing.expect(t, k.lane_world_needs_resync(&client.lane))
			current: k.World_Diagnostic_Frame; testing.expect_value(t, k.lane_world_diagnostic_frame(&client.lane, 140, &current), k.World_Error.Ok)
			for part in bd.Part {testing.expect_value(t, mem.compare(protected.view.parts[part], current.view.parts[part]), 0)}
			k.world_diagnostic_frame_destroy(&current); delete(bad)
		}
		k.world_diagnostic_frame_destroy(&protected)
		// Rejection is not the end of the proof: exactly one real Reset retires
		// the invalid receive context, then valid current-scope work must resume.
		testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
		pump({&host, &client}); _ = k.lane_frame(&host.lane, 0); pump({&host, &client}); _ = k.lane_frame(&client.lane, 0)
		_ = advance_pair_to(t, &host, &client, 147)
		expect_same(t, &host, &client, 147); expect_full5(t, &host, &client, 147)
		testing.expect_value(t, client.effects, host.effects)
	}
	delete(old); destroy(&client); destroy(&host); b.recovery_catalog_destroy(&cat)
	engine, _ := b.engine_allocation_stats(); wrapper, _ := b.snapshot_allocation_stats()
	fmt.printf(
		"KIT_STALE_EPOCH_TEARDOWN engine=%d wrapper=%d provider=%d checkpoints=%d diagnostics=%d\n",
		engine.live_bytes,
		wrapper.live_bytes,
		p.owned_bytes(),
		k.world_checkpoint_owned_bytes(),
		k.world_diagnostic_frame_owned_bytes(),
	)
	testing.expect(
		t,
		engine.live_bytes == 0 &&
		wrapper.live_bytes == 0 &&
		p.owned_bytes() == 0 &&
		k.world_checkpoint_owned_bytes() == 0 &&
		k.world_diagnostic_frame_owned_bytes() == 0,
	)
}
