package replay_transfer_test

import "core:testing"
import rec "godot:replay/recovery"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

@(test)
gameplay_recovery_and_application_transfers_have_distinct_consumers :: proc(t: ^testing.T) {
	m: tr.Memory; tr.memory_init(&m, cfg = {2, 16, 65536, 128}); defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint; tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b); defer tr.close(&wa); defer tr.close(&wb)
	l: rec.Link(u64, u8, u8, u8, 2); defer rec.link_destroy(&l)
	cfg := rec.DEFAULT_LINK_CONFIG
	cfg.application_handles = proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool {return tf.handles(bytes)}
	testing.expect(t, rec.link_init(&l, wb, cfg))
	game := [3]u8{1, 2, 3}; tr.send(&wa, 2, .Reliable, game[:])
	content := packet(game[:], 1); defer delete(content)
	old, application: tf.Sender; defer tf.sender_destroy(&old); defer tf.sender_destroy(&application)
	testing.expect_value(t, rec.sender_init(&old, SCOPE, 2, wa, archive_kind = PAYLOAD_KIND), tf.Error.None)
	testing.expect_value(t, tf.sender_init(&application, SCOPE, 2, wa, archive_kind = PAYLOAD_KIND), tf.Error.None)
	tf.sender_begin(&old, content, 0); tf.sender_begin(&application, content, 0)
	tf.sender_update(&old, 0); tf.sender_update(&application, 0)
	tr.memory_advance(&m, 1); testing.expect(t, rec.link_pump(&l, 1))
	primary, background, app := rec.link_game_transport(&l), l.background, rec.link_application_transport(&l)
	buffer: [1200]u8
	testing.expect_value(t, tr.receive(&primary, buffer[:]).count, 3)
	p := tr.receive(&background, buffer[:]); testing.expect_value(t, p.state, tr.Receive_State.Received)
	testing.expect(t, rec.handles(buffer[:p.count]) && !tf.handles(buffer[:p.count]))
	p = tr.receive(&app, buffer[:]); testing.expect_value(t, p.state, tr.Receive_State.Received)
	testing.expect(t, tf.handles(buffer[:p.count]) && !rec.handles(buffer[:p.count]))
	testing.expect_value(t, tr.receive(&primary, buffer[:]).state, tr.Receive_State.Empty)
}
