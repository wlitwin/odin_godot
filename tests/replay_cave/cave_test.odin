package replay_cave_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import p "godot:replay/play"
import cave "../../examples/replay_cavecrawl/shared/cave"

context_for :: proc(events: []r.Occurrence(cave.Event), tick: u64 = 1) -> r.Step(cave.Event) {
    return {tick = tick, epoch = 1, events = events}
}

joined_world :: proc() -> cave.World {
    w := cave.initial()
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:])
    cave.step(&w, {}, 3, 0, &ctx)
    return w
}

@(test)
chest_bags_drops_and_pickups_conserve_authored_loot :: proc(t: ^testing.T) {
    w := joined_world()
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:])
    w.players[0].position = cave.floor(1).chest
    w.players[1].position = w.players[0].position
    testing.expect(t, cave.act(&w, 1, {verb = .Take, index = 0}, &ctx))
    testing.expect(t, !cave.act(&w, 2, {verb = .Take, index = 0}, &ctx))
    testing.expect_value(t, cave.world_items(&w, cave.GEM), u32(3))
    ctx = context_for(events[:], 2)
    testing.expect(t, cave.act(&w, 1, {verb = .Drop, index = 0}, &ctx))
    testing.expect_value(t, w.pickups.count, u32(1))
    ctx = context_for(events[:], 3)
    testing.expect(t, cave.act(&w, 2, {verb = .Grab, index = 0, generation = w.pickups.generations[0]}, &ctx))
    testing.expect_value(t, w.pickups.count, u32(0))
    testing.expect_value(t, cave.world_items(&w, cave.GEM), u32(3))
    testing.expect_value(t, p.inventory_count(w.players[1].bag[:], cave.GEM), u32(3))
    testing.expect(t, cave.state_valid(w))
}

@(test)
inventory_capacity_keeps_unmoved_items_in_the_chest :: proc(t: ^testing.T) {
    w := joined_world()
    w.players[0].position = cave.floor(1).chest

    for &stack in w.players[0].bag {
        stack = {cave.TORCH, 5}
    }

    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:])
    testing.expect(t, !cave.act(&w, 1, {verb = .Take}, &ctx))
    testing.expect_value(t, w.chest[0].count, u16(3))
    w.players[0].bag[0] = {cave.GEM, 98}
    testing.expect(t, cave.act(&w, 1, {verb = .Take}, &ctx))
    testing.expect_value(t, w.chest[0].count, u16(2))
    testing.expect_value(t, w.players[0].bag[0].count, u16(99))
}

@(test)
door_and_relic_actions_use_simulated_positions_and_carrier_identity :: proc(t: ^testing.T) {
    w := joined_world()
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:])
    testing.expect(t, !cave.act(&w, 1, {verb = .Door}, &ctx))
    w.players[0].position = cave.floor(1).door
    testing.expect(t, cave.act(&w, 1, {verb = .Door}, &ctx))
    testing.expect(t, w.door_open)
    w.players[0].position = w.relic.position
    ctx = context_for(events[:], 2)
    testing.expect(t, cave.act(&w, 1, {verb = .Carry}, &ctx))
    testing.expect(t, !cave.act(&w, 2, {verb = .Set_Down}, &ctx))
    cave.step(&w, {}, 0, 0, &ctx)
    testing.expect_value(t, w.relic.position, w.players[0].position + [2]f32{10, -12})
    ctx = context_for(events[:], 3)
    testing.expect(t, cave.act(&w, 1, {verb = .Set_Down}, &ctx))
    testing.expect_value(t, w.relic.carrier, u16(0))
}

@(test)
rocks_damage_and_chill_players_and_can_revive_before_bleedout :: proc(t: ^testing.T) {
    w := joined_world()
    w.director.done = true
    w.players[0].position, w.players[1].position = {100, 120}, {160, 120}
    events: [32]r.Occurrence(cave.Event)

    for shot in 0 ..< 3 {
        w.players[0].rock_cd = 0
        w.players[0].stamina = 10
        ctx := context_for(events[:], u64(shot * 10 + 1))
        testing.expect(t, cave.act(&w, 1, {verb = .Throw, aim = {1, 0}}, &ctx))

        for frame in 0 ..< 6 {
            ctx = context_for(events[:], u64(shot * 10 + frame + 2))
            cave.step(&w, {}, 0, 0, &ctx)
            testing.expect_value(t, ctx.error, r.Error.None)
        }
    }

    testing.expect_value(t, w.players[1].hp, i32(0))
    testing.expect_value(t, w.players[1].deaths, u32(1))
    testing.expect_value(t, w.players[0].kills, u32(1))
    w.players[0].position = w.players[1].position
    ctx := context_for(events[:], 30)
    testing.expect(t, cave.act(&w, 1, {verb = .Revive, index = 1}, &ctx))
    testing.expect_value(t, w.players[1].hp, i32(30))
    testing.expect_value(t, w.players[1].respawn_at, u64(0))
    testing.expect(t, cave.state_valid(w))
}

@(test)
floor_progression_preserves_bags_and_invalidates_previous_pool_handles :: proc(t: ^testing.T) {
    w := joined_world()
    w.players[0].bag[0] = {cave.GEM, 3}
    id, _ := r.pool_insert(&w.rocks, cave.Rock{left = 10, shooter = 1})
    w.director.done, w.door_open = true, true

    for &player in w.players {
        if player.connected {
            player.position = cave.floor(1).door
        }
    }

    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 2)
    cave.step(&w, {}, 0, 0, &ctx)
    testing.expect_value(t, w.depth, u8(2))
    testing.expect_value(t, w.players[0].bag[0].count, u16(3))
    testing.expect_value(t, w.chest[0].count, u16(5))
    new_id, _ := r.pool_insert(&w.rocks, cave.Rock{left = 10, shooter = 1})
    testing.expect(t, id != new_id)
    _, old := r.pool_get(&w.rocks, id)
    testing.expect(t, !old)
    w.director.done, w.door_open = true, true

    for &player in w.players {
        if player.connected {
            player.position = cave.floor(2).door
        }
    }

    ctx = context_for(events[:], 3)
    cave.step(&w, {}, 0, 0, &ctx)
    testing.expect(t, w.won)
}

@(test)
replayable_path_query_walks_around_the_authored_rift :: proc(t: ^testing.T) {
    def := cave.floor(2)
    position := [2]f32{400, 180}
    goal := [2]f32{200, 180}
    bent := false

    for _ in 0 ..< 200 {
        position = p.around_rect(position, goal, def.rift, 4)

        if position[1] < 60 || position[1] > 300 {
            bent = true
        }
    }

    testing.expect(t, bent)
    testing.expect(t, p.in_reach(position, goal, 4))
}
