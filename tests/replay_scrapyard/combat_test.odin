package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import "core:fmt"
import r "godot:replay"
import p "godot:replay/play"
import sc "godot:replay/schema"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import content "../../examples/replay_scrapyard/shared/content"

yard :: proc() -> game.World {
	w := game.initial(encounter_count = 0); w.stage = .Yard
	w.players[0].connected, w.players[0].in_yard = true, true
	w.players[0].position = {500, 1040}
	return w
}

@(test)
tiny_valid_aim_and_exhausted_tick_cannot_corrupt_a_frame :: proc(t: ^testing.T) {
	w := yard()
	timeline: r.Timeline(game.World, Input, game.Event)
	r.init(&timeline, r.Frame(game.World){state = w}, step); defer r.destroy(&timeline)
	input: Input; input.controls[0] = {aim = {1e-38, 1e-38}, fire = true}
	testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
	frame, _ := r.current(&timeline); testing.expect(t, game.state_valid(frame.state))
	r.destroy(&timeline)
	r.init(&timeline, r.Frame(game.World){tick = max(u64) - 65536, state = w}, step)
	testing.expect_value(t, r.advance(&timeline, input).error, r.Error.Aborted)
	frame, _ = r.current(&timeline); testing.expect(t, reflect.equal(frame.state, w))
}

@(test)
catalog_is_valid_and_part_of_canonical_checkpoint_state :: proc(t: ^testing.T) {
	w := yard()
	testing.expect(t, content.valid(w.catalog))
	testing.expect_value(t, w.catalog.gun_count, u8(7)); testing.expect_value(t, w.catalog.mob_count, u8(7))
	fingerprint := content.fingerprint(w.catalog)
	w.catalog.guns[0].damage += 1
	testing.expect(t, content.fingerprint(w.catalog) != fingerprint)
	codec: sc.Schema; defer sc.destroy(&codec)
	testing.expect_value(t, sc.init(&codec, game.World).error, sc.Error.None)
	fmt.printf("RSY_CONTENT sum=%d world_wire_bytes=%d fields=%d\n", fingerprint, codec.wire_size, len(codec.fields))
	bytes := make([]u8, codec.wire_size); defer delete(bytes)
	sc.encode(&codec, w, bytes)
	got: game.World; testing.expect_value(t, sc.decode(&codec, &got, bytes).error, sc.Error.None)
	testing.expect(t, reflect.equal(w, got))
	w.catalog.guns[0].mechanism.jam_per_mille = 1001
	testing.expect(t, !game.state_valid(w))
}

@(test)
sweeps_skip_new_corpses_and_cover_wins_over_targets :: proc(t: ^testing.T) {
	w := yard()
	game.spawn_mob(&w, 0, {580, 1040}); game.spawn_mob(&w, 0, {610, 1040})
	for i in 0 ..< 2 {r.pool_insert(&w.shots, game.Shot{seat = 1, generation = 1, serial = u32(i + 1), position = {550, 1040}, velocity = {100, 0}, ttl = 3, damage = 3})}
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	feedback: game.Notices
	game.shot_step(&w, &feedback, &ctx); game.flush(&w, &feedback, &ctx)
	testing.expect_value(t, w.players[0].kills, u32(2)); testing.expect_value(t, w.drops.count, u32(2))
	testing.expect_value(t, w.shots.count, u32(0)); testing.expect_value(t, ctx.count, 2)
	testing.expect_value(t, w.players[0].damage, u32(6))
	// Artificial cover fixture isolates occlusion, not a network-valid layout.
	w = yard(); w.layout.covers = {}; w.layout.covers[0] = {560, 1000, 20, 60, 0}
	game.spawn_mob(&w, 0, {590, 1040})
	r.pool_insert(&w.shots, game.Shot{seat = 1, generation = 1, serial = 1, position = {540, 1040}, velocity = {80, 0}, ttl = 3, damage = 3})
	game.shot_step(&w, &feedback, &ctx)
	testing.expect_value(t, w.mobs.values[0].hp, u16(3)); testing.expect_value(t, w.shots.count, u32(0))
}

@(test)
capacity_preserves_ammo_and_scrap_and_feedback_stays_bounded :: proc(t: ^testing.T) {
	w := yard()
	storage: [32]r.Occurrence(game.Event); ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	for i in 0 ..< game.MAX_SHOTS {r.pool_insert(&w.shots, game.Shot{seat = 1, generation = 1, serial = u32(i + 1), position = {24, 1040}, velocity = {1, 0}, ttl = 20})}
	before := w.players[0].gun
	game.fire(&w, 1, &ctx)
	testing.expect(t, reflect.equal(before, w.players[0].gun)); testing.expect_value(t, w.players[0].shots, u32(0))
	for _ in 0 ..< game.MAX_DROPS {testing.expect(t, game.drop_scrap(&w, {500, 1040}, 3))}
	testing.expect(t, game.drop_scrap(&w, {501, 1040}, 3))
	testing.expect_value(t, w.drops.count, u32(game.MAX_DROPS))
	feedback: game.Notices; game.pickup_step(&w, &feedback, &ctx); game.flush(&w, &feedback, &ctx)
	testing.expect_value(t, w.players[0].scrap, u32((game.MAX_DROPS + 1) * 3))
	testing.expect_value(t, w.drops.count, u32(0)); testing.expect_value(t, ctx.count, 1)
	testing.expect_value(t, ctx.error, r.Error.None)
}

