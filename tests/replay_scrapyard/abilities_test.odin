package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
ability_gate_capacity_and_aim_conventions_are_explicit :: proc(t: ^testing.T) {
	w := yard(); w.clock = 1
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	before := w
	testing.expect(t, !game.cast_ability(&w, 1, 2, {1, 0}, false, &ctx) && reflect.equal(w, before))
	testing.expect(t, !game.cast_ability(&w, 1, 0, {2, 0}, false, &ctx) && reflect.equal(w, before))
	testing.expect(t, game.cast_ability(&w, 1, 0, {1, 0}, false, &ctx))
	testing.expect_value(t, w.lobs.values[0].position, [2]f32{514, 1040})
	testing.expect_value(t, w.lobs.values[0].left, u16(21))
	testing.expect_value(t, w.players[0].ability_cd[0].remaining, u32(300))
	accepted := w
	testing.expect(t, !game.cast_ability(&w, 1, 0, {1, 0}, false, &ctx) && reflect.equal(w, accepted))
	w = before
	testing.expect(t, game.cast_ability(&w, 1, 0, {65000, 1040}, true, &ctx))
	testing.expect(t, reflect.equal(w.lobs, accepted.lobs))
	w = before
	for _ in 0 ..< game.MAX_LOBS {r.pool_insert(&w.lobs, game.Lob{position = {600, 1040}, velocity = {1, 0}, left = 10, ability = 1, credit = {1, 1}, serial = 1})}
	full := w
	testing.expect(t, !game.cast_ability(&w, 1, 0, {1, 0}, false, &ctx) && reflect.equal(w, full))
}

@(test)
lob_and_cone_form_a_credited_cross_player_reaction :: proc(t: ^testing.T) {
	w := yard(); w.players[1].connected, w.players[1].in_yard, w.players[1].position = true, true, {700, 1040}
	w.catalog.mobs[1].speed = 0; game.spawn_mob(&w, 1, {560, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}
	testing.expect(t, game.cast_ability(&w, 1, 0, {560, 1040}, true, &ctx))
	for tick in 1 ..= 3 {ctx.tick, ctx.count = u64(tick), 0; game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)}
	testing.expect_value(t, w.lobs_landed, u32(1)); testing.expect_value(t, w.mobs.values[0].fx[0].kind, u8(1))
	testing.expect(t, game.cast_ability(&w, 2, 1, {-1, 0}, false, &ctx))
	testing.expect_value(t, ctx.error, r.Error.None)
	testing.expect_value(t, w.reactions, u32(1)); testing.expect_value(t, w.mobs.values[0].hp, u16(4))
	testing.expect_value(t, w.players[1].damage, u32(16)); testing.expect_value(t, w.players[0].hp, u8(0))
	testing.expect(t, game.state_valid(w))
}

@(test)
nova_and_buff_use_the_authored_targeting_rules :: proc(t: ^testing.T) {
	w := yard(); w.players[0].profile.abilities = {3, 4}
	game.spawn_mob(&w, 0, {600, 1040}); game.spawn_mob(&w, 0, {800, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}
	testing.expect(t, game.cast_ability(&w, 1, 0, {0, 0}, false, &ctx))
	testing.expect_value(t, w.mobs.values[0].fx[0].kind, u8(3)); testing.expect_value(t, w.mobs.values[1].fx[0].kind, u8(0))
	testing.expect(t, game.cast_ability(&w, 1, 1, {0, 0}, false, &ctx))
	testing.expect_value(t, game.status_multiplier(&w, w.players[0].fx[:], .Dealt), f32(1.5))
	// A modified Buff row targets the nearest living friend, retaining self fallback.
	w = yard(); w.catalog.abilities[4].self_buff = false; w.players[0].profile.abilities[0] = 4
	for i in 1 ..= 2 {w.players[i].connected, w.players[i].in_yard = true, true; w.players[i].position = {500 + f32(i) * 30, 1040}}
	testing.expect(t, game.cast_ability(&w, 1, 0, {1, 0}, false, &ctx))
	testing.expect_value(t, w.players[0].fx[0].kind, u8(0)); testing.expect_value(t, w.players[1].fx[0].kind, u8(4)); testing.expect_value(t, w.players[2].fx[0].kind, u8(0))
}

@(test)
cast_feedback_folds_into_the_same_ticks_projectile_feedback :: proc(t: ^testing.T) {
	w := yard(); w.catalog.mobs[1].speed = 0; game.spawn_mob(&w, 1, {620, 1040})
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){epoch = 1, events = storage[:]}; feedback: game.Notices
	game.apply_status(&w, game.mob_target(&w, 0), 1, game.Credit{1, 1}, &feedback, &ctx)
	r.pool_insert(&w.shots, game.Shot{seat = 1, generation = 1, serial = 1, position = {610, 1040}, velocity = {1, 0}, ttl = 2, damage = 1})
	Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
	s: Server; defer net.server_destroy(&s); model := game.model(); model.reset_player = nil
	testing.expect_value(t, net.server_init(&s, r.Frame(game.World){state = w}, model, {}, local_seat = 1), net.Error.None)
	net.server_issue(&s, game.Action{kind = .Cast, slot = 1, aim = {1, 0}})
	testing.expect_value(t, net.server_step(&s), net.Error.None)
	frame, _ := r.current(&s.timeline); testing.expect_value(t, frame.state.players[0].damage, u32(17))
	events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(game.Event)); n, _ := r.copy_events(&s.timeline, 1, events[:])
	hits := 0
	for event in events[:n] {if event.value.kind == .Gameplay && event.value.value.kind == .Hit {hits += 1; testing.expect_value(t, event.value.value.serial, u32(17))}}
	testing.expect_value(t, hits, 1)
}

