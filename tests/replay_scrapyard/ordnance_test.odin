package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import h "godot:replay/history"
import p "godot:replay/play"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"

@(test)
rail_queries_past_positions_but_wounds_current_lifetimes :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 2
    game.spawn_mob(&w, 0, {590, 1040})
    game.spawn_mob(&w, 0, {640, 1040})
    h.record(&w.hit_history, 1, game.proxies(&w))

    for &mob, i in w.mobs.values {
        if w.mobs.alive[i] {
            mob.position[1] = 960
        }
    }

    storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 2,
        epoch  = 1,
        events = storage[:],
    }
    shot := game.Shot {
        seat       = 1,
        generation = 1,
        serial     = 1,
        position   = {524, 1040},
        velocity   = {30, 0},
        ttl        = 12,
        damage     = 2,
    }
    feedback: game.Notices
    game.rail_land(&w, shot, false, net.View_Time{1, 1, 0, .Historical}, &feedback, &ctx)

    for alive, i in w.mobs.alive {
        if alive {
            testing.expect_value(t, w.mobs.values[i].hp, u16(1))
            testing.expect_value(t, w.mobs.values[i].position[1], f32(960))
        }
    }

    testing.expect_value(t, w.players[0].damage, u32(4))
    testing.expect_value(t, w.players[0].last_judged, u64(1))
    // Recycled slot at the old location must not inherit the old target's wound.
    r.pool_remove(&w.mobs, r.Handle(game.Mob){0, w.mobs.generations[0]})
    game.spawn_mob(&w, 0, {590, 1040})
    game.rail_land(&w, shot, false, net.View_Time{1, 1, 0, .Historical}, &feedback, &ctx)
    testing.expect_value(t, w.mobs.values[0].hp, u16(3))
    h.record(&w.hit_history, 2, game.proxies(&w))
    game.rail_land(&w, shot, false, net.View_Time{1, 2, 32768, .Historical}, &feedback, &ctx)
    testing.expect_value(t, w.mobs.values[0].hp, u16(3)) // no interpolated birth between generations
    game.rail_land(&w, shot, false, net.View_Time{1, 2, max(u16), .Historical}, &feedback, &ctx)
    testing.expect_value(t, w.mobs.values[0].hp, u16(1)) // the new endpoint can be judged as its own lifetime
    testing.expect(t, game.state_valid(w))
}

@(test)
unavailable_and_expired_rails_never_fall_back_to_live_targets :: proc(t: ^testing.T) {
    for status in ([3]net.View_Status{.Unavailable, .Expired, .Historical}) {
        w := yard()
        w.clock = 2
        w.players[0].profile.iron, w.players[0].gun_id = 5, 5
        p.gun_equip(&w.players[0].gun, w.catalog.guns[5].mechanism)
        game.spawn_mob(&w, 0, {560, 1040})
        storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 2,
            epoch  = 1,
            events = storage[:],
        }
        feedback: game.Notices
        game.fire_view(&w, 1, net.View_Time{1, 1, 0, status}, &feedback, &ctx)
        testing.expect_value(t, w.mobs.values[0].hp, u16(3))
        testing.expect_value(t, w.players[0].rejected_queries, u32(1))
        testing.expect_value(t, w.players[0].gun.ammo, u16(4))
        testing.expect_value(t, w.players[0].shots, u32(1))
        testing.expect(t, game.state_valid(w))
    }
}

@(test)
mend_hits_first_living_friend_including_a_full_health_blocker :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 1

    for i in 1 ..= 2 {
        w.players[i].connected, w.players[i].in_yard = true, true
        w.players[i].position = {550 + f32(i) * 40, 1040}
    }

    w.players[2].hp = 2
    storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    shot := game.Shot {
        seat       = 1,
        generation = 1,
        serial     = 1,
        position   = {524, 1040},
        velocity   = {30, 0},
        ttl        = 12,
        damage     = 4,
    }
    feedback: game.Notices
    game.rail_land(&w, shot, true, net.View_Time{status = .Live}, &feedback, &ctx)
    testing.expect_value(t, w.players[2].hp, u8(2))
    testing.expect_value(t, w.players[0].healed, u32(0))
    w.players[1].hp = 0
    game.rail_land(&w, shot, true, net.View_Time{status = .Live}, &feedback, &ctx)
    testing.expect_value(t, w.players[1].hp, u8(0))
    testing.expect_value(t, w.players[2].hp, u8(6))
    testing.expect_value(t, w.players[0].healed, u32(4))
    testing.expect_value(t, w.players[0].hp, u8(10))
    testing.expect(t, game.state_valid(w))
}

