package replay_authority_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

@(test)
prepared_archive_outlives_replica_storage_and_requires_the_exact_grant_to_restore :: proc(t: ^testing.T) {
	c: auth.Coordinator; ledger: Ledger; setup(&c, &ledger)
	clock: Clock; old: auth.Lease; grant_lease(&old, &c, &clock, A)
	source, resumed: Server
	defer net.server_destroy(&source); defer net.server_destroy(&resumed)
	cfg := net.DEFAULT_CONFIG; cfg.content, cfg.require_permit = 55, true
	net.server_init(&source, r.Frame(World){}, model(), {}, cfg, local_seat = 1, permit = auth.lease_permit(&old))
	net.server_set_local_token(&source, net.Token{0 = 7})
	net.server_issue(&source, Action{4})
	net.server_step(&source)
	cp: net.Checkpoint(World, Control, Action, 2); defer net.checkpoint_destroy(&cp)
	net.checkpoint_capture(&source, &cp)
	m: tr.Memory; tr.memory_init(&m, cfg = {2, 32, 1200, 512}); defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint; tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&wa); defer tr.close(&wb)
	sender: rec.Sender; receiver: rec.Receiver(World, Control, Action, Event, 2)
	defer rec.sender_destroy(&sender); defer rec.receiver_destroy(&receiver)
	scope := rec.Scope{44, 1, 9, 55}
	rec.sender_init(&sender, scope, 2, wa)
	rec.receiver_init(&receiver, scope, 1, wb, model())
	rec.sender_publish(&sender, &cp, model(), 0)
	buffer: [1200]u8
	for tick in u64(1) ..< 100 {
		tr.memory_advance(&m, tick)
		for _ in 0 ..< 32 {packet := tr.receive(&wa, buffer[:]); if packet.state != .Received {break}; rec.sender_receive(&sender, packet.from, buffer[:packet.count], tick)}
		for _ in 0 ..< 32 {packet := tr.receive(&wb, buffer[:]); if packet.state != .Received {break}; rec.receiver_receive(&receiver, packet.from, buffer[:packet.count], tick)}
		rec.sender_update(&sender, tick); rec.receiver_update(&receiver, tick)
		if sender.phase == .Complete {break}
	}
	testing.expect_value(t, sender.phase, rec.Phase.Complete)
	prepared: auth.Prepared; defer auth.prepared_destroy(&prepared)
	testing.expect_value(t, auth.prepared_copy(&prepared, &receiver, sender.acknowledged.archive), auth.Error.None)
	rec.receiver_destroy(&receiver) // no borrowed archive may be required after this point
	auth.coordinator_nominate(&c, A, 1, B, 9, 100)
	testing.expect_value(t, auth.coordinator_prepare(&c, B, prepared.point, 100), auth.Error.None)
	retired, _ := auth.lease_retire(&old)
	testing.expect_value(t, auth.coordinator_release(&c, A, retired, prepared.point, 100), auth.Error.None)
	new_clock := Clock{now = 100}
	lease: auth.Lease; auth.lease_init(&lease, B, 44, 55, clock_source(&new_clock), true)
	codec: net.Checkpoint_Codec; defer net.checkpoint_codec_destroy(&codec)
	testing.expect_value(t, net.checkpoint_codec_init(&codec, World, Control, Action, Event, 2), net.Error.None)
	request, _ := auth.lease_request(&lease)
	testing.expect_value(t, auth.prepared_restore(&prepared, &resumed, model(), {}, &lease, 0, codec = &codec), net.Error.Fenced)
	testing.expect_value(t, auth.coordinator_claim(&c, B, 1, request, prepared.point, 100), auth.Error.None)
	view, _ := auth.coordinator_view(&c, 100)
	auth.lease_accept(&lease, request, view)
	testing.expect_value(t, auth.prepared_restore(&prepared, &resumed, model(), {}, &lease, 0, codec = &codec), net.Error.None)
	net.checkpoint_codec_destroy(&codec) // the new runtime must not borrow decoding metadata
	frame, _ := r.current(&resumed.timeline)
	testing.expect_value(t, frame.state.value, u32(4))
	testing.expect_value(t, frame.tick, cp.frame.tick)
	testing.expect_value(t, net.server_step(&source), net.Error.Fenced)
	testing.expect_value(t, net.server_step(&resumed), net.Error.None)
	frame, _ = r.current(&resumed.timeline)
	testing.expect_value(t, frame.state.value, u32(4))
	testing.expect_value(t, frame.tick, cp.frame.tick + 1)
}
