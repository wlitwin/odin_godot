package replay_net_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"

// Exercise the public presentation/input path; the server must resolve the
// actual transmitted hint using its own sent-snapshot history.
send_view :: proc(f: ^Fixture, stamp: net.View_Stamp) -> u64 {
	c := &f.clients[0]
	c.presented = stamp
	tick := c.timeline.head + 1
	assert(net.client_step(c, Control{move = 1}) == .None)
	assert(tr.memory_advance(&f.network, f.clock))
	assert(net.server_pump(&f.server, f.clock * 1000 / 60) == .None)
	return tick
}

@(test)
aim_keeps_its_drawn_bracket_across_new_snapshot_delivery :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	for _ in 0 ..< 50 {fixture_step(&f, true)}
	a, b, alpha, ok := net.client_present(&f.clients[0])
	testing.expect(t, ok)
	stamp := f.clients[0].presented
	testing.expect_value(t, stamp.from_tick, a.tick); testing.expect_value(t, stamp.to_tick, b.tick)
	testing.expect_value(t, alpha, f32(stamp.fraction) / 65535)
	for _ in 0 ..< 2 {fixture_step(&f)} // pump newer snapshots without drawing them
	testing.expect_value(t, f.clients[0].presented, stamp)
	tick := send_view(&f, stamp)
	for f.server.timeline.head < tick {fixture_step(&f)}
	input, found := r.read_input(&f.server.timeline, tick)
	testing.expect(t, found)
	testing.expect_value(t, input.views[0], net.View_Time{a.tick, b.tick, stamp.fraction, .Historical})
	testing.expect_value(t, input.controls[0].move, i8(1))
}

@(test)
forged_future_and_expired_views_do_not_discard_valid_movement :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	for _ in 0 ..< 50 {fixture_step(&f)}
	for scenario in 0 ..< 3 {
		_, _, _, ok := net.client_present(&f.clients[0]); testing.expect(t, ok)
		stamp := f.clients[0].presented
		expected := net.View_Status.Invalid
		switch scenario {
		case 0: stamp.from_id = max(u64) // an ID this peer was never sent
		case 1: stamp.to_tick = f.server.timeline.head + 100
		case 2:
			// A real, retained Welcome can still be too old to authorize rewind.
			stamp = {from_tick = f.server.peers[0].welcome_view.tick, to_tick = f.server.peers[0].welcome_view.tick, valid = true}
			expected = .Expired
		}
		tick := send_view(&f, stamp)
		for f.server.timeline.head < tick {fixture_step(&f)}
		input, found := r.read_input(&f.server.timeline, tick)
		testing.expect(t, found); testing.expect_value(t, input.views[0].status, expected)
		testing.expect_value(t, input.controls[0].move, i8(1))
	}
	testing.expect(t, f.server.stats.rejected_views >= 2 && f.server.stats.expired_views > 0)
	testing.expect_value(t, f.server.stats.rejected_inputs, u64(0))
}

@(test)
checkpoint_roundtrips_validated_views_and_retires_disconnected_control_stream :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	for _ in 0 ..< 50 {fixture_step(&f)}
	net.client_present(&f.clients[0])
	stamp := f.clients[0].presented
	tick := send_view(&f, stamp)
	cp, decoded: Checkpoint
	defer net.checkpoint_destroy(&cp); defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
	bytes, err := net.checkpoint_encode(&cp, model()); defer delete(bytes)
	testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content), net.Error.None)
	resumed: Server; defer net.server_destroy(&resumed)
	testing.expect_value(t, net.server_restore(&resumed, &decoded, model(), {}, {epoch = 2, retain_membership = true, preserve_pending = true}), net.Error.None)
	slot := resumed.inputs[int(tick % u64(resumed.cfg.history))]
	testing.expect_value(t, slot.tick, tick)
	testing.expect_value(t, slot.view, net.View_Time{stamp.from_tick, stamp.to_tick, stamp.fraction, .Historical})
	testing.expect_value(t, slot.value.move, i8(1))
	// The archive retains accepted context, but a disconnected transport does
	// not execute its old stream. Reconnect establishes fresh generation/inputs.
	for resumed.timeline.head < tick {testing.expect_value(t, net.server_step(&resumed), net.Error.None)}
	input, found := r.read_input(&resumed.timeline, tick)
	testing.expect(t, found)
	testing.expect_value(t, input.views[0].status, net.View_Status.Unavailable)
	testing.expect_value(t, input.controls[0].move, i8(0))
	changed := false
	for &pending in cp.inputs {if pending.tick == tick && pending.peer == 0 {
		pending.view.to = cp.frame.tick + 1; changed = true; break
	}}
	testing.expect(t, changed); testing.expect(t, !net.checkpoint_valid(&cp, model()))
}

@(test)
observed_clock_catches_up_without_making_an_overwide_view_or_rewriting_old_aim :: proc(t: ^testing.T) {
	f: Fixture; fixture_init(&f); defer fixture_destroy(&f)
	for _ in 0 ..< 80 {fixture_step(&f, true)}
	c := &f.clients[0]
	_, _, _, ready := net.client_present(c); testing.expect(t, ready)
	old_aim := c.presented
	latest := c.authority_frame.tick; latest_slot := int(latest % u64(c.cfg.history))
	old_slot := -1
	for frame, i in c.observed {if c.observed_valid[i] && frame.tick + u64(c.cfg.max_view_span) + 2 < latest {old_slot = i; break}}
	testing.expect(t, old_slot >= 0); if old_slot < 0 {return}
	for &valid, i in c.observed_valid {valid = i == old_slot || i == latest_slot}
	c.watch_clock = f64(c.observed[old_slot].tick) + 0.5
	testing.expect_value(t, net.client_pump(c, c.now), net.Error.None)
	testing.expect(t, c.watch_clock >= f64(latest - u64(c.cfg.watch_delay + c.cfg.view_slack)))
	testing.expect_value(t, c.presented, old_aim) // already captured aiming context is immutable
	a, b, _, ok := net.client_present(c); testing.expect(t, ok)
	testing.expect(t, b.tick - a.tick <= u64(c.cfg.max_view_span))
	testing.expect_value(t, a.tick, latest); testing.expect_value(t, b.tick, latest)
}