@(test)
grenade_contacts_flesh_blasts_mobs_and_spares_the_crew :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 1
    game.spawn_mob(&w, 0, {510, 1040})
    game.spawn_mob(&w, 0, {560, 1040})
    shot := game.Shot {
        kind       = .Grenade,
        seat       = 1,
        generation = 1,
        serial     = 1,
        position   = {500, 1040},
        ttl        = 66,
        damage     = 3,
    }
    storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = storage[:],
    }
    feedback: game.Notices
    testing.expect(t, game.grenade_step(&w, &shot, &feedback, &ctx))
    testing.expect_value(t, w.players[0].hp, u8(10))
    testing.expect_value(t, w.players[0].kills, u32(2))
    testing.expect_value(t, w.players[0].blasts, u32(1))
    testing.expect_value(t, w.drops.count, u32(2))
    testing.expect_value(t, w.flashes.count, u32(1))
    testing.expect(t, game.state_valid(w))
}

@(test)
grenade_rewind_cancels_the_complete_blast_and_payout :: proc(t: ^testing.T) {
    w := yard()
    w.players[0].profile.iron, w.players[0].gun_id = 4, 4
    p.gun_equip(&w.players[0].gun, w.catalog.guns[4].mechanism)
    game.spawn_mob(&w, 0, {565, 1040})
    timeline: r.Timeline(game.World, Input, game.Event)
    r.init(&timeline, r.Frame(game.World){state = w}, step)
    defer r.destroy(&timeline)

    for tick in 1 ..= 80 {
        input: Input
        input.controls[0].fire = tick == 1
        testing.expect_value(t, r.advance(&timeline, input).error, r.Error.None)
    }

    before, _ := r.current(&timeline)
    testing.expect_value(t, before.state.players[0].blasts, u32(1))
    testing.expect_value(t, before.state.players[0].kills, u32(1))
    testing.expect_value(t, r.revise_input(&timeline, 1, Input{}).error, r.Error.None)
    after, _ := r.current(&timeline)
    testing.expect_value(t, after.state.players[0].blasts, u32(0))
    testing.expect_value(t, after.state.players[0].kills, u32(0))
    testing.expect_value(t, after.state.drops.count, u32(0))
    testing.expect_value(t, after.state.flashes.count, u32(0))
    testing.expect_value(t, r.audit(&timeline, 1).error, r.Error.None)
}

@(test)
grenade_and_query_history_survive_authority_archive_restore :: proc(t: ^testing.T) {
    w := yard()
    w.players[0].profile.iron, w.players[0].gun_id = 4, 4
    w.catalog.guns[4].mechanism = {1, 20, 0, 3}
    p.gun_equip(&w.players[0].gun, w.catalog.guns[4].mechanism)
    game.spawn_mob(&w, 0, {680, 1040})
    Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
    Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    s, resumed: Server
    defer net.server_destroy(&s)
    defer net.server_destroy(&resumed)
    model := game.model()
    model.reset_player = nil // This fixture already owns its live occupant.
    config := net.DEFAULT_CONFIG
    config.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w}, model, {}, config, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&s, net.Token{0 = 11})
    net.server_local(&s, game.Control{fire = true})
    net.server_step(&s)
    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    testing.expect_value(t, cp.frame.state.shots.values[0].kind, game.Shot_Kind.Grenade)
    testing.expect_value(t, cp.frame.state.players[0].gun.mode, p.Gun_Mode.Reloading)
    _, found := h.read(&cp.frame.state.hit_history, cp.frame.tick)
    testing.expect(t, found)
    bytes, err := net.checkpoint_encode(&cp, model)
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, model, game.CONTENT), net.Error.None)
    testing.expect(t, reflect.equal(cp.frame.state.hit_history, decoded.frame.state.hit_history))
    testing.expect_value(
        t,
        net.server_restore(&resumed, &decoded, model, {}, {epoch = 2, local_seat = 1}),
        net.Error.None,
    )
    before, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(before, decoded.frame))
    reference_authority_epoch(&s, 2)

    for _ in 0 ..< 100 {
        net.server_local(&s, game.Control{})
        net.server_local(&resumed, game.Control{})
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    }

    a, _ := r.current(&s.timeline)
    b, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(a, b) && game.state_valid(a.state))
    testing.expect_value(t, a.state.players[0].blasts, u32(1))
    testing.expect_value(t, a.state.players[0].kills, u32(1))
}
