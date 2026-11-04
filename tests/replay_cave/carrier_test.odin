package replay_cave_test

import "core:testing"
import "core:reflect"
import "core:os"
import "core:fmt"
import net "godot:replay/net"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"
import r "godot:replay"
import cave "../../examples/replay_cavecrawl/shared/cave"

carrier_world :: proc() -> cave.World {
    w := joined_world()
    w.clock = 100
    w.director = {
        wave = 2,
        done = true,
    }
    w.players[0].position = {220, 150}
    w.players[1].position = {240, 150}
    w.relic = {
        position = {230, 138},
        carrier  = 1,
        version  = 7,
    }
    return w
}

@(test)
carrier_death_revive_and_respawn_retain_relic_ownership :: proc(t: ^testing.T) {
    w := carrier_world()
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 101)
    cave.hurt_player(&w, 0, 100, 2, false, 10, &ctx)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.players[0].hp, i32(0))
    testing.expect_value(t, w.relic.carrier, u16(1))
    testing.expect_value(t, w.relic.version, u32(7))
    testing.expect(t, cave.act(&w, 2, cave.Action{verb = .Revive, index = 0}, &ctx))
    testing.expect_value(t, w.relic.carrier, u16(1))
    cave.hurt_player(&w, 0, 100, 2, false, 11, &ctx)
    ctx = context_for(events[:], w.players[0].respawn_at)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.players[0].hp, cave.MAX_HP)
    testing.expect_value(t, w.relic.carrier, u16(1))
    testing.expect_value(t, w.relic.version, u32(7))
    testing.expect_value(t, w.relic.position, w.players[0].position + ([2]f32{10, -12}))
    testing.expect(t, cave.state_valid(w))
}

@(test)
disconnected_carrier_keeps_relic_until_rejoin_or_explicit_identity_replacement :: proc(t: ^testing.T) {
    w := carrier_world()
    before := w.relic
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 101)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 1, &ctx)
    testing.expect(t, reflect.equal(w.relic, before))
    testing.expect(t, !cave.act(&w, 2, cave.Action{verb = .Carry}, &ctx))
    testing.expect(t, !cave.act(&w, 1, cave.Action{verb = .Set_Down}, &ctx))
    // Descent may move a reserved avatar, but an absent owner cannot stream a prop.
    w.players[1].position = cave.floor(1).door
    w.door_open = true
    ctx = context_for(events[:], 102)
    cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
    testing.expect_value(t, w.depth, u8(2))
    testing.expect(t, reflect.equal(w.relic, before))
    ctx = context_for(events[:], 103)
    cave.step(&w, [cave.SEATS]cave.Control{}, 1, 0, &ctx)
    testing.expect_value(t, w.relic.carrier, u16(1))
    testing.expect_value(t, w.relic.version, u32(7))
    testing.expect_value(t, w.relic.position, w.players[0].position + ([2]f32{10, -12}))
    // Reusing a seat for a different identity must not grant the old relic.
    last := w.relic.position
    cave.reset_player(&w, 1, &ctx)
    testing.expect_value(t, w.relic.carrier, u16(0))
    testing.expect_value(t, w.relic.version, u32(8))
    testing.expect_value(t, w.relic.position, last)
}

carrier_replay_step :: proc(w: ^cave.World, leave: bool, ctx: ^r.Step(cave.Event)) {
    cave.step(w, [cave.SEATS]cave.Control{}, 0, leave ? 1 : 0, ctx)
}

@(test)
correcting_carrier_departure_restores_complete_state_and_events :: proc(t: ^testing.T) {
    initial := r.Frame(cave.World) {
        tick  = 100,
        state = carrier_world(),
    }
    left, right: r.Timeline(cave.World, bool, cave.Event)
    r.init(&left, initial, carrier_replay_step)
    r.init(&right, initial, carrier_replay_step)
    defer r.destroy(&left)
    defer r.destroy(&right)

    for tick in 101 ..= 105 {
        testing.expect_value(t, r.advance(&left, tick == 101).error, r.Error.None)
        testing.expect_value(t, r.advance(&right, false).error, r.Error.None)
    }

    testing.expect_value(t, r.revise_input(&left, 101, false).error, r.Error.None)
    a, _ := r.current(&left)
    b, _ := r.current(&right)
    testing.expect(t, reflect.equal(a, b))
    testing.expect_value(t, a.state.relic.carrier, u16(1))
    testing.expect_value(t, a.state.relic.version, u32(7))
    ea, eb: [32]r.Occurrence(cave.Event)

    for tick in 101 ..= 105 {
        na, _ := r.copy_events(&left, u64(tick), ea[:])
        nb, _ := r.copy_events(&right, u64(tick), eb[:])
        testing.expect_value(t, na, nb)
        testing.expect(t, reflect.equal(ea[:na], eb[:nb], true))
    }

    testing.expect_value(t, r.audit(&left, 101).error, r.Error.None)
}

@(test)
content6_carrier_conversion_retains_complete_frame_and_peer_values :: proc(t: ^testing.T) {
    names := [2]string{"dead", "disconnected"}

    for name in names {
        bytes, error := os.read_entire_file(
            fmt.tprintf("tests/replay_cave/fixtures/content6/%s.replay", name),
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
            net.checkpoint_decode(&old, bytes, upgrade.model6(), upgrade.CONTENT_6),
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
        cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
        testing.expect_value(t, w.relic.carrier, u16(1))
        testing.expect_value(t, w.relic.version, u32(7))
        testing.expect_value(t, w.relic.position, old.frame.state.relic.position)
        ctx = context_for(events[:], 104)
        cave.step(&w, [cave.SEATS]cave.Control{}, name == "disconnected" ? 1 : 0, 0, &ctx)
        testing.expect(t, w.players[0].connected && w.players[0].hp > 0)
        testing.expect_value(t, w.relic.carrier, u16(1))
        testing.expect_value(t, w.relic.version, u32(7))
        testing.expect_value(t, w.relic.position, w.players[0].position + ([2]f32{10, -12}))
    }
}
