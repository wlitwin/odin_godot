package replay_view_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import v "godot:replay/view"
import game "../../examples/replay_hello/shared/hello"

@(test)
actual_hello_game_correction_cancels_the_projectile_effect :: proc(t: ^testing.T) {
	tl: game.Timeline
	r.init(&tl, r.Frame(game.World){state = game.initial()}, game.step)
	defer r.destroy(&tl)
	j: v.Journal(game.Event)
	v.journal_init(&j)
	defer v.journal_destroy(&j)
	input: game.Input
	input.players[0].fire = true
	r.advance(&tl, input)
	events: [32]r.Occurrence(game.Event)
	n, _ := r.copy_events(&tl, 1, events[:])
	v.sync_tick(&j, 1, events[:n])
	out: [4]v.Change(game.Event)
	testing.expect_value(t, v.drain(&j, out[:]), 1)
	testing.expect_value(t, out[0].kind, v.Change_Kind.Begin)
	r.advance(&tl, game.Input{})
	v.sync_tick(&j, 2, nil)
	r.advance(&tl, game.Input{})
	v.sync_tick(&j, 3, nil)
	testing.expect_value(t, r.revise_input(&tl, 1, game.Input{}).error, r.Error.None)
	n, _ = r.copy_events(&tl, 1, events[:])
	testing.expect_value(t, v.sync_tick(&j, 1, events[:n]), v.Error.None)
	testing.expect_value(t, v.drain(&j, out[:]), 1)
	testing.expect_value(t, out[0].kind, v.Change_Kind.Cancel)
	frame, _ := r.current(&tl)
	testing.expect_value(t, frame.state.shots, u32(0))
	testing.expect_value(t, frame.state.actors.count, u32(2))
	testing.expect_value(t, r.confirm_through(&tl, 3), r.Error.None)
	testing.expect_value(t, v.advance_time(&j, 3, 3), v.Error.None)
	testing.expect_value(t, r.revise_input(&tl, 1, input).error, r.Error.Committed)
	testing.expect_value(t, r.rewind(&tl, 2), r.Error.Committed)
	testing.expect_value(t, r.confirm_through(&tl, 2), r.Error.Time_Reversed)
	after, _ := r.current(&tl)
	testing.expect(t, reflect.equal(frame, after))
	testing.expect_value(t, r.audit(&tl, 1).error, r.Error.None)
}

@(test)
historical_frame_sampling_is_detached_and_never_extrapolates :: proc(t: ^testing.T) {
	tl: game.Timeline
	r.init(&tl, r.Frame(game.World){state = game.initial()}, game.step)
	defer r.destroy(&tl)
	input: game.Input
	input.players[0].move[0] = 1
	r.advance(&tl, input)
	a, b, alpha, ok := v.frames_at(&tl, 0, 0.5)
	testing.expect(t, ok)
	testing.expect_value(t, alpha, f32(0.5))
	testing.expect_value(t, a.tick, u64(0))
	testing.expect_value(t, b.tick, u64(1))
	b.state.shots = 99
	stored, _ := r.current(&tl)
	testing.expect_value(t, stored.state.shots, u32(0))
	a, b, alpha, ok = v.frames_at(&tl, 1, 0.8)
	testing.expect(t, ok && reflect.equal(a, b))
	testing.expect_value(t, alpha, f32(0))
	_, _, _, ok = v.frames_at(&tl, 2, 0)
	testing.expect(t, !ok)
}
