package replay_net_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Checkpoint :: net.Checkpoint(World, Control, Action, 2)

@(test)
cached_archive_codecs_preserve_bytes_validation_and_owned_lifetimes :: proc(t: ^testing.T) {
	s: Server
	defer net.server_destroy(&s)
	net.server_init(&s, r.Frame(World){state = {chest = 5}}, model(), {}, local_seat = 1)
	net.server_set_local_token(&s, net.Token{0 = 14})
	codec: net.Checkpoint_Codec
	defer net.checkpoint_codec_destroy(&codec)
	testing.expect_value(t, net.checkpoint_codec_init(&codec, World, Control, Action, Event, 2), net.Error.None)
	testing.expect_value(t, net.checkpoint_codec_init(&codec, World, Control, Action, Event, 2), net.Error.Wrong_Phase)
	for _ in 0 ..< 3 {
		net.server_step(&s)
		cp, decoded: Checkpoint
		defer net.checkpoint_destroy(&cp); defer net.checkpoint_destroy(&decoded)
		net.checkpoint_capture(&s, &cp)
		plain, a := net.checkpoint_encode(&cp, model())
		cached, b := net.checkpoint_encode(&cp, model(), codec = &codec)
		defer delete(plain); defer delete(cached)
		testing.expect_value(t, a, net.Error.None); testing.expect_value(t, b, net.Error.None)
		testing.expect(t, reflect.equal(plain, cached, true))
		testing.expect_value(t, net.checkpoint_decode(&decoded, cached, model(), 99, codec = &codec), net.Error.Invalid_Checkpoint)
		cached[len(cached) - 1] ~= 1
		testing.expect_value(t, net.checkpoint_decode(&decoded, cached, model(), 1, codec = &codec), net.Error.Invalid_Checkpoint)
		cached[len(cached) - 1] ~= 1
		testing.expect_value(t, net.checkpoint_decode(&decoded, cached, model(), 1, codec = &codec), net.Error.None)
		testing.expect(t, reflect.equal(cp.frame, decoded.frame))
	}
	wrong: net.Checkpoint_Codec
	defer net.checkpoint_codec_destroy(&wrong)
	net.checkpoint_codec_init(&wrong, Private_World, Control, Action, Event, 2)
	cp: Checkpoint
	defer net.checkpoint_destroy(&cp)
	net.checkpoint_capture(&s, &cp)
	bytes, err := net.checkpoint_encode(&cp, model(), codec = &wrong)
	defer delete(bytes)
	testing.expect_value(t, err, net.Error.Invalid_Schema)
}

@(test)
checkpoint_roundtrip_promotes_existing_seat_and_preserves_action_frontiers :: proc(t: ^testing.T) {
	f: Fixture
	fixture_init(&f)
	defer fixture_destroy(&f)
	for _ in 0 ..< 30 {fixture_step(&f)}
	net.client_issue(&f.clients[1], Action{take = true})
	for _ in 0 ..< 40 {fixture_step(&f)}
	net.server_set_locked(&f.server, true)
	cp, decoded: Checkpoint
	defer net.checkpoint_destroy(&cp)
	defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
	bytes, err := net.checkpoint_encode(&cp, model())
	defer delete(bytes)
	testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content), net.Error.None)
	testing.expect(t, reflect.equal(cp.frame, decoded.frame))
	testing.expect(t, reflect.equal(cp.peers[:], decoded.peers[:], true))
	testing.expect(t, reflect.equal(cp.outcomes[:], decoded.outcomes[:], true))
	resumed: Server
	defer net.server_destroy(&resumed)
	testing.expect_value(t, net.server_restore(&resumed, &decoded, model(), {},
	                     {epoch = 2, local_seat = 2, preserve_pending = true, retain_membership = true}), net.Error.None)
	frame, _ := r.current(&resumed.timeline)
	testing.expect(t, reflect.equal(cp.frame, frame))
	testing.expect(t, resumed.locked)
	sequence, issued := net.server_issue(&resumed, Action{take = true})
	testing.expect_value(t, issued, net.Error.None)
	testing.expect_value(t, sequence, u64(2)) // previous seat 2 action was already accepted and settled
	testing.expect_value(t, net.server_step(&resumed), net.Error.None)
	frame, _ = r.current(&resumed.timeline)
	testing.expect_value(t, frame.state.players[1].bag, u32(5))
	testing.expect_value(t, frame.state.chest, u32(0))
	events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
	n, _ := r.copy_events(&resumed.timeline, frame.tick, events[:])
	testing.expect_value(t, n, 1)
	testing.expect_value(t, events[0].value.sequence, u64(2))
	testing.expect(t, !events[0].value.applied)
	testing.expect_value(t, events[0].id.epoch, u64(2))
}

