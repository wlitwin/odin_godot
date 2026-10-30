package replay_scrapyard_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
transition_deadlines_use_snapshot_ticks_and_cancel_without_local_history :: proc(t: ^testing.T) {
	w := clear_world()
	w.depart = {wind = 180, left = 180}
	testing.expect_value(t, flow.derive(&w, 50, 1).seconds, u32(3))
	w.depart.left = 120; testing.expect_value(t, flow.derive(&w, 90, 1).seconds, u32(2))
	w.depart.left = 1; testing.expect_value(t, flow.derive(&w, 5000, 1).seconds, u32(1))
	w.depart = {}; testing.expect_value(t, flow.derive(&w, 5000, 1).kind, flow.Kind.Clear)
	w.stage = .Yard; w.wave_count = 3; w.director = {wave = 1, rest_until = 221}
	view := flow.derive(&w, 100, 1)
	testing.expect_value(t, view.kind, flow.Kind.Rest); testing.expect_value(t, view.wave, u16(2)); testing.expect_value(t, view.seconds, u32(3))
	testing.expect_value(t, flow.derive(&w, 161, 1).seconds, u32(1))
	testing.expect_value(t, flow.derive(&w, 221, 1).kind, flow.Kind.Wave)
	w.director.wave = 3; testing.expect_value(t, flow.derive(&w, 100, 1).kind, flow.Kind.Securing)
	w.stage = .Over; w.players[0].kills, w.players[0].scrap, w.players[0].cores = 27, 17, 9
	view = flow.derive(&w, 100, 1)
	testing.expect(t, view.personal && view.kind == .Over && view.kills == 27 && view.scrap == 17 && view.cores == 9)
	testing.expect(t, !flow.derive(&w, 100, 0).personal)
}

@(test)
transition_views_reconstruct_from_real_checkpoints_at_a_new_epoch :: proc(t: ^testing.T) {
	Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
	Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
	for kind in ([4]flow.Kind{.Rest, .Clear, .Depart, .Over}) {
		w := clear_world()
		#partial switch kind {
		case .Rest: w.stage = .Yard; w.director = {rest_until = 211}
		case .Depart: w.depart = {wind = 180, left = 90}
		case .Over: w.stage = .Over; w.over_until = 240; w.players[0].hp = 0
		case:
		}
		w.players[0].kills, w.players[0].scrap, w.players[0].cores = 27, 17, 9
		server, restored: Server; defer net.server_destroy(&server); defer net.server_destroy(&restored)
		model := game.model(); model.reset_player = nil; config := net.DEFAULT_CONFIG; config.content = game.CONTENT
		testing.expect_value(t, net.server_init(&server, r.Frame(game.World){tick = 90, state = w}, model, {}, config, local_seat = 1), net.Error.None)
		net.server_set_local_token(&server, net.Token{0 = 47})
		point, decoded: Checkpoint; defer net.checkpoint_destroy(&point); defer net.checkpoint_destroy(&decoded)
		testing.expect_value(t, net.checkpoint_capture(&server, &point), net.Error.None)
		bytes, err := net.checkpoint_encode(&point, model); defer delete(bytes); testing.expect_value(t, err, net.Error.None)
		testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model, game.CONTENT), net.Error.None)
		testing.expect_value(t, net.server_restore(&restored, &decoded, model, {}, {epoch = 2, local_seat = 1}), net.Error.None)
		frame, ok := r.current(&restored.timeline); testing.expect(t, ok)
		view := flow.derive(&frame.state, frame.tick, 1)
		testing.expect_value(t, view.kind, kind); testing.expect(t, reflect.equal(view, flow.derive(&w, 90, 1)))
	}
}
