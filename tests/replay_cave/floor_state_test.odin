package replay_cave_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import cave "../../examples/replay_cavecrawl/shared/cave"
import net "godot:replay/net"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"
import "core:os"
import "core:fmt"

floor_state_world :: proc() -> cave.World {
    w := joined_world()
    w.clock = 40
    w.director = {
        wave = 2,
        done = true,
    }
    w.door_open = true

    for &player, index in w.players {
        if player.connected {
            player.position = cave.floor(1).door
            player.hp = 65 + i32(index)
            player.stamina = 3 + i32(index)
            player.rock_cd = 7
            player.heal_cd = 11
            player.chill = 13
            player.kills = 4
            player.deaths = 1
            player.damage = 42
            player.slain = 5
        }
    }

    w.players[0].bag[0] = {cave.GEM, 3}
    return w
}

@(test)
descent_preserves_vitals_after_normal_tick_decay :: proc(t: ^testing.T) {
    w := floor_state_world()
    before := w
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 41)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.depth, u8(2))
    testing.expect_value(t, ctx.error, r.Error.None)

    for player, index in w.players {
        if player.connected {
            testing.expect_value(t, player.hp, before.players[index].hp)
            testing.expect_value(t, player.stamina, before.players[index].stamina)
            testing.expect_value(t, player.rock_cd, u16(6))
            testing.expect_value(t, player.heal_cd, u16(10))
            testing.expect_value(t, player.chill, u16(12))
            testing.expect_value(t, player.kills, before.players[index].kills)
            testing.expect_value(t, player.deaths, before.players[index].deaths)
            testing.expect_value(t, player.damage, before.players[index].damage)
            testing.expect_value(t, player.slain, before.players[index].slain)
            testing.expect(t, reflect.equal(player.bag, before.players[index].bag))
        }
    }

    testing.expect_value(t, w.players[0].position, ([2]f32{80, 120}))
    testing.expect(t, cave.state_valid(w))
}

@(test)
restart_restores_run_fields_but_preserves_status_and_ledger :: proc(t: ^testing.T) {
    w := floor_state_world()
    w.won = true
    w.depth = 2
    names := w.lobby.names
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 41)
    testing.expect(t, cave.act(&w, 1, cave.Action{verb = .Lobby, lobby = {verb = .Restart}}, &ctx))
    testing.expect_value(t, w.depth, u8(1))
    testing.expect(t, !w.won)

    for player in w.players {
        if player.initialized {
            testing.expect_value(t, player.hp, cave.MAX_HP)
            testing.expect_value(t, player.stamina, cave.MAX_STAMINA)
            testing.expect_value(t, player.rock_cd, u16(0))
            testing.expect_value(t, player.heal_cd, u16(0))
            testing.expect_value(t, player.chill, u16(13))
            testing.expect_value(t, player.bag[0].count, u16(0))
            testing.expect_value(t, player.kills, u32(4))
            testing.expect_value(t, player.damage, u32(42))
        }
    }

    testing.expect(t, reflect.equal(w.lobby.names, names))
    testing.expect(t, cave.state_valid(w))
}

@(test)
descent_keeps_normal_regeneration_and_reserved_respawn_progress :: proc(t: ^testing.T) {
    w := floor_state_world()
    w.players[1].connected = false
    w.players[1].hp = 0
    w.players[1].respawn_at = 44
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 40)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 2, &ctx)
    testing.expect_value(t, w.depth, u8(2))
    testing.expect_value(t, w.players[0].stamina, i32(4))
    testing.expect_value(t, w.players[1].hp, i32(0))
    testing.expect_value(t, w.players[1].respawn_at, u64(44))
    testing.expect_value(t, w.players[1].chill, u16(13))
    ctx = context_for(events[:], 45)
    cave.step(&w, [cave.SEATS]cave.Control{}, 2, 0, &ctx)
    testing.expect_value(t, w.players[1].hp, cave.MAX_HP)
    testing.expect_value(t, w.players[1].respawn_at, u64(0))
}

