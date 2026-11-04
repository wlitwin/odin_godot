package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
spitter_spawn_grace_and_projectile_wound_are_tick_owned :: proc(t: ^testing.T) {
    w := yard()
    w.catalog.mobs[2].speed = 0
    game.spawn_mob(&w, 2, {700, 1040})
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }

    for tick in 1 ..< 90 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.spits, u32(0))
    ctx.tick, ctx.count = 90, 0
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.spits, u32(1))
    testing.expect_value(t, w.shots.values[0].kind, game.Shot_Kind.Spit)
    testing.expect_value(t, w.shots.values[0].position, [2]f32{678, 1040})

    for tick in 91 ..< 240 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.players[0].hp, u8(9))
    testing.expect_value(t, w.spits, u32(1))
    testing.expect(t, game.state_valid(w))
}

@(test)
popper_death_has_no_loot_and_rewind_removes_its_blast :: proc(t: ^testing.T) {
    w := yard()
    game.spawn_mob(&w, 3, {536, 1040})
    timeline: r.Timeline(game.World, Input, game.Event)
    r.init(&timeline, r.Frame(game.World){state = w}, step)
    defer r.destroy(&timeline)

    for _ in 0 ..< 10 {
        r.advance(&timeline, Input{})
    }

    before, _ := r.current(&timeline)
    testing.expect_value(t, before.state.pops, u32(1))
    testing.expect_value(t, before.state.defeated, u32(1))
    testing.expect_value(t, before.state.players[0].hp, u8(8))
    testing.expect_value(t, before.state.drops.count, u32(0))
    input: Input
    input.controls[0] = {
        move = {-1, 0},
        aim  = {-1, 0},
        dash = true,
    }
    testing.expect_value(t, r.revise_input(&timeline, 1, input).error, r.Error.None)
    after, _ := r.current(&timeline)
    testing.expect_value(t, after.state.pops, u32(0))
    testing.expect_value(t, after.state.players[0].hp, u8(10))
    testing.expect_value(t, after.state.flashes.count, u32(0))
    testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
}

@(test)
titan_wind_adds_enrage_and_payout_follow_saved_state :: proc(t: ^testing.T) {
    w := yard()
    w.boss_hp = 36
    w.catalog.mobs[4].speed, w.catalog.mobs[0].speed = 0, 0
    game.spawn_mob(&w, 4, {650, 1040})
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }

    for tick in 1 ..= 60 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.mobs.values[0].tele.left, u16(48))

    for tick in 61 ..= 108 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.slams, u32(1))
    testing.expect_value(t, w.players[0].hp, u8(8))
    w.mobs.values[0].hp, w.mobs.values[0].next_act = 11, 0
    ctx.tick, ctx.count = 109, 0
    game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.adds, u32(2))
    testing.expect_value(t, w.mobs.values[0].tele.left, u16(24))

    for tick in 110 ..= 133 {
        ctx.tick, ctx.count = u64(tick), 0
        game.step(&w, [game.SEATS]game.Control{}, 0, 0, &ctx)
    }

    testing.expect_value(t, w.slams, u32(2))
    testing.expect_value(t, w.mobs.values[0].next_act, u64(223))
    feedback: game.Notices
    game.wound_mob(&w, 0, 255, game.Credit{1, 1}, &feedback, &ctx)
    testing.expect_value(t, w.players[0].cores, u32(3))
    testing.expect_value(t, w.drops.count, u32(5))
    testing.expect_value(t, w.mobs.values[0].tele, p.Telegraph{})
    testing.expect(t, game.state_valid(w))
}

@(test)
boss_wind_spit_and_status_credit_continue_after_checkpoint_restore :: proc(t: ^testing.T) {
    w := yard()
    w.clock, w.boss_hp = 60, 36
    w.catalog.mobs[4].speed, w.catalog.mobs[2].speed = 0, 0
    game.spawn_mob(&w, 4, {650, 1040})
    game.spawn_mob(&w, 2, {700, 1040})
    p.telegraph_start(&w.mobs.values[0].tele, 48)
    w.mobs.values[1].next_act = 62
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 60,
        epoch  = 1,
        events = storage[:],
    }
    feedback: game.Notices
    game.apply_status(&w, game.mob_target(&w, 0), 6, game.Credit{1, 1}, &feedback, &ctx)
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
        net.server_init(&s, r.Frame(game.World){tick = 60, state = w}, model, {}, config, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&s, net.Token{0 = 31})

    for _ in 0 ..< 10 {
        testing.expect_value(t, net.server_step(&s), net.Error.None)
    }

    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    testing.expect(
        t,
        cp.frame.state.mobs.values[0].tele.left > 0 &&
        cp.frame.state.shots.count > 0 &&
        cp.frame.state.mobs.values[0].fx_credit[0].seat == 1,
    )
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

    for _ in 0 ..< 120 {
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    }

    a, _ := r.current(&s.timeline)
    b, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(a, b) && game.state_valid(a.state))
    testing.expect(t, a.state.slams > 0 && a.state.dot_pulses > 0 && a.state.players[0].hp < 10)
}