@(test)
checkpoint_resume_explicitly_preserves_or_retires_unexecuted_actions :: proc(t: ^testing.T) {
	s: Server
	defer net.server_destroy(&s)
	testing.expect_value(t, net.server_init(&s, r.Frame(World){state = {chest = 5}}, model(), {}, local_seat = 1), net.Error.None)
	testing.expect_value(t, net.server_set_local_token(&s, net.Token{0 = 42}), net.Error.None)
	net.server_step(&s)
	net.server_issue(&s, Action{take = true})
	cp: Checkpoint
	defer net.checkpoint_destroy(&cp)
	testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
	policies := [2]bool{true, false}
	for preserve in policies {
		resumed: Server
		defer net.server_destroy(&resumed)
		testing.expect_value(t, net.server_restore(&resumed, &cp, model(), {},
		                     {epoch = 2, local_seat = 1, preserve_pending = preserve}), net.Error.None)
		testing.expect_value(t, net.server_step(&resumed), net.Error.None)
		frame, _ := r.current(&resumed.timeline)
		testing.expect_value(t, frame.state.players[0].bag, preserve ? u32(5) : u32(0))
		events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
		n, _ := r.copy_events(&resumed.timeline, frame.tick, events[:])
		testing.expect_value(t, events[n - 1].value.reason, preserve ? net.Action_Reason.None : net.Action_Reason.Disconnected)
		net.server_step(&resumed)
		frame2, _ := r.current(&resumed.timeline)
		testing.expect(t, reflect.equal(frame.state, frame2.state))
	}
}

@(test)
checkpoint_corruption_bounds_content_and_roster_fail_transactionally :: proc(t: ^testing.T) {
	f: Fixture
	fixture_init(&f)
	defer fixture_destroy(&f)
	for _ in 0 ..< 30 {fixture_step(&f)}
	cp, decoded: Checkpoint
	defer net.checkpoint_destroy(&cp)
	defer net.checkpoint_destroy(&decoded)
	net.checkpoint_capture(&f.server, &cp)
	bytes, err := net.checkpoint_encode(&cp, model())
	defer delete(bytes)
	testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model(), 1), net.Error.Invalid_Checkpoint)
	for n in 0 ..< len(bytes) {
		testing.expect_value(t, net.checkpoint_decode(&decoded, bytes[:n], model(), f.server.cfg.content), net.Error.Invalid_Checkpoint)
		testing.expect(t, !decoded.ready && cap(decoded.peers) == 0)
	}
	bytes[len(bytes) - 1] ~= 1
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content), net.Error.Invalid_Checkpoint)
	bytes[len(bytes) - 1] ~= 1
	meta, fingerprint, _ := sc.inspect(bytes)
	hschema: sc.Schema
	defer sc.destroy(&hschema)
	sc.init(&hschema, net.Checkpoint_Header)
	header := cp.header
	header.inputs = max(u32)
	sc.encode(&hschema, header, bytes[sc.HEADER_BYTES:sc.HEADER_BYTES + hschema.wire_size])
	sc.pack_bytes(fingerprint, meta, bytes[sc.HEADER_BYTES:], bytes)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content), net.Error.Invalid_Checkpoint)
	testing.expect(t, !decoded.ready && cap(decoded.inputs) == 0)
	if len(cp.inputs) > 0 {
		append(&cp.inputs, cp.inputs[0])
		cp.header.inputs += 1
		testing.expect(t, !net.checkpoint_valid(&cp, model()))
		resize(&cp.inputs, len(cp.inputs) - 1)
		cp.header.inputs -= 1
	}
	cp.peers[1].seat = cp.peers[0].seat
	testing.expect(t, !net.checkpoint_valid(&cp, model()))
	resumed: Server
	defer net.server_destroy(&resumed)
	testing.expect_value(t, net.server_restore(&resumed, &cp, model(), {}, {epoch = 2}), net.Error.Invalid_Checkpoint)
	testing.expect(t, !resumed.initialized)
}

@(test)
checkpoint_restores_bans_policy_and_requires_a_new_authority_epoch :: proc(t: ^testing.T) {
	f: Fixture
	fixture_init(&f)
	defer fixture_destroy(&f)
	for _ in 0 ..< 30 {fixture_step(&f)}
	net.server_kick(&f.server, 1, true)
	f.server.admission = proc(user: rawptr, hash: [32]u8, spectator: bool) -> bool {return true}
	cp: Checkpoint
	defer net.checkpoint_destroy(&cp)
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.Checkpoint_Policy)
	policy := [3]u8{1, 2, 3}
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp, 77, policy[:]), net.Error.None)
	resumed: Server
	defer net.server_destroy(&resumed)
	testing.expect_value(t, net.server_restore(&resumed, &cp, model(), {}, {epoch = 1}), net.Error.Invalid_Config)
	testing.expect_value(t, net.server_restore(&resumed, &cp, model(), {}, {epoch = 2}), net.Error.Checkpoint_Policy)
	testing.expect_value(t, net.server_restore(&resumed, &cp, model(), {},
	                     {epoch = 2, policy_id = 77, admission = f.server.admission}), net.Error.None)
	testing.expect_value(t, resumed.banned_count, 1)
	testing.expect(t, resumed.banned[0] == f.server.banned[0])
	testing.expect(t, net.server_unban(&resumed, f.clients[0].token))
	testing.expect(t, !net.server_unban(&resumed, f.clients[0].token))
}