floor_replay_step :: proc(w: ^cave.World, input: bool, ctx: ^r.Step(cave.Event)) {
    w.door_open = input
    cave.step(w, [cave.SEATS]cave.Control{}, 0, 0, ctx)
}

@(test)
revising_a_descent_matches_fresh_vitals_and_complete_events :: proc(t: ^testing.T) {
    initial := r.Frame(cave.World) {
        tick  = 40,
        state = floor_state_world(),
    }
    left, right: r.Timeline(cave.World, bool, cave.Event)
    r.init(&left, initial, floor_replay_step)
    r.init(&right, initial, floor_replay_step)
    defer r.destroy(&left)
    defer r.destroy(&right)

    for tick in 41 ..= 45 {
        testing.expect_value(t, r.advance(&left, true).error, r.Error.None)
        testing.expect_value(t, r.advance(&right, tick != 41).error, r.Error.None)
    }

    testing.expect_value(t, r.revise_input(&left, 41, false).error, r.Error.None)
    a, _ := r.current(&left)
    b, _ := r.current(&right)
    testing.expect(t, reflect.equal(a, b))
    testing.expect_value(t, a.state.players[0].hp, i32(65))
    testing.expect_value(t, a.state.players[0].rock_cd, u16(2))
    ea, eb: [32]r.Occurrence(cave.Event)

    for tick in 41 ..= 45 {
        na, _ := r.copy_events(&left, u64(tick), ea[:])
        nb, _ := r.copy_events(&right, u64(tick), eb[:])
        testing.expect_value(t, na, nb)
        testing.expect(t, reflect.equal(ea[:na], eb[:nb], true))
    }

    testing.expect_value(t, r.audit(&left, 41).error, r.Error.None)
}

@(test)
content4_conversion_retains_saved_state_and_uses_new_transition_rules :: proc(t: ^testing.T) {
    names := [3]string{"before-descent", "after-descent", "before-restart"}

    for name in names {
        bytes, error := os.read_entire_file(
            fmt.tprintf("tests/replay_cave/fixtures/content4/%s.replay", name),
            context.allocator,
        )
        testing.expect(t, error == nil)
        defer delete(bytes)
        old: net.Checkpoint(upgrade.World_7, cave.Control, cave.Action, cave.SEATS)
        current: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
        defer net.checkpoint_destroy(&old)
        defer net.checkpoint_destroy(&current)
        testing.expect_value(
            t,
            net.checkpoint_decode(&old, bytes, upgrade.model4(), upgrade.CONTENT_4),
            net.Error.None,
        )
        testing.expect(t, net.checkpoint_decode(&current, bytes, cave.model(), cave.CONTENT) != .None)
        converted, result := upgrade.convert_archive(bytes)
        defer delete(converted)
        testing.expect_value(t, result, net.Error.None)
        testing.expect_value(t, net.checkpoint_decode(&current, converted, cave.model(), cave.CONTENT), net.Error.None)
        expected, _ := upgrade.convert_world7(old.frame.state)
        expected.authority_known = true
        expected.authority_seat = old.header.local_seat
        testing.expect(t, reflect.equal(current.frame, r.Frame(cave.World){tick = old.frame.tick, state = expected}))
        testing.expect(t, reflect.equal(current.peers[:], old.peers[:], true))
        w := current.frame.state
        events: [32]r.Occurrence(cave.Event)
        ctx := context_for(events[:], 101)

        if name == "before-descent" {
            cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
            testing.expect_value(t, w.depth, u8(2))
            testing.expect_value(t, w.players[0].hp, i32(65))
            testing.expect_value(t, w.players[0].rock_cd, u16(6))
        }

        if name == "after-descent" {
            testing.expect_value(t, w.players[0].hp, i32(100))
        } // Already-lost injury is not fabricated.

        if name == "before-restart" {
            testing.expect(t, cave.act(&w, 1, cave.Action{verb = .Lobby, lobby = {verb = .Restart}}, &ctx))
            testing.expect_value(t, w.players[0].chill, u16(13))
            testing.expect_value(t, w.players[0].hp, cave.MAX_HP)
        }
    }
}