@(test)
dense_simultaneous_deaths_fit_the_network_event_budget :: proc(t: ^testing.T) {
	w := yard()
	for i in 0 ..< game.MAX_MOBS {
		position := [2]f32{64 + f32(i % 8) * 80, 100 + f32(i / 8) * 100}
		game.spawn_mob(&w, 0, position)
		r.pool_insert(&w.shots, game.Shot{seat = 1, generation = 1, serial = u32(i + 1), position = position, velocity = {1, 0}, ttl = 2, damage = 3})
	}
	storage: [net.GAME_EVENTS]r.Occurrence(game.Event); ctx := r.Step(game.Event){tick = 1, epoch = 1, events = storage[:]}
	feedback: game.Notices; game.shot_step(&w, &feedback, &ctx); game.flush(&w, &feedback, &ctx)
	testing.expect_value(t, ctx.error, r.Error.None); testing.expect_value(t, ctx.count, 2)
	testing.expect_value(t, w.players[0].kills, u32(game.MAX_MOBS)); testing.expect_value(t, w.players[0].damage, u32(game.MAX_MOBS * 3))
	testing.expect_value(t, w.drops.count, u32(game.MAX_MOBS)); testing.expect_value(t, w.shots.count, u32(0))
	testing.expect(t, game.state_valid(w))
}

@(test)
combat_rewind_replaces_damage_payout_and_pickup :: proc(t: ^testing.T) {
	w := yard(); w.catalog.guns[0].damage = 3; w.catalog.guns[0].mechanism.jam_per_mille = 0
	game.spawn_mob(&w, 0, {538, 1040})
	timeline: r.Timeline(game.World, Input, game.Event)
	r.init(&timeline, r.Frame(game.World){state = w}, step); defer r.destroy(&timeline)
	for tick in 1 ..= 80 {input: Input; input.controls[0].fire = tick == 1; testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)}
	before, _ := r.current(&timeline)
	testing.expect_value(t, before.state.players[0].kills, u32(1)); testing.expect_value(t, before.state.players[0].scrap, u32(3))
	testing.expect_value(t, before.state.mobs.count, u32(0))
	testing.expect_value(t, r.revise_input(&timeline, 1, Input{}).error, r.Error.None)
	after, _ := r.current(&timeline)
	testing.expect_value(t, after.state.players[0].kills, u32(0)); testing.expect_value(t, after.state.players[0].scrap, u32(0))
	testing.expect_value(t, after.state.mobs.count, u32(1))
	testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
	testing.expect(t, game.state_valid(after.state))
}

@(test)
active_combat_authority_archive_restores_projectiles_reload_brains_and_drops :: proc(t: ^testing.T) {
	w := yard(); w.catalog.guns[0].mechanism = {1, 20, 0, 3}; p.gun_equip(&w.players[0].gun, w.catalog.guns[0].mechanism)
	game.spawn_mob(&w, 0, {680, 1040}); game.drop_scrap(&w, {540, 1040}, 3)
	Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
	Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
	s, resumed: Server; defer net.server_destroy(&s); defer net.server_destroy(&resumed)
	model := game.model(); model.reset_player = nil // Fixture already owns a live occupant; admission is covered separately.
	config := net.DEFAULT_CONFIG; config.content = game.CONTENT
	testing.expect_value(t, net.server_init(&s, r.Frame(game.World){state = w}, model, {}, config, local_seat = 1), net.Error.None)
	net.server_set_local_token(&s, net.Token{0 = 7}); net.server_local(&s, game.Control{fire = true}); testing.expect_value(t, net.server_step(&s), net.Error.None)
	cp, decoded: Checkpoint; defer net.checkpoint_destroy(&cp); defer net.checkpoint_destroy(&decoded)
	testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
	testing.expect_value(t, cp.frame.state.shots.count, u32(1)); testing.expect_value(t, cp.frame.state.players[0].gun.mode, p.Gun_Mode.Reloading)
	bytes, err := net.checkpoint_encode(&cp, model); defer delete(bytes); testing.expect_value(t, err, net.Error.None)
	testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model, game.CONTENT), net.Error.None)
	testing.expect_value(t, net.server_restore(&resumed, &decoded, model, {}, {epoch = 2, local_seat = 1}), net.Error.None)
	before,_:=r.current(&resumed.timeline);testing.expect(t,reflect.equal(before,decoded.frame))
	reference_authority_epoch(&s,2)
	for _ in 0 ..< 100 {
		net.server_local(&s, game.Control{fire = true}); net.server_local(&resumed, game.Control{fire = true})
		testing.expect_value(t, net.server_step(&s), net.Error.None); testing.expect_value(t, net.server_step(&resumed), net.Error.None)
	}
	a, _ := r.current(&s.timeline); b, _ := r.current(&resumed.timeline)
	testing.expect(t, reflect.equal(a, b) && game.state_valid(a.state))
	testing.expect(t, a.state.players[0].kills > 0 && a.state.players[0].scrap >= 3)
}
