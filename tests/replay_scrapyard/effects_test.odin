package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
reaction_priority_transmute_and_shatter_preserve_actual_rules :: proc(t: ^testing.T) {
	w := yard(); w.clock = 1
	game.spawn_mob(&w, 1, {700, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	feedback: game.Notices; credit := game.Credit{1, 1}; target := game.mob_target(&w, 0)
	game.apply_status(&w, target, 1, credit, &feedback, &ctx)
	game.apply_status(&w, target, 3, credit, &feedback, &ctx)
	testing.expect_value(t, w.mobs.values[0].fx[0].kind, u8(7))
	testing.expect_value(t, game.status_multiplier(&w, w.mobs.values[0].fx[:], .Move), f32(0))
	game.apply_status(&w, target, 2, credit, &feedback, &ctx)
	testing.expect_value(t, w.mobs.values[0].hp, u16(0)); testing.expect_value(t, w.players[0].damage, u32(20))
	testing.expect_value(t, w.reactions, u32(2)); testing.expect_value(t, w.drops.count, u32(1))
	testing.expect(t, game.state_valid(w))
	// Effect slot order precedes table filename order: burn+chill douses first.
	w = yard(); w.clock = 1; game.spawn_mob(&w, 1, {700, 1040}); feedback = {}
	game.apply_status(&w, game.mob_target(&w, 0), 2, credit, &feedback, &ctx)
	game.apply_status(&w, game.mob_target(&w, 0), 1, credit, &feedback, &ctx)
	game.apply_status(&w, game.mob_target(&w, 0), 3, credit, &feedback, &ctx)
	testing.expect_value(t, w.mobs.values[0].fx[0].kind, u8(0)); testing.expect_value(t, w.mobs.values[0].fx[1].kind, u8(1))
}

@(test)
stacked_dot_refresh_credit_cannot_transfer_to_a_new_occupant :: proc(t: ^testing.T) {
	w := yard(); w.catalog.mobs[1].hp, w.catalog.mobs[1].speed = 100, 0
	w.players[1].connected, w.players[1].in_yard = true, true
	game.spawn_mob(&w, 1, {700, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}
	feedback: game.Notices
	for seat in ([3]u16{1, 1, 2}) {game.apply_status(&w, game.mob_target(&w, 0), 6, game.Credit{seat, 1}, &feedback, &ctx)}
	for tick in 1 ..= 30 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)}
	testing.expect_value(t, w.mobs.values[0].hp, u16(97)); testing.expect_value(t, w.players[1].damage, u32(3))
	w.players[1] = game.fresh_player(2, 2)
	for tick in 31 ..= 240 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)}
	testing.expect_value(t, w.mobs.values[0].hp, u16(79)); testing.expect_value(t, w.players[1].damage, u32(0))
	testing.expect(t, reflect.equal(w.mobs.values[0].fx[0], p.Effect{}) && reflect.equal(w.mobs.values[0].fx_credit[0], game.Credit{}))
	testing.expect_value(t, w.dot_pulses, u32(7)); testing.expect(t, game.state_valid(w))
}

@(test)
barrel_chain_counts_each_death_once_and_preserves_dot_credit :: proc(t: ^testing.T) {
	w := yard(); w.players[0].position = {680, 1040}
	w.catalog.mobs[1].hp, w.catalog.mobs[1].speed = 13, 0
	game.spawn_mob(&w, 5, {700, 1040}); game.spawn_mob(&w, 5, {760, 1040}); game.spawn_mob(&w, 1, {820, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}
	feedback: game.Notices
	game.wound_mob(&w, 0, 4, game.Credit{1, 1}, &feedback, &ctx)
	testing.expect_value(t, w.barrel_blasts, u32(2)); testing.expect_value(t, w.players[0].kills, u32(0))
	testing.expect_value(t, w.mobs.values[2].hp, u16(1)); testing.expect_value(t, w.mobs.values[2].fx[0].kind, u8(2))
	testing.expect_value(t, w.players[0].hp, u8(0)); testing.expect_value(t, w.drops.count, u32(0))
	for tick in 1 ..= 90 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)}
	testing.expect_value(t, w.players[0].kills, u32(1)); testing.expect_value(t, w.players[0].damage, u32(21))
	testing.expect_value(t, w.drops.count, u32(1)); testing.expect_value(t, w.barrel_blasts, u32(2))
	testing.expect(t, game.state_valid(w))
}

