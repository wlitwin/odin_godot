package replay_scrapyard_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_scrapyard/shared/game"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
rail_contacts_preserve_piercing_and_do_not_alias_terminal_slugs :: proc(t: ^testing.T) {
    for mend in ([2]bool{false, true}) {
        w := yard()
        w.clock = 1
        w.layout.covers = {}
        w.layout.covers[0] = {600, 1000, 20, 60, 0}
        game.spawn_mob(&w, 0, {570, 1040})
        game.spawn_mob(&w, 0, {650, 1040})
        w.players[1].connected, w.players[1].in_yard = true, true
        w.players[1].position = {570, 1040}
        w.players[1].hp = 5
        shot := game.Shot {
            seat       = 1,
            generation = 1,
            serial     = 1,
            position   = {540, 1040},
            velocity   = {100, 0},
            ttl        = 3,
            damage     = 1,
        }
        storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 1,
            epoch  = 1,
            events = storage[:],
        }
        feedback: game.Notices
        game.rail_land(&w, shot, mend, net.View_Time{status = .Live}, &feedback, &ctx)
        // The matching pool handle would otherwise have exactly the rail's source.
        shot.position = {550, 1020}
        r.pool_insert(&w.shots, shot)
        game.shot_step(&w, &feedback, &ctx)
        game.flush(&w, &feedback, &ctx)
        testing.expect_value(t, ctx.error, r.Error.None)
        rails, slugs := 0, 0

        for occurrence in storage[:ctx.count] {
            if occurrence.value.kind == .Wall {
                testing.expect_value(t, occurrence.id.source, u64(1) << 32 | 1)
                testing.expect_value(t, game.wall_normal(occurrence.value), [2]f32{-1, 0})

                if occurrence.id.key == game.WALL_RAIL_KEY {
                    rails += 1
                    testing.expect_value(t, occurrence.value.position, [2]f32{600, 1040})
                } else {
                    slugs += 1
                    testing.expect_value(t, occurrence.value.position, [2]f32{600, 1020})
                }
            }
        }

        testing.expect_value(t, rails, 1)
        testing.expect_value(t, slugs, 1)
        testing.expect_value(t, w.mobs.values[0].hp, mend ? u16(3) : u16(2))
        testing.expect_value(t, w.mobs.values[1].hp, u16(3))
        testing.expect_value(t, w.players[1].hp, mend ? u8(6) : u8(5))
        testing.expect_value(t, w.flashes.values[0].end, [2]f32{600, 1040})
    }
}

@(test)
rail_walls_describe_the_beam_even_when_historical_body_query_is_unavailable :: proc(t: ^testing.T) {
    for blocked in ([2]bool{true, false}) {
        w := yard()
        w.clock = 2
        w.layout.covers = {}

        if blocked {
            w.layout.covers[0] = {600, 1000, 20, 60, 0}
        }

        game.spawn_mob(&w, 0, {570, 1040})
        storage: [net.GAME_EVENTS]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = 2,
            epoch  = 1,
            events = storage[:],
        }
        feedback: game.Notices
        game.rail_land(
            &w,
            {seat = 1, generation = 1, serial = 1, position = {540, 1040}, velocity = {100, 0}, ttl = 3, damage = 1},
            false,
            net.View_Time{status = .Unavailable},
            &feedback,
            &ctx,
        )
        game.flush(&w, &feedback, &ctx)
        testing.expect_value(t, w.mobs.values[0].hp, u16(3))
        testing.expect_value(t, w.players[0].rejected_queries, u32(1))
        testing.expect_value(t, ctx.count, blocked ? 1 : 0)
        testing.expect_value(t, ctx.error, r.Error.None)
    }
}

@(test)
grenade_trails_sample_confirmed_ticks_without_replaying_history :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 10
    shot := game.Shot {
        kind       = .Grenade,
        seat       = 1,
        generation = 1,
        serial     = 1,
        position   = {500, 1040},
        ttl        = 66,
    }
    handle, _ := r.pool_insert(&w.shots, shot)
    trails: flow.Trails
    out: [game.MAX_SHOTS]flow.Trail_Point
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 0) // restored live shot seeds silently
    w.clock = 12
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 0)
    w.clock = 13
    w.shots.values[0].position = {510, 1040}
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 1)
    testing.expect_value(t, out[0].position, [2]f32{510, 1040})
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 0)
    w.clock = 50
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 1) // no invented backlog
    r.pool_remove(&w.shots, handle)
    r.pool_insert(&w.shots, shot)
    w.clock = 51
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 0)
    w.clock = 54
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 1)
    testing.expect_value(t, out[0].source, u64(2) << 32 | 1)
    w.clock = 55
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 0) // migration
    w.clock = 58
    testing.expect_value(t, flow.trail_points(&trails, &w, 1, out[:]), 0) // stale epoch
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 1)
    w.clock = 56
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 0) // rewind baseline
    w.clock = 59
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, nil), 0)
    testing.expect_value(t, trails.dropped, u64(1))
    w.clock = 60
    w.floor += 1
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 0)
    w.clock = 63
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 1)
    w.clock = 64
    w.run += 1
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 0)
    w.clock = 70
    w.shots.values[0].kind = .Ballistic
    testing.expect_value(t, flow.trail_points(&trails, &w, 2, out[:]), 0)
}
