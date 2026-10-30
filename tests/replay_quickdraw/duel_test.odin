package replay_quickdraw_test

import "core:math"
import "core:reflect"
import "core:testing"
import r "godot:replay"
import p "godot:replay/play"
import h "godot:replay/history"
import net "godot:replay/net"
import game "../../examples/replay_quickdraw/shared/duel"

joined :: proc() -> game.World {
	w := game.initial(true, true, 1)
	storage: [32]r.Occurrence(game.Event)
	ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	game.reset_player(&w, 1, &ctx); game.reset_player(&w, 2, &ctx)
	return w
}

@(test)
interpolated_historical_hit_live_miss_and_respawn_identity :: proc(t: ^testing.T) {
	w := joined()
	w.players[1].position = {580, 200}
	w.players[0].position = {60, 100}; h.record(&w.history, 10, game.hurtboxes(&w))
	w.players[0].position = {60, 200}; h.record(&w.history, 11, game.hurtboxes(&w))
	w.players[0].position = {60, 300}
	w.players[1].aim = game.aim(math.atan2(f32(-50), f32(-520)))
	live, respawned := w, w
	respawned.players[0].life += 1
	storage: [32]r.Occurrence(game.Event)
	view := net.View_Time{10, 11, 32768, .Historical}
	ctx := r.Step(game.Event){tick = 20, epoch = 1, events = storage[:]}
	game.shoot(&w, 1, view, game.hurtboxes(&w), &ctx)
	testing.expect_value(t, w.hits, u32(1)); testing.expect_value(t, w.players[0].hp, i32(2))
	live.rewind = false; ctx.count = 0
	game.shoot(&live, 1, view, game.hurtboxes(&live), &ctx)
	testing.expect_value(t, live.hits, u32(0))
	ctx.count = 0
	game.shoot(&respawned, 1, view, game.hurtboxes(&respawned), &ctx)
	testing.expect_value(t, respawned.hits, u32(0))
}

@(test)
history_miss_and_cover_never_fall_back_to_a_phantom_hit :: proc(t: ^testing.T) {
	w := joined()
	w.players[0].position, w.players[1].position = {60, 300}, {580, 300}
	w.players[1].aim = game.aim(math.PI)
	storage: [32]r.Occurrence(game.Event)
	ctx := r.Step(game.Event){tick = 40, epoch = 1, events = storage[:]}
	game.shoot(&w, 1, {1, 2, 0, .Historical}, game.hurtboxes(&w), &ctx)
	testing.expect_value(t, w.hits, u32(0)); testing.expect_value(t, w.expired_queries, u32(1))
	ctx.count = 0; w.players[0].position, w.players[1].position = {60, 100}, {580, 100}
	game.shoot(&w, 1, {40, 40, 0, .Live}, game.hurtboxes(&w), &ctx)
	testing.expect_value(t, w.hits, u32(0))
	h.record(&w.history, 1, game.hurtboxes(&w)); h.record(&w.history, 33, game.hurtboxes(&w))
	_, found := h.read(&w.history, 1); testing.expect(t, !found)
}

@(test)
dash_drone_cadence_boots_and_death_cooldowns_follow_authored_rules :: proc(t: ^testing.T) {
	w := joined()
	storage: [32]r.Occurrence(game.Event)
	input: [game.SEATS]game.Controls
	views: [game.SEATS]net.View_Time
	input[0] = {move = {1, 0}, drone = {-1, 0}, buttons = game.DASH | game.FIRE}
	ctx := r.Step(game.Event){tick = 2, epoch = 1, events = storage[:]}
	views[0] = {2, 2, 0, .Live}
	x, dx := w.players[0].position[0], w.players[0].drone[0]
	game.step(&w, input, views, 0, 0, &ctx)
	testing.expect_value(t, w.players[0].position[0], x + 7)
	testing.expect_value(t, w.players[0].drone[0], dx - 1.6)
	testing.expect_value(t, w.players[0].fire_cd, game.FIRE_CD - 1)
	input[0].move = {-1, 0}; input[0].buttons = 0
	ctx.tick, ctx.count = 3, 0
	game.step(&w, input, views, 0, 0, &ctx)
	testing.expect_value(t, w.players[0].velocity[0], f32(7))
	ctx.count = 0
	testing.expect(t, game.buy(&w, 1, {item = 1}, &ctx))
	testing.expect(t, !game.buy(&w, 1, {item = 1}, &ctx))
	testing.expect_value(t, w.players[0].gold, u8(0))
	w.players[0].hp = 0
	remaining := w.players[0].fire_cd
	ctx.tick, ctx.count = 4, 0; game.step(&w, input, views, 0, 0, &ctx)
	testing.expect_value(t, w.players[0].fire_cd, remaining)
}

@(test)
projectile_identity_is_independent_of_prediction_pool_slot :: proc(t: ^testing.T) {
	a := joined(); b := a
	r.pool_insert(&b.bullets, game.Bullet{key = 99, position = {100, 100}, life = 70, owner = 2})
	input: [game.SEATS]game.Controls; input[0].buttons = game.LOB
	storage: [32]r.Occurrence(game.Event)
	ctx := r.Step(game.Event){tick = 2, epoch = 1, events = storage[:]}
	game.step(&a, input, {}, 0, 0, &ctx)
	ctx.count = 0; game.step(&b, input, {}, 0, 0, &ctx)
	testing.expect_value(t, a.bullets.values[0].key, b.bullets.values[1].key)
	testing.expect(t, reflect.equal(a.bullets.values[0], b.bullets.values[1]))
}
