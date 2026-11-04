package replay_cave_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import cave "../../examples/replay_cavecrawl/shared/cave"

adoption_step :: proc(w: ^cave.World, authority: net.Authority_Observation, ctx: ^r.Step(cave.Event)) {
    cave.observe_authority(w, authority, ctx)

    if ctx.error == .None {
        cave.step(w, [cave.SEATS]cave.Control{}, 0, 0, ctx)
    }
}

@(test)
old_host_prop_adoption_is_once_per_change_and_replayable :: proc(t: ^testing.T) {
    w := carrier_world()
    w.authority_known = true
    w.authority_seat = 1
    old_avatar := w.players[0]
    left, right: r.Timeline(cave.World, net.Authority_Observation, cave.Event)
    initial := r.Frame(cave.World) {
        tick  = 100,
        state = w,
    }
    r.init(&left, initial, adoption_step)
    r.init(&right, initial, adoption_step)
    defer r.destroy(&left)
    defer r.destroy(&right)

    for tick in 101 ..= 104 {
        testing.expect_value(t, r.advance(&left, net.Authority_Observation{true, 2}).error, r.Error.None)
        testing.expect_value(
            t,
            r.advance(&right, net.Authority_Observation{true, tick == 101 ? 1 : 2}).error,
            r.Error.None,
        )
    }

    testing.expect_value(t, r.revise_input(&left, 101, net.Authority_Observation{true, 1}).error, r.Error.None)
    a, _ := r.current(&left)
    b, _ := r.current(&right)
    testing.expect(t, reflect.equal(a, b))
    testing.expect_value(t, a.state.relic.carrier, u16(2))
    testing.expect_value(t, a.state.relic.version, u32(8))
    testing.expect_value(t, a.state.relic.position, a.state.players[1].position + ([2]f32{10, -12}))
    testing.expect_value(t, a.state.players[0].position, old_avatar.position)
    ea, eb: [32]r.Occurrence(cave.Event)
    adopted := 0

    for tick in 101 ..= 104 {
        na, _ := r.copy_events(&left, u64(tick), ea[:])
        nb, _ := r.copy_events(&right, u64(tick), eb[:])
        testing.expect_value(t, na, nb)
        testing.expect(t, reflect.equal(ea[:na], eb[:nb], true))

        for event in ea[:na] {
            if event.value.kind == .Carry {
                adopted += 1
                testing.expect_value(t, event.value.seat, u16(2))
            }
        }
    }

    testing.expect_value(t, adopted, 1)
    testing.expect_value(t, r.audit(&left, 101).error, r.Error.None)
}

@(test)
authority_observation_preserves_other_carriers_and_aborts_overflow_atomically :: proc(t: ^testing.T) {
    w := carrier_world()
    w.authority_known = true
    w.authority_seat = 2
    events: [32]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 101)
    before := w.relic
    cave.observe_authority(&w, {true, 1}, &ctx)
    testing.expect(t, reflect.equal(w.relic, before))
    w.relic.version = max(u32)
    timeline: r.Timeline(cave.World, net.Authority_Observation, cave.Event)
    r.init(&timeline, r.Frame(cave.World){state = w}, adoption_step)
    defer r.destroy(&timeline)
    testing.expect_value(t, r.advance(&timeline, net.Authority_Observation{true, 2}).error, r.Error.Aborted)
    current, _ := r.current(&timeline)
    testing.expect(t, reflect.equal(current.state, w))
    testing.expect_value(t, timeline.head, u64(0))
    // A dedicated successor has no avatar to carry a prop, so adoption releases it.
    w.relic.version = 7
    ctx = context_for(events[:], 102)
    cave.observe_authority(&w, {true, 0}, &ctx)
    testing.expect_value(t, w.relic.carrier, u16(0))
    testing.expect_value(t, w.relic.version, u32(8))
}