@(test)
zone_and_lob_survive_an_actual_authority_archive :: proc(t: ^testing.T) {
	w := yard(); w.players[0].profile.abilities = {5, 6}; w.players[0].hp = 8
	w.catalog.mobs[1].hp, w.catalog.mobs[1].speed = 100, 0; game.spawn_mob(&w, 1, {700, 1040})
	Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
	Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
	s, resumed: Server; defer net.server_destroy(&s); defer net.server_destroy(&resumed)
	model := game.model(); model.reset_player = nil; config := net.DEFAULT_CONFIG; config.content = game.CONTENT
	testing.expect_value(t, net.server_init(&s, r.Frame(game.World){state = w}, model, {}, config, local_seat = 1), net.Error.None)
	net.server_set_local_token(&s, net.Token{0 = 43})
	net.server_issue(&s, game.Action{kind = .Cast, slot = 0, aim = {500, 1040}, aim_is_point = true}); net.server_step(&s)
	net.server_issue(&s, game.Action{kind = .Cast, slot = 1, aim = {700, 1040}, aim_is_point = true}); net.server_step(&s)
	cp, decoded: Checkpoint; defer net.checkpoint_destroy(&cp); defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
	testing.expect_value(t, cp.frame.state.zones.count, u32(1)); testing.expect_value(t, cp.frame.state.lobs.count, u32(1))
	bytes, err := net.checkpoint_encode(&cp, model); defer delete(bytes); testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model, game.CONTENT), net.Error.None)
	testing.expect_value(t, net.server_restore(&resumed, &decoded, model, {}, {epoch = 2, local_seat = 1}), net.Error.None)
	before,_:=r.current(&resumed.timeline);testing.expect(t,reflect.equal(before,decoded.frame))
	reference_authority_epoch(&s,2)
	for _ in 0 ..< 370 {testing.expect_value(t, net.server_step(&s), net.Error.None); testing.expect_value(t, net.server_step(&resumed), net.Error.None)}
	a, _ := r.current(&s.timeline); b, _ := r.current(&resumed.timeline)
	testing.expect(t, reflect.equal(a, b) && game.state_valid(a.state))
	testing.expect_value(t, a.state.zone_pulses, u32(11)); testing.expect_value(t, a.state.lobs_landed, u32(1))
	testing.expect_value(t, a.state.zones.count, u32(0)); testing.expect_value(t, a.state.players[0].hp, u8(10))
}

Cast_Input :: struct {request: bool, slot: u8, aim: [2]f32}
cast_step :: proc(w: ^game.World, input: Cast_Input, ctx: ^r.Step(game.Event)) {
	game.step(w, [game.SEATS]game.Control{}, 0, 0, ctx)
	if input.request {game.action(w, 1, game.Action{kind = .Cast, slot = input.slot, aim = input.aim, aim_is_point = true}, ctx)}
}

@(test)
cast_rewind_removes_lob_zone_cooldowns_and_status_consequences :: proc(t: ^testing.T) {
	w := yard(); w.players[0].profile.abilities = {5, 1}; w.players[0].hp = 8
	w.catalog.mobs[1].speed = 0; game.spawn_mob(&w, 1, {620, 1040})
	timeline: r.Timeline(game.World, Cast_Input, game.Event)
	r.init(&timeline, r.Frame(game.World){state = w}, cast_step); defer r.destroy(&timeline)
	for tick in 1 ..= 70 {
		input: Cast_Input
		if tick == 1 {input = {true, 0, {500, 1040}}}
		if tick == 2 {input = {true, 1, {620, 1040}}}
		testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
	}
	before, _ := r.current(&timeline)
	testing.expect_value(t, before.state.players[0].casts, u32(2)); testing.expect(t, before.state.players[0].hp > 8)
	testing.expect_value(t, r.revise_input(&timeline, 1, Cast_Input{}).error, r.Error.None)
	testing.expect_value(t, r.revise_input(&timeline, 2, Cast_Input{}).error, r.Error.None)
	after, _ := r.current(&timeline)
	testing.expect_value(t, after.state.players[0].casts, u32(0)); testing.expect_value(t, after.state.players[0].hp, u8(8))
	testing.expect_value(t, after.state.zones_spawned, u32(0)); testing.expect_value(t, after.state.lobs_landed, u32(0))
	testing.expect_value(t, after.state.zones.count, u32(0)); testing.expect_value(t, after.state.lobs.count, u32(0))
	testing.expect(t, reflect.equal(after.state.players[0].ability_cd, [2]p.Cooldown{}))
	testing.expect_value(t, after.state.mobs.values[0].fx[0].kind, u8(0))
	testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
}
