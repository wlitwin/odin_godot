package replay_cave_test

import "core:testing"
import "core:reflect"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import cave "../../examples/replay_cavecrawl/shared/cave"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"

@(test)
authored_values_remain_owned_and_support_more_than_two_waves :: proc(t: ^testing.T) {
    definitions := cave.FLOORS
    definitions[0].gems, definitions[0].torches = 7, 31
    definitions[0].wave_count = 3
    definitions[0].waves = {
        0 = 0,
        1 = 0,
        2 = 0,
    }
    definitions[0].rests = {}
    w := cave.initial(floors = definitions)
    definitions[0].gems = 99
    testing.expect_value(t, w.chest[0].count, u16(7))
    testing.expect_value(t, w.chest[1].count, u16(31))
    testing.expect(t, cave.state_valid(w))
    events: [32]r.Occurrence(cave.Event)
    ctx := r.Step(cave.Event) {
        epoch  = 1,
        events = events[:],
    }

    for tick in 1 ..= 4 {
        ctx.tick, ctx.count = u64(tick), 0
        cave.step(&w, [cave.SEATS]cave.Control{}, tick == 1 ? 1 : 0, 0, &ctx)
    }

    testing.expect(t, w.director.done && w.director.wave == 3)
    w.players[0].position = cave.world_floor(&w).chest
    testing.expect(t, cave.act(&w, 1, cave.Action{verb = .Take, index = 1}, &ctx))
    testing.expect_value(t, w.chest[1].count, u16(1))
    testing.expect_value(t, cave.world_items(&w, cave.TORCH), u32(31))
    testing.expect(t, cave.state_valid(w))
}

@(test)
zero_stock_and_invalid_definition_bounds_are_explicit :: proc(t: ^testing.T) {
    defs := cave.FLOORS
    defs[0].gems, defs[0].torches = 0, 0
    w := cave.initial(floors = defs)
    testing.expect(t, cave.state_valid(w))
    testing.expect_value(t, w.chest[0].count, u16(0))
    testing.expect_value(t, w.chest[0].item, cave.GEM - cave.GEM)
    bad := defs[0]
    bad.wave_count = 0
    testing.expect(t, !cave.floor_valid(bad))
    bad = defs[0]
    bad.waves[7] = 1
    testing.expect(t, !cave.floor_valid(bad))
    bad = defs[0]
    bad.dens[0][0] = 700
    testing.expect(t, !cave.floor_valid(bad))
    w.director.wave = 0
    w.director.remaining = 1
    testing.expect(t, !cave.state_valid(w))
    w.director = {}
    w.director.wave = 3
    testing.expect(t, !cave.state_valid(w))
    w.director.wave = 1
    w.director.remaining = 256
    testing.expect(t, !cave.state_valid(w))
}

@(test)
old_archive_conversion_preserves_legacy_world_fields_and_adds_default_definitions :: proc(t: ^testing.T) {
    bytes, err := os.read_entire_file("tests/replay_cave/fixtures/content1/cave.replay", context.allocator)
    defer delete(bytes)
    testing.expect(t, err == nil)

    if err != nil {
        return
    }

    old: net.Checkpoint(upgrade.Legacy_World, cave.Control, upgrade.Legacy_Action, cave.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(
        t,
        net.checkpoint_decode(&old, bytes, upgrade.legacy_model(), upgrade.CONTENT_1),
        net.Error.None,
    )
    converted, result := upgrade.convert_archive(bytes)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)

    if result != .None {
        return
    }

    current: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, converted, cave.model(), cave.CONTENT), net.Error.None)
    expected, ok := upgrade.convert_world(old.frame.state)
    expected.authority_known = true
    expected.authority_seat = old.header.local_seat
    testing.expect(t, ok && reflect.equal(current.frame.state, expected))
    testing.expect_value(t, current.frame.tick, old.frame.tick)
    testing.expect_value(t, current.header.epoch, old.header.epoch)
    testing.expect(t, reflect.equal(current.peers[:], old.peers[:], true))
    testing.expect(t, reflect.equal(current.frame.state.floors, cave.FLOORS))
}

@(test)
content2_archive_maps_world_and_action_schemas_together :: proc(t: ^testing.T) {
    bytes, err := os.read_entire_file("tests/replay_cave/fixtures/content2/cave.replay", context.allocator)
    defer delete(bytes)
    testing.expect(t, err == nil)

    if err != nil {
        return
    }

    old: net.Checkpoint(upgrade.World_2, cave.Control, upgrade.Legacy_Action, cave.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(t, net.checkpoint_decode(&old, bytes, upgrade.model2(), upgrade.CONTENT_2), net.Error.None)
    converted, result := upgrade.convert_archive(bytes)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)

    if result != .None {
        return
    }

    current: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
    defer net.checkpoint_destroy(&current)
    testing.expect_value(t, net.checkpoint_decode(&current, converted, cave.model(), cave.CONTENT), net.Error.None)
    expected, ok := upgrade.convert_world2(old.frame.state)
    expected.authority_known = true
    expected.authority_seat = old.header.local_seat
    testing.expect(t, ok && reflect.equal(current.frame.state, expected))
    testing.expect_value(t, current.frame.tick, old.frame.tick)
    testing.expect_value(t, current.header.epoch, old.header.epoch)
    testing.expect(t, reflect.equal(current.peers[:], old.peers[:], true))
    testing.expect_value(t, current.frame.state.lobby.run, u32(1))
}
