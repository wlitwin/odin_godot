package replay_cave_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import cave "../../examples/replay_cavecrawl/shared/cave"

impact_world :: proc() -> cave.World {
    w := joined_world()

    for i in 0 ..< len(w.dwellers.alive) {
        if w.dwellers.alive[i] {
            r.pool_remove(&w.dwellers, r.Handle(cave.Dweller){u32(i), w.dwellers.generations[i]})
        }
    }

    _, ok := r.pool_insert(&w.dwellers, cave.Dweller{position = {200, 120}, home = {200, 120}, hp = 70})
    assert(ok)
    w.director = {
        wave = 1,
        done = true,
    }
    return w
}

impact_rock :: proc(w: ^cave.World) {
    _, ok := r.pool_insert(&w.rocks, cave.Rock{position = {180, 120}, velocity = {12, 0}, left = 24, shooter = 1})
    assert(ok)
}

@(test)
dweller_hits_keep_projectile_identity_target_generation_and_detached_pose :: proc(t: ^testing.T) {
    w := impact_world()
    generation := w.dwellers.generations[0]
    events: [8]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 2)
    impact_rock(&w)
    cave.step_rocks(&w, &ctx)
    testing.expect_value(t, ctx.error, r.Error.None)
    testing.expect_value(t, ctx.count, 1)
    hit := events[0]
    testing.expect_value(t, w.dwellers.values[0].hp, i32(35))
    testing.expect(
        t,
        hit.value.kind == .Hit &&
        hit.value.seat == 0 &&
        hit.value.amount == 35 &&
        hit.value.position == ([2]f32{200, 120}),
    )
    testing.expect_value(t, hit.id.key, u64(generation) << 32 | 1)
    impact_rock(&w)
    ctx = context_for(events[:], 3)
    cave.step_rocks(&w, &ctx)
    testing.expect_value(t, ctx.count, 2)
    testing.expect(
        t,
        events[0].value.kind == .Hit &&
        events[1].value.kind == .Slain &&
        events[0].id.key == hit.id.key &&
        events[0].id.source != hit.id.source,
    )
    testing.expect_value(t, w.dwellers.count, u32(0))
    handle, ok := r.pool_insert(&w.dwellers, cave.Dweller{position = {300, 200}, home = {300, 200}, hp = 70})
    testing.expect(t, ok)
    testing.expect(t, handle.generation != generation && events[0].value.position == ([2]f32{200, 120}))
}

@(test)
impact_events_replay_and_overflow_atomically_without_changing_damage_rules :: proc(t: ^testing.T) {
    initial := impact_world()
    impact_rock(&initial)
    old := initial
    events: [8]r.Occurrence(cave.Event)
    ctx := context_for(events[:], 2)
    cave.step_rocks(&old, &ctx, false)
    testing.expect_value(t, ctx.count, 0)
    current := initial
    ctx = context_for(events[:], 2)
    cave.step_rocks(&current, &ctx)
    testing.expect(t, reflect.equal(old, current))
    tl: r.Timeline(cave.World, bool, cave.Event)

    step := proc(w: ^cave.World, hit: bool, ctx: ^r.Step(cave.Event)) {
        if hit {
            cave.step_rocks(w, ctx)
        }
    }

    testing.expect_value(
        t,
        r.init(&tl, r.Frame(cave.World){tick = 1, state = initial}, step, cfg = {8, 8}),
        r.Error.None,
    )
    defer r.destroy(&tl)
    testing.expect_value(t, r.advance(&tl, true).error, r.Error.None)
    testing.expect_value(t, r.revise_input(&tl, 2, false).error, r.Error.None)
    no_hit, _ := r.current(&tl)
    testing.expect(t, reflect.equal(no_hit.state, initial))
    testing.expect_value(t, r.revise_input(&tl, 2, true).error, r.Error.None)
    hit, _ := r.current(&tl)
    testing.expect(t, reflect.equal(hit.state, current))
    // A full occurrence budget fails the entire step, retaining the original rock
    // and victim; it cannot apply damage while dropping required feedback.
    tiny: r.Timeline(cave.World, bool, cave.Event)

    crowded := proc(w: ^cave.World, _: bool, ctx: ^r.Step(cave.Event)) {
        r.emit(ctx, 99, 99, cave.Event{kind = .Door})
        cave.step_rocks(w, ctx)
    }

    testing.expect_value(
        t,
        r.init(&tiny, r.Frame(cave.World){tick = 1, state = initial}, crowded, cfg = {8, 1}),
        r.Error.None,
    )
    defer r.destroy(&tiny)
    testing.expect_value(t, r.advance(&tiny, true).error, r.Error.Event_Capacity)
    untouched, _ := r.current(&tiny)
    testing.expect(t, untouched.tick == 1 && reflect.equal(untouched.state, initial))
}
