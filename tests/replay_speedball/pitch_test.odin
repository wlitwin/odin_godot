package replay_speedball_test

import "core:reflect"
import "core:testing"
import "core:math"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import v "godot:replay/view"
import game "../../examples/replay_speedball/shared/pitch"

ready_world :: proc() -> game.World {
	w := game.initial(goals_to = 1)
	ctx := r.Step(game.Event){}
	game.reset_player(&w, 1, &ctx); game.reset_player(&w, 2, &ctx)
	w.started, w.ball.hold = true, 0
	return w
}

@(test)
motion_bounce_speed_cap_and_goal_crossing_match_authored_order :: proc(t: ^testing.T) {
	m := p.Motion2{position = {100, 100}}
	p.momentum_step(&m, {2.2, 0}, 0.35, game.PLAYER_BOUNDS)
	testing.expect_value(t, m.velocity[0], f32(2.2) * 0.35)
	w := ready_world(); w.ball.motion = {position = {619, 180}, velocity = {30, 0}}
	storage: [32]r.Occurrence(game.Event)
	ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	game.step(&w, {}, 0, 0, &ctx)
	testing.expect_value(t, w.ball.motion.position[0], f32(620))
	testing.expect(t, math.abs(w.ball.motion.velocity[0] + 4.95) < 0.00001)
	testing.expect_value(t, w.score.left, u8(0)) // crossing is judged on the next tick
	ctx.tick, ctx.count = 2, 0; game.step(&w, {}, 0, 0, &ctx)
	testing.expect_value(t, w.score.left, u8(1)); testing.expect_value(t, w.score.winner, u8(1))
	testing.expect_value(t, w.ball.motion.position, game.CENTER)
	testing.expect_value(t, w.ball.hold, game.KICKOFF_HOLD)
	testing.expect_value(t, ctx.count, 1)
}

@(test)
simultaneous_opposed_kicks_share_one_world_and_exact_cooldown :: proc(t: ^testing.T) {
	w := ready_world()
	w.players[0].motion.position, w.players[1].motion.position = {300, 180}, {340, 180}
	input: [game.SEATS]game.Controls
	input[0].buttons, input[1].buttons = game.KICK, game.KICK
	storage: [32]r.Occurrence(game.Event)
	ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	game.step(&w, input, 0, 0, &ctx)
	testing.expect_value(t, w.kicks, u32(2)); testing.expect_value(t, w.ball.motion.velocity, [2]f32{})
	testing.expect_value(t, ctx.count, 2)
	for tick in 2 ..= 20 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, input, 0, 0, &ctx)}
	testing.expect_value(t, w.kicks, u32(2))
	ctx.tick, ctx.count = 21, 0; game.step(&w, input, 0, 0, &ctx)
	testing.expect_value(t, w.kicks, u32(4))
}

local_step :: proc(w: ^game.World, c: [game.SEATS]game.Controls, ctx: ^r.Step(game.Event)) {game.step(w, c, 0, 0, ctx)}

@(test)
revoking_a_predicted_kick_rewinds_goal_score_reset_and_cooldown :: proc(t: ^testing.T) {
	w := ready_world(); w.ball.motion.position = {610, 180}; w.players[0].motion.position = {590, 180}
	a, b: r.Timeline(game.World, [game.SEATS]game.Controls, game.Event)
	defer r.destroy(&a); defer r.destroy(&b)
	r.init(&a, r.Frame(game.World){state = w}, local_step); r.init(&b, r.Frame(game.World){state = w}, local_step)
	for tick in 1 ..= 10 {
		c: [game.SEATS]game.Controls; if tick == 1 {c[0].buttons = game.KICK}
		testing.expect_value(t, r.advance(&a, c).error, r.Error.None)
		testing.expect_value(t, r.advance(&b, [game.SEATS]game.Controls{}).error, r.Error.None)
	}
	predicted, _ := r.current(&a); testing.expect_value(t, predicted.state.score.winner, u8(1))
	testing.expect_value(t, r.revise_input(&a, 1, [game.SEATS]game.Controls{}).error, r.Error.None)
	revised, _ := r.current(&a); reference, _ := r.current(&b)
	testing.expect(t, reflect.equal(revised, reference))
	testing.expect_value(t, revised.state.score.winner, u8(0)); testing.expect_value(t, revised.state.ball.reset, u32(0))
}

