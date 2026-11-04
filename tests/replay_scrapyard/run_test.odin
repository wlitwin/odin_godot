package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import arena "../../examples/replay_scrapyard/shared/arena"

run_world :: proc() -> game.World {
    w := yard()
    w.rules = game.RUN_RULES
    w.rules.base_count, w.rules.growth, w.rules.rest, w.rules.wave_count, w.rules.barrels, w.rules.boss_every =
        2, 0, 3, 1, 0, 0
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    game.arm_floor(&w, &ctx, false)
    return w
}

clear_world :: proc() -> game.World {
    w := run_world()
    w.stage = .Clear
    w.director = {
        wave = 1,
        done = true,
    }
    w.players[0].position = game.GATE
    return w
}

@(test)
director_membership_rest_and_clear_reward_are_consistent :: proc(t: ^testing.T) {
    w := run_world()
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }

    for tick in 1 ..= 3 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.director.alive, u32(2))
    testing.expect_value(t, w.director.pending, u32(0))
    feedback: game.Notices

    for i in 0 ..< 2 {
        game.wound_mob(&w, i, 255, game.Credit{1, 1}, &feedback, &ctx)
    }

    testing.expect_value(t, w.director.alive, u32(0))
    testing.expect_value(t, w.director.rest_until, u64(6))

    for tick in 4 ..= 5 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
        testing.expect_value(t, w.stage, game.Stage.Yard)
    }

    ctx.tick, ctx.count = 6, 0
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.stage, game.Stage.Clear)
    testing.expect_value(t, w.players[0].cores, u32(1))
    ctx.tick, ctx.count = 7, 0
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.clears, u32(1))
    testing.expect(t, game.state_valid(w))
}

@(test)
empty_single_wave_clears_without_an_invented_death_or_rest :: proc(t: ^testing.T) {
    w := run_world()
    w.rules.base_count = 0
    w.rules.rest = 300
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = events[:],
    }
    game.arm_floor(&w, &ctx, false)
    testing.expect(t, game.state_valid(w))

    for tick in 1 ..= 4 {
        ctx.tick = u64(tick)
        ctx.count = 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.stage, game.Stage.Clear)
    testing.expect_value(t, w.spawn_index, u32(0))
    testing.expect_value(t, w.defeated, u32(0))
    testing.expect_value(t, w.clears, u32(1))
    testing.expect_value(t, w.players[0].cores, u32(1))
    testing.expect_value(t, w.director.rest_until, u64(0))
    testing.expect(t, game.state_valid(w))
}

@(test)
gate_cancel_and_floor_turn_preserve_run_resources_and_rebase_history :: proc(t: ^testing.T) {
    w := clear_world()
    w.players[0].scrap, w.players[0].cores, w.players[0].boost_damage = 9, 4, 2
    w.players[0].gun.ammo = 5
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.depart.left, game.DEPART_TICKS)
    w.players[0].position = {500, 1040}
    ctx.tick, ctx.count = 2, 0
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.depart.wind, u16(0))
    testing.expect_value(t, w.floor, u8(1))
    w.players[0].position = game.GATE

    for tick in 3 ..= 183 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.floor, u8(2))
    testing.expect_value(t, w.stage, game.Stage.Yard)
    testing.expect_value(t, w.players[0].position, [2]f32{184, arena.HEIGHT / 2})
    testing.expect_value(t, w.players[0].scrap, u32(9))
    testing.expect_value(t, w.players[0].gun.ammo, u16(5))
    testing.expect_value(t, w.players[0].boost_damage, u8(2))
    testing.expect_value(t, w.players[0].cores, u32(4))
    testing.expect(t, w.players[0].warp > 0 && arena.valid(w.layout, w.seed, 2) && game.state_valid(w))

    for entry in w.hit_history.entries {
        if entry.valid {
            testing.expect_value(t, entry.tick, u64(183))
        }
    }
}

