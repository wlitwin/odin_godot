package replay_net_test

import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import r "godot:replay"

Identity_Check :: struct {hash: [32]u8, incarnation: u64}
identity_allowed :: proc(user: rawptr, hash: [32]u8, incarnation: u64) -> bool {
	check := cast(^Identity_Check)user
	return hash != check.hash || incarnation == check.incarnation
}

@(test)
new_validated_incarnation_reclaims_its_reserved_seat_and_fences_old_packets :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	check := Identity_Check{net.token_hash(f.clients[0].token), 5}
	f.server.identity_user, f.server.identity_check = &check, identity_allowed
	f.clients[0].incarnation = 5
	for _ in 0 ..< 30 {fixture_step(&f)}
	net.client_issue(&f.clients[0], Action{take = true})
	for _ in 0 ..< 40 {fixture_step(&f)}
	before, _ := net.server_seat_connection(&f.server, 1)
	testing.expect_value(t, before.incarnation, u64(5))
	check.incarnation = 6
	// A different still-live connection returns with the same player token and
	// the coordinator-approved newer process identity.
	net.client_destroy(&f.clients[2])
	old_wire := tr.memory_transport(&f.endpoints[3]); tr.close(&old_wire)
	net.server_pump(&f.server, f.clock * 1000 / 60)
	tr.memory_open(&f.network, &f.endpoints[3], 4)
	net.client_init(&f.clients[2], model(), tr.memory_transport(&f.endpoints[3]), f.clients[0].token,
	                cfg = f.server.cfg, incarnation = 6)
	for _ in 0 ..< 40 {fixture_step(&f)}
	connection, live := net.server_seat_connection(&f.server, 1)
	testing.expect(t, live)
	testing.expect_value(t, connection.peer, tr.Peer_Id(4))
	testing.expect_value(t, connection.incarnation, u64(6))
	testing.expect(t, connection.generation > before.generation)
	frame, _ := r.current(&f.server.timeline)
	testing.expect_value(t, frame.state.players[0].bag, u32(5))
	testing.expect_value(t, frame.state.chest, u32(0))
	// The old identity cannot rejoin merely by replaying the player credential.
	net.client_reconnect(&f.clients[0], tr.memory_transport(&f.endpoints[1]))
	for _ in 0 ..< 30 {fixture_step(&f)}
	testing.expect_value(t, f.clients[0].rejection, net.Reject.Denied)
	cp: Checkpoint; defer net.checkpoint_destroy(&cp)
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
	found := false
	for peer in cp.peers {if peer.seat == 1 {found = peer.incarnation == 6}}
	testing.expect(t, found)
}