@(test)
spike_uses_authoritative_reach_and_two_queued_commands_settle_once :: proc(t: ^testing.T) {
	w := ready_world(); w.players[0].motion.position = {100, 100}
	ctx := r.Step(game.Event){}
	testing.expect(t, !game.spike(&w, 1, {spike = true}, &ctx))
	testing.expect_value(t, w.spikes, u32(0))
	s: net.Server(game.World, game.Controls, game.Action, game.Event, game.SEATS)
	defer net.server_destroy(&s)
	w.players[0].motion.position = {350, 180}
	net.server_init(&s, r.Frame(game.World){state = w}, game.model(), {}, local_seat = 1)
	// Consume the initial fresh-seat join, then install a local reference frame
	// with authored positions for the command range scenario.
	net.server_step(&s)
	frame, _ := r.current(&s.timeline); frame.state.players[0].motion.position = {350, 180}
	r.reset_checkpoint(&s.timeline, frame, 2); s.cfg.epoch = 2
	net.server_issue(&s, game.Action{spike = true}); net.server_issue(&s, game.Action{spike = true})
	for _ in 0 ..< 3 {testing.expect_value(t, net.server_step(&s), net.Error.None)}
	frame, _ = r.current(&s.timeline)
	testing.expect_value(t, frame.state.spikes, u32(2))
}

@(test)
correction_smoothing_preserves_motion_and_cuts_goal_discontinuity :: proc(t: ^testing.T) {
	s: v.Smoother2
	v.smooth_present(&s, {position = {100, 100}}, 0)
	v.smooth_correct(&s, {100, 100}, {90, 100})
	shown := v.smooth_present(&s, {position = {92, 100}}, 0)
	testing.expect_value(t, shown.position, [2]f32{102, 100}) // ordinary two-pixel motion remains
	v.smooth_correct(&s, {92, 100}, game.CENTER, discontinuity = true)
	shown = v.smooth_present(&s, {position = game.CENTER}, 0)
	testing.expect_value(t, shown.position, game.CENTER)
}

@(test)
manual_pitch_waits_for_host_and_profiles_follow_the_issuing_seat :: proc(t:^testing.T) {
 w:=game.initial(min_players=2,manual_start=true);ctx:=r.Step(game.Event){tick=1}
 game.step(&w,{},3,0,&ctx);testing.expect(t,!w.started)
 before:=w;testing.expect(t,!game.action(&w,2,{start=true},&ctx));testing.expect(t,reflect.equal(w,before))
 testing.expect(t,game.action(&w,1,{name={bytes={0='A'},length=1}},&ctx))
 testing.expect(t,game.action(&w,2,{name={bytes={0='B'},length=1}},&ctx))
 testing.expect_value(t,w.names[0].bytes[0],u8('A'));testing.expect_value(t,w.names[1].bytes[0],u8('B'))
 testing.expect(t,game.action(&w,1,{start=true},&ctx));testing.expect(t,w.started)
 testing.expect(t,!game.action(&w,1,{start=true},&ctx))
 testing.expect(t,!game.action_valid({start=true,spike=true}))
 testing.expect(t,game.state_valid(w))
}