@(test)
shop_and_parts_are_atomic_and_active_iron_is_separate_from_claim :: proc(t: ^testing.T) {
    w := clear_world()
    w.players[0].scrap, w.players[0].cores = 20, 9
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    claim := w.players[0].profile.iron

    for item in u8(1) ..= 3 {
        testing.expect(t, game.action(&w, 1, game.Action{kind = .Buy, item = item}, &ctx))
    }

    testing.expect_value(t, w.players[0].scrap, u32(7))
    testing.expect_value(t, w.players[0].boost_damage, u8(1))
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Buy, item = 5}, &ctx))
    testing.expect_value(t, w.players[0].profile.iron, claim)
    testing.expect_value(t, w.players[0].gun_id, u8((claim + 1) % 7))

    for part in u8(0) ..< 4 {
        testing.expect(t, game.action(&w, 1, game.Action{kind = .Workshop, item = part}, &ctx))
    }

    testing.expect_value(t, w.players[0].cores, u32(0))
    testing.expect_value(t, w.players[0].parts, u8(15))
    testing.expect_value(t, w.players[0].hp, u8(14))
    before := w
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Workshop, item = 1}, &ctx) && reflect.equal(w, before))
    w.players[0].scrap = 0
    before = w
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Buy, item = 1}, &ctx) && reflect.equal(w, before))
    testing.expect_value(t, game.gun_cadence(&w, &w.players[0]), u16(4))
    testing.expect(t, game.state_valid(w))
}

@(test)
wipe_reset_clears_floor_state_but_preserves_parts_cores_and_current_iron :: proc(t: ^testing.T) {
    w := run_world()
    w.players[0].parts, w.players[0].cores, w.players[0].scrap = 2, 7, 20
    w.players[0].boost_damage, w.players[0].boost_rate, w.players[0].boost_speed = 2, 1, 1
    w.players[0].gun_id = 1
    p.gun_equip(&w.players[0].gun, w.catalog.guns[1].mechanism)
    w.players[0].hp = 0
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.stage, game.Stage.Over)
    testing.expect_value(t, w.over_until, u64(151))

    for tick in 2 ..= 151 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.run, u32(1))
    testing.expect_value(t, w.floor, u8(1))
    testing.expect_value(t, w.players[0].hp, u8(14))
    testing.expect_value(t, w.players[0].scrap, u32(0))
    testing.expect_value(t, w.players[0].cores, u32(7))
    testing.expect_value(t, w.players[0].parts, u8(2))
    testing.expect_value(t, w.players[0].gun_id, u8(1))
    testing.expect_value(t, w.players[0].boost_damage, u8(0))
    testing.expect_value(t, w.director.rest_until, u64(154))
    testing.expect(t, game.state_valid(w))
}

@(test)
revive_requires_continued_authority_validated_hold :: proc(t: ^testing.T) {
    w := yard()
    w.players[0].hp = 0
    w.players[1].connected, w.players[1].in_yard, w.players[1].position = true, true, {535, 1040}
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    controls: [game.SEATS]game.Control
    controls[1].revive = true

    for tick in 1 ..= 60 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, controls, 0, 0, &ctx)
    }

    testing.expect_value(t, w.players[1].revive.elapsed, u16(60))
    controls[1].revive = false
    ctx.tick, ctx.count = 61, 0
    game.step(&w, controls, 0, 0, &ctx)
    testing.expect_value(t, w.players[1].revive, p.Channel{})
    controls[1].revive = true

    for tick in 62 ..= 181 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, controls, 0, 0, &ctx)
    }

    testing.expect_value(t, w.players[0].hp, u8(4))
    testing.expect_value(t, w.players[1].revives, u32(1))
    testing.expect_value(t, w.players[1].revive, p.Channel{})
    testing.expect(t, game.state_valid(w))
}

@(test)
departure_checkpoint_continues_to_the_same_next_floor :: proc(t: ^testing.T) {
    w := clear_world()
    Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    s, resumed: Server
    defer net.server_destroy(&s)
    defer net.server_destroy(&resumed)
    model := game.model()
    model.reset_player = nil
    config := net.DEFAULT_CONFIG
    config.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w}, model, {}, config, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&s, net.Token{0 = 47})

    for _ in 0 ..< 31 {
        net.server_step(&s)
    }

    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    testing.expect_value(t, cp.frame.state.depart.left, u16(150))
    bytes, err := net.checkpoint_encode(&cp, model)
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model, game.CONTENT), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(&resumed, &decoded, model, {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    before, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(before, decoded.frame))
    reference_authority_epoch(&s, 2)

    for _ in 0 ..< 150 {
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    }

    a, _ := r.current(&s.timeline)
    b, _ := r.current(&resumed.timeline)
    testing.expect_value(t, a.state.floor, u8(2))
    testing.expect(t, reflect.equal(a, b) && game.state_valid(a.state))
}
