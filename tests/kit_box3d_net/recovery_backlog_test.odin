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

// Public Session/Lane queue guarantee under World2. Diagnostic Corrections are
// explicitly requested, never assumed to be periodic ordinary traffic. They are
// retained IN ORDER before exactly ONE explicit Reset response. All
// arrive in one receive batch before lane_frame; there is no retry workaround.
@(test)
recovery_backlog_one_shot_reset_after_queued_corrections :: proc(t: ^testing.T) {
	host, client: Box; start_pair(&host, &client); cat := catalog()
	setup(&host, 3, &cat); setup(&client, 3, &cat); bootstrap(t, &host, &client)
	for _ in 0 ..< 8 {if !advance_one(t, &client) {return}}
	testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 0)
	discard(&client) // Stream input proposals are lost during the blackout.
	reliable: [dynamic]Parcel
	for tick in 1 ..= 24 {
		if !advance_one(t, &host) {return}
		expect_ordinary(t, &host)
		discard(&host)
		if tick % 3 == 0 {testing.expect_value(t, k.lane_world_send_checkpoint(&host.lane, client.peer, .Correction), k.World_Error.Ok)}
		for parcel in host.out {
			if parcel.channel == .Reliable &&
			   len(parcel.bytes) > 2 &&
			   parcel.bytes[0] == s.SES_APP &&
			   parcel.bytes[2] ==
				   k.SIM_WORLD_CHUNK {append(&reliable, parcel)} else {delete(parcel.bytes)}
		}
		clear(&host.out)
	}
	old_chunks := len(reliable); testing.expect(t, old_chunks > 1)
	before, be := k.lane_world_checkpoint(
		&client.lane,
		8,
	); testing.expect_value(t, be, k.World_Error.Ok)
	fields, fx := client.proxies, client.effects; side, _ := p.read(&client.physics)
	engine_before, _ := b.engine_allocation_stats(
		
	); wrapper_before, _ := b.snapshot_allocation_stats(); provider_before := p.owned_bytes()
	testing.expect_value(t, k.lane_world_request_reset(&client.lane), k.World_Error.Ok)
	testing.expect_value(t, len(client.out), 1)
	// Only the Reset request is delivered to authority now; old server Reliable
	// traffic remains queued ahead of the eventual Reset response.
	for parcel in client.out {r := n.reader_make(parcel.bytes); s.session_handle_packet(&host.ses, client.peer, &r); delete(parcel.bytes)}
	clear(&client.out); testing.expect_value(t, k.lane_frame(&host.lane, 0), 0)
	reset_chunks := len(host.out); testing.expect(t, reset_chunks > 0)
	for parcel in host.out {testing.expect_value(t, parcel.channel, s.Channel.Reliable); append(&reliable, parcel)}
	clear(&host.out)
	// Exactly the real transport shape: poll the entire ordered batch, THEN pump
	// the game stack. No lane_frame or state application between old/new chunks.
	for parcel in reliable {r := n.reader_make(parcel.bytes)
		s.session_handle_packet(&client.ses, s.HOST_PEER, &r)
		delete(parcel.bytes)}
	delete(reliable)
	testing.expect_value(t, k.lane_frame(&client.lane, 0), 0)
	status := k.lane_world_network_status(&client.lane)
	recovered :=
		status.ready && !status.needs_resync && status.head == 24 && status.confirmed == 24
	unchanged := false
	if !recovered {
		after, ae := k.lane_world_checkpoint(
			&client.lane,
			8,
		); testing.expect_value(t, ae, k.World_Error.Ok)
		equal, ee := k.world_checkpoint_equal(
			&before,
			&after,
		); testing.expect_value(t, ee, k.World_Error.Ok); unchanged = equal; k.world_checkpoint_destroy(&after)
		now, _ := p.read(
			&client.physics,
		); testing.expect_value(t, now, side); testing.expect_value(t, client.proxies, fields)
	}
	engine_after, _ := b.engine_allocation_stats(
		
	); wrapper_after, _ := b.snapshot_allocation_stats()
	fmt.printf(
		"KIT_RECOVERY_BACKLOG old_chunks=%d reset_chunks=%d requests=1 ready=%t resync=%t status=%v head=%d confirmed=%d recovered=%t old_publication_unchanged=%t engine_before=%d engine_after=%d wrapper_before=%d wrapper_after=%d provider_before=%d provider_after=%d\n",
		old_chunks,
		reset_chunks,
		status.ready,
		status.needs_resync,
		status.error,
		status.head,
		status.confirmed,
		recovered,
		unchanged,
		engine_before.live_bytes,
		engine_after.live_bytes,
		wrapper_before.live_bytes,
		wrapper_after.live_bytes,
		provider_before,
		p.owned_bytes(),
	)
	testing.expect(
		t,
		recovered,
		"a valid one-shot Reset behind ordinary Reliable backlog must recover",
	)
	if recovered {a, ae := k.lane_world_confirmed_signature(&host.lane, 24); c, ce := k.lane_world_confirmed_signature(&client.lane, 24); testing.expect_value(t, ae, k.World_Error.Ok); testing.expect_value(t, ce, k.World_Error.Ok); testing.expect_value(t, bd.compare(a, c), bd.Difference.Match)
		authority, replica: k.World_Diagnostic_Frame
		testing.expect_value(
			t,
			k.lane_world_diagnostic_frame(&host.lane, 24, &authority),
			k.World_Error.Ok,
		)
		testing.expect_value(
			t,
			k.lane_world_diagnostic_frame(&client.lane, 24, &replica),
			k.World_Error.Ok,
		)
		for part in bd.Part {testing.expect_value(t, mem.compare(authority.view.parts[part], replica.view.parts[part]), 0)}
		k.world_diagnostic_frame_destroy(&authority); k.world_diagnostic_frame_destroy(&replica)
	}
	testing.expect_value(t, client.effects, fx) // reset never republishes old effects
	k.world_checkpoint_destroy(
		&before,
	); destroy(&client); destroy(&host); b.recovery_catalog_destroy(&cat)
	engine, _ := b.engine_allocation_stats(); wrapper, _ := b.snapshot_allocation_stats()
	fmt.printf(
		"KIT_RECOVERY_BACKLOG_TEARDOWN engine=%d wrapper=%d provider=%d checkpoints=%d diagnostics=%d\n",
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