budget_step :: proc(w: ^game.World, input: u8, ctx: ^r.Step(game.Event)) {
	w.players[0].scrap += 1
	feedback := game.Notices{work = game.REACTION_WORK - 1}
	game.apply_status(w, game.mob_target(w, 0), 2, game.Credit{1, 1}, &feedback, ctx)
}

@(test)
dense_spread_consumes_primers_and_keeps_credit_within_work_budget :: proc(t: ^testing.T) {
	w := yard(); w.players[1].connected, w.players[1].in_yard = true, true
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}; feedback: game.Notices
	for i in 0 ..< game.MAX_MOBS {
		game.spawn_mob(&w, 1, {700 + f32(i % 8) * 3, 950 + f32(i / 8) * 3})
		game.apply_status(&w, game.mob_target(&w, i), 1, game.Credit{1, 1}, &feedback, &ctx)
	}
	game.apply_status(&w, game.mob_target(&w, 0), 6, game.Credit{2, 1}, &feedback, &ctx)
	testing.expect_value(t, ctx.error, r.Error.None); testing.expect(t, feedback.work < game.REACTION_WORK)
	testing.expect_value(t, w.reactions, u32(game.MAX_MOBS))
	for mob in w.mobs.values {
		active := 0
		for effect, slot in mob.fx {if effect.kind != 0 {
			active += 1; testing.expect_value(t, effect.kind, u8(6)); testing.expect(t, effect.power <= 3)
			testing.expect_value(t, mob.fx_credit[slot].seat, u16(2))
		}}
		testing.expect_value(t, active, 1)
	}
	testing.expect(t, game.state_valid(w))
}

@(test)
runner_modifiers_and_remaining_clock_pulses_match_the_rulebook :: proc(t: ^testing.T) {
	w := yard()
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}; feedback: game.Notices
	game.apply_status(&w, game.player_target(&w, 0), 7, game.Credit{1, 1}, &feedback, &ctx)
	before := w.players[0].position
	controls: [game.SEATS]game.Control; controls[0].move = {1, 0}
	ctx.tick = 1; game.step(&w, controls, 0, 0, &ctx)
	testing.expect_value(t, w.players[0].position, before)
	controls[0].dash = true; ctx.tick, ctx.count = 2, 0; game.step(&w, controls, 0, 0, &ctx)
	testing.expect(t, w.players[0].position[0] > before[0]) // original dash bypasses move modifiers
	w = yard(); w.players[0].hp = 8; feedback = {}
	game.apply_status(&w, game.player_target(&w, 0), 8, game.Credit{1, 1}, &feedback, &ctx)
	for tick in 1 ..< 15 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)}
	testing.expect_value(t, w.players[0].hp, u8(8))
	ctx.tick, ctx.count = 15, 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
	testing.expect_value(t, w.players[0].hp, u8(9)) // 600 remaining ticks first reaches a multiple of 45 after 15 ticks
	testing.expect_value(t, game.status_multiplier(&w, w.players[0].fx[:], .Dealt), f32(1.5))
	testing.expect(t, game.state_valid(w))
}

@(test)
authored_cycles_stop_at_depth_and_work_exhaustion_rolls_back :: proc(t: ^testing.T) {
	w := yard(); game.spawn_mob(&w, 1, {700, 1040})
	w.catalog.combos[0] = {present = 1, incoming = 2, reaction = .Transmute, output = 2, consume = false}
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}; feedback: game.Notices
	game.apply_status(&w, game.mob_target(&w, 0), 1, game.Credit{1, 1}, &feedback, &ctx)
	before := w
	game.apply_status(&w, game.mob_target(&w, 0), 2, game.Credit{1, 1}, &feedback, &ctx)
	testing.expect_value(t, w.reactions, u32(game.CHAIN_DEPTH)); testing.expect_value(t, w.mobs.values[0].fx[1].kind, u8(2))
	testing.expect_value(t, ctx.error, r.Error.None)
	timeline: r.Timeline(game.World, u8, game.Event)
	r.init(&timeline, r.Frame(game.World){state = before}, budget_step); defer r.destroy(&timeline)
	testing.expect_value(t, r.advance(&timeline, u8(0)).error, r.Error.Aborted)
	frame, _ := r.current(&timeline); testing.expect(t, reflect.equal(frame.state, before))
}
