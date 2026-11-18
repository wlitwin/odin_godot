package replay_cave_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import cave "../../examples/replay_cavecrawl/shared/cave"

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
saved_definitions_are_values_independent_of_live_defaults :: proc(t: ^testing.T) {
    cp := load_current_fixture("definitions")
    defer net.checkpoint_destroy(&cp)
    testing.expect(t, cp.frame.tick == 82 && cp.header.epoch == 1 && len(cp.peers) == 1)
    testing.expect(t, cp.frame.state.authority_known && cp.frame.state.authority_seat == cp.header.local_seat)
    testing.expect(t, cp.frame.state.floors[0].gems == 3 && cp.frame.state.floors[1].gems == 5)
    defaults := cave.FLOORS
    defaults[0].gems = 99
    other := cave.initial(floors = defaults)
    testing.expect(t, other.floors[0].gems == 99 && cp.frame.state.floors[0].gems == 3)
}

@(test)
saved_lobby_and_membership_use_the_current_checkpoint_contract :: proc(t: ^testing.T) {
    cp := load_current_fixture("lobby")
    defer net.checkpoint_destroy(&cp)
    testing.expect(t, cp.frame.tick == 82 && cp.header.epoch == 1 && len(cp.peers) == 1)
    testing.expect(t, cp.frame.state.authority_known && cp.frame.state.authority_seat == cp.header.local_seat)
    testing.expect_value(t, cp.frame.state.lobby.run, u32(1))
    testing.expect(t, cp.peers[0].local && cp.peers[0].active && cp.peers[0].seat == cp.header.local_seat)
}