@(test)
checkpoint_fresh_clients_reclaim_seats_without_resetting_loot_or_accepting_old_traffic :: proc(t: ^testing.T) {
	f: Fixture
	fixture_init(&f)
	defer fixture_destroy(&f)
	f.server.model.reset_player = fresh_player
	for &client in f.clients {client.model.reset_player = fresh_player}
	for _ in 0 ..< 30 {fixture_step(&f)}
	net.client_issue(&f.clients[0], Action{take = true})
	for _ in 0 ..< 40 {fixture_step(&f)}
	net.server_set_locked(&f.server, true)
	cp: Checkpoint
	defer net.checkpoint_destroy(&cp)
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
	// Queue an old-epoch action, then replace the authority before delivery.
	net.client_issue(&f.clients[1], Action{take = true})
	definition := f.server.model
	net.server_destroy(&f.server)
	testing.expect_value(t, net.server_restore(&f.server, &cp, definition, tr.memory_transport(&f.endpoints[0]),
	                     {epoch = 2}), net.Error.None)
	for &client, i in f.clients {
		token := client.token
		net.client_destroy(&client)
		testing.expect_value(t, net.client_init(&client, definition, tr.memory_transport(&f.endpoints[i + 1]), token,
		                     spectator = i == 2, cfg = f.server.cfg), net.Error.None)
	}
	for _ in 0 ..< 60 {fixture_step(&f)}
	frame, _ := r.current(&f.server.timeline)
	testing.expect(t, frame.state.players[0].active && frame.state.players[1].active)
	testing.expect_value(t, frame.state.players[0].bag, u32(5))
	testing.expect_value(t, frame.state.chest, u32(0))
	testing.expect(t, f.server.stats.rejected_packets > 0)
	for &client, i in f.clients {
		testing.expect_value(t, client.phase, net.Phase.Running)
		testing.expect_value(t, client.seat, i == 2 ? u16(0) : u16(i + 1))
		testing.expect(t, client.generation > cp.header.generation)
		observed, _ := r.current(&client.timeline)
		testing.expect(t, reflect.equal(observed.state, frame.state))
	}
	sequence, err := net.client_issue(&f.clients[0], Action{take = true})
	testing.expect_value(t, sequence, u64(2))
	testing.expect_value(t, err, net.Error.None)
	for _ in 0 ..< 30 {fixture_step(&f)}
	frame, _ = r.current(&f.server.timeline)
	testing.expect_value(t, frame.state.players[0].bag, u32(5))
}

@(test)
checkpoint_host_token_cannot_reserve_a_second_seat :: proc(t: ^testing.T) {
	f: Fixture
	fixture_init(&f)
	defer fixture_destroy(&f)
	net.server_destroy(&f.server)
	testing.expect_value(t, net.server_init(&f.server, r.Frame(World){state = {chest = 5}}, model(),
	                     tr.memory_transport(&f.endpoints[0]), f.clients[0].cfg, local_seat = 1), net.Error.None)
	testing.expect_value(t, net.server_set_local_token(&f.server, f.clients[0].token), net.Error.None)
	for _ in 0 ..< 30 {fixture_step(&f)}
	testing.expect_value(t, f.clients[0].rejection, net.Reject.Token_In_Use)
	testing.expect_value(t, f.clients[1].seat, u16(2))
}

Private_World :: struct {visible: u32, secret: u64 `replay:"authority"`, scratch: f32}
private_model :: proc() -> net.Model(Private_World, Control, Action, Event, 2) {
	return {step = proc(w: ^Private_World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {w.secret += 1},
	        control_valid = control_valid, hold = hold, state_valid = proc(w: Private_World) -> bool {return w.secret > 0}}
}

@(test)
checkpoint_uses_complete_authority_projection_and_rejects_contract_changes :: proc(t: ^testing.T) {
	s: net.Server(Private_World, Control, Action, Event, 2)
	defer net.server_destroy(&s)
	net.server_init(&s, r.Frame(Private_World){state = {visible = 7, secret = 0x123456789}}, private_model(), {})
	cp, decoded: net.Checkpoint(Private_World, Control, Action, 2)
	defer net.checkpoint_destroy(&cp)
	defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
	bytes, err := net.checkpoint_encode(&cp, private_model())
	defer delete(bytes)
	testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, private_model(), 1), net.Error.None)
	testing.expect_value(t, decoded.frame.state.secret, u64(0x123456789))
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, private_model(), 1), net.Error.Wrong_Phase)
	resumed: net.Server(Private_World, Control, Action, Event, 2)
	defer net.server_destroy(&resumed)
	decoded.header.contract ~= 1
	testing.expect_value(t, net.server_restore(&resumed, &decoded, private_model(), {}, {epoch = 2}), net.Error.Checkpoint_Contract)
	testing.expect(t, !resumed.initialized)
	// Model validity and codec validity are separate. Failure after allocating the
	// archive must free its candidate buffer and return no partially encoded bytes.
	cp.frame.state.scratch = transmute(f32)u32(0x7fc00000)
	invalid_bytes, invalid_error := net.checkpoint_encode(&cp, private_model())
	testing.expect_value(t, invalid_error, net.Error.Invalid_Checkpoint)
	testing.expect_value(t, len(invalid_bytes), 0)
}