@(test)
manual_match_leadership_survives_handoff_and_follows_roster_loss :: proc(t:^testing.T) {
 w:=game.initial(min_players=2,manual_start=true);ctx:=r.Step(game.Event){tick=1}
 game.step(&w,{},7,0,&ctx)
 testing.expect_value(t,game.leader(w),u16(1))
 // Network authority replacement does not mutate the game roster or leader.
 before:=w;testing.expect(t,!game.action(&w,2,{start=true},&ctx));testing.expect(t,reflect.equal(w,before))
 ctx.tick=2;game.step(&w,{},0,1,&ctx)
 testing.expect_value(t,game.leader(w),u16(2))
 testing.expect(t,!game.action(&w,3,{start=true},&ctx))
 testing.expect(t,game.action(&w,2,{start=true},&ctx))
 testing.expect(t,w.started && game.state_valid(w))
}

@(test)
restart_is_leader_scoped_preserves_roster_and_rejects_stale_rounds :: proc(t:^testing.T) {
 w:=ready_world();ctx:=r.Step(game.Event){tick=100}
 w.clock=100;w.names[0]={bytes={0='A'},length=1};w.players[0].named=true
 w.players[1].connected=false;w.players[1].kick_cd=10
 before:=w
 testing.expect(t,!game.action(&w,1,{restart_round=1},&ctx));testing.expect(t,reflect.equal(w,before))
 w.score={left=1,winner=1};w.ball.reset=1;w.kicks,w.spikes,w.contacts=5,2,9
 before=w
 testing.expect(t,!game.action(&w,2,{restart_round=1},&ctx));testing.expect(t,reflect.equal(w,before))
 testing.expect(t,!game.action_valid({start=true,restart_round=1}))
 testing.expect(t,game.action(&w,1,{restart_round=1},&ctx));testing.expect(t,game.state_valid(w))
 testing.expect_value(t,w.round,u32(2));testing.expect_value(t,w.clock,u64(100))
 testing.expect(t,w.started && w.players[0].connected && w.players[0].named && !w.players[1].connected)
 testing.expect_value(t,w.names,before.names);testing.expect_value(t,w.score,game.Score{})
 testing.expect_value(t,w.ball.motion.position,game.CENTER);testing.expect_value(t,w.ball.hold,game.KICKOFF_HOLD)
 testing.expect_value(t,w.kicks+w.spikes+w.contacts,u32(0));testing.expect_value(t,w.players[1].kick_cd,u16(0))
 w.score={left=1,winner=1};w.ball.reset=1;before=w
 testing.expect(t,!game.action(&w,1,{restart_round=1},&ctx));testing.expect(t,reflect.equal(w,before))
 w.min_players=2;testing.expect(t,!game.action(&w,1,{restart_round=2},&ctx))
 w.min_players=1;w.round=max(u32);testing.expect(t,!game.action(&w,1,{restart_round=max(u32)},&ctx))
}

restart_step :: proc(w:^game.World,a:game.Action,ctx:^r.Step(game.Event)) {game.action(w,1,a,ctx);game.step(w,{},0,0,ctx)}
@(test)
revoked_restart_restores_completed_match_and_replays_exactly :: proc(t:^testing.T) {
 w:=ready_world();w.score={left=1,winner=1};w.ball.reset=1
 a,b:r.Timeline(game.World,game.Action,game.Event);defer r.destroy(&a);defer r.destroy(&b)
 r.init(&a,r.Frame(game.World){state=w},restart_step);r.init(&b,r.Frame(game.World){state=w},restart_step)
 for tick in 1..=8 {
  testing.expect_value(t,r.advance(&a,game.Action{restart_round=tick==1 ? 1 : 0}).error,r.Error.None)
  testing.expect_value(t,r.advance(&b,game.Action{}).error,r.Error.None)
 }
 frame,_:=r.current(&a);testing.expect_value(t,frame.state.round,u32(2))
 testing.expect_value(t,r.revise_input(&a,1,game.Action{}).error,r.Error.None)
 revised,_:=r.current(&a);reference,_:=r.current(&b)
 testing.expect(t,reflect.equal(revised,reference));testing.expect_value(t,revised.state.score.winner,u8(1))
}
