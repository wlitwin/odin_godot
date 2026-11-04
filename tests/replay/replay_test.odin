package replay_test

import "core:reflect"
import "core:mem"
import "core:testing"
import r "godot:replay"
import loot "../../examples/replay_loot/game"

@(test)
contested_loot_replays_the_world_and_replaces_events :: proc(t: ^testing.T) {
    tl: loot.Timeline
    testing.expect_value(t, r.init(&tl, r.Frame(loot.World){state = loot.initial()}, loot.step), r.Error.None)
    defer r.destroy(&tl)
    inputs: [8]loot.Input
    inputs[0].players[0] = {
        take = true,
        fire = true,
        seq  = 1,
    }
    inputs[1].players[1] = {
        fire = true,
        seq  = 2,
    }

    for input in inputs {
        testing.expect_value(t, r.advance(&tl, input).error, r.Error.None)
    }

    before, _ := r.current(&tl)
    testing.expect_value(t, before.state.players[0].bag, u32(5))
    events: [4]r.Occurrence(loot.Event)
    n, err := r.copy_events(&tl, 1, events[:])
    testing.expect_value(t, err, r.Error.None)
    testing.expect_value(t, n, 2)
    shot_id := events[1].id

    inputs[0].players[0].take = false
    inputs[0].players[1].take = true
    inputs[0].players[1].seq = 1
    result := r.revise_input(&tl, 1, inputs[0])
    testing.expect_value(t, result.error, r.Error.None)
    testing.expect_value(t, result.steps, 8)
    after, _ := r.current(&tl)
    testing.expect_value(t, after.state.players[0].bag, u32(0))
    testing.expect_value(t, after.state.players[1].bag, u32(5))
    testing.expect_value(t, after.state.entities.count, u32(0))
    n, err = r.copy_events(&tl, 1, events[:])
    testing.expect_value(t, n, 2)
    testing.expect_value(t, err, r.Error.None)
    testing.expect_value(t, events[0].id, shot_id) // stable despite changed emit order
    testing.expect_value(t, events[1].value.player, u8(1))
    testing.expect_value(t, r.audit(&tl, 1).error, r.Error.None)

    // Snapshot reads and event reads cannot modify the stored timeline.
    after.state.players[1].bag = 900
    events[0].value.amount = 900
    stored, _ := r.current(&tl)
    testing.expect_value(t, stored.state.players[1].bag, u32(5))
    r.copy_events(&tl, 1, events[:])
    testing.expect_value(t, events[0].value.amount, u32(1))
}

@(test)
checkpoint_restores_rng_lifetime_and_allocation :: proc(t: ^testing.T) {
    tl: loot.Timeline
    r.init(&tl, r.Frame(loot.World){state = loot.initial()}, loot.step)
    defer r.destroy(&tl)
    sample := loot.Input{}
    sample.players[0] = {
        fire = true,
        seq  = 1,
    }
    r.advance(&tl, sample)
    checkpoint, _ := r.current(&tl)

    for _ in 0 ..< 7 {
        r.advance(&tl, sample)
    }

    want, _ := r.current(&tl)
    resumed: loot.Timeline
    testing.expect_value(t, r.init(&resumed, checkpoint, loot.step, epoch = 2), r.Error.None)
    defer r.destroy(&resumed)

    for _ in 0 ..< 7 {
        r.advance(&resumed, sample)
    }

    got, _ := r.current(&resumed)
    testing.expect(t, reflect.equal(got, want))
    events: [2]r.Occurrence(loot.Event)
    n, err := r.copy_events(&resumed, got.tick, events[:])
    testing.expect_value(t, err, r.Error.None)
    testing.expect_value(t, n, 1)
    testing.expect_value(t, events[0].id.epoch, u64(2))
}

Counter :: struct {
    value: i32,
}

Counter_Input :: struct {
    add:  i32,
    stop: bool,
}

Counter_Timeline :: r.Timeline(Counter, Counter_Input, i32)

counter_step :: proc(s: ^Counter, input: Counter_Input, ctx: ^r.Step(i32)) {
    s.value += input.add
    r.emit(ctx, 1, 1, s.value)

    if input.stop || s.value > 10 {
        r.abort(ctx)
    }
}

@(test)
failed_advance_and_late_replay_failure_are_atomic :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    r.init(&tl, r.Frame(Counter){}, counter_step)
    defer r.destroy(&tl)

    for _ in 0 ..< 3 {
        r.advance(&tl, Counter_Input{add = 3})
    }

    before, _ := r.current(&tl)
    testing.expect_value(t, r.advance(&tl, Counter_Input{add = 4}).error, r.Error.Aborted)
    // Revised tick 1 and tick 2 succeed; tick 3 fails. Nothing commits.
    result := r.revise_input(&tl, 1, Counter_Input{add = 5})
    testing.expect_value(t, result.error, r.Error.Aborted)
    testing.expect_value(t, result.steps, 2)
    testing.expect_value(t, result.tick, u64(3))
    after, _ := r.current(&tl)
    testing.expect(t, reflect.equal(before, after))
    first, _ := r.read(&tl, 1)
    testing.expect_value(t, first.state.value, i32(3))
    events: [1]r.Occurrence(i32)
    r.copy_events(&tl, 2, events[:])
    testing.expect_value(t, events[0].value, i32(6))
    testing.expect_value(t, r.audit(&tl, 1).error, r.Error.None) // old inputs survived too
}

@(test)
history_wrap_and_rewind_never_fall_back_to_current_state :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    r.init(&tl, r.Frame(Counter){}, counter_step, cfg = {history_frames = 4, events_per_tick = 1})
    defer r.destroy(&tl)
    _, zero := r.read(&tl, 0)
    testing.expect(t, zero)
    testing.expect_value(t, r.revise_input(&tl, 0, Counter_Input{}).error, r.Error.Initial_Frame)

    for _ in 0 ..< 5 {
        r.advance(&tl, Counter_Input{add = 1})
    }

    _, expired := r.read(&tl, 1)
    testing.expect(t, !expired)
    testing.expect_value(t, r.revise_input(&tl, 2, Counter_Input{}).error, r.Error.History_Missing)
    testing.expect_value(t, r.revise_input(&tl, 3, Counter_Input{add = 2}).error, r.Error.None)
    testing.expect_value(t, r.rewind(&tl, 3), r.Error.None)
    _, future := r.read(&tl, 4)
    testing.expect(t, !future)
    events: [1]r.Occurrence(i32)
    _, err := r.copy_events(&tl, 5, events[:])
    testing.expect_value(t, err, r.Error.History_Missing)
    r.advance(&tl, Counter_Input{add = 2})
    frame, _ := r.current(&tl)
    testing.expect_value(t, frame.tick, u64(4))
    testing.expect_value(t, frame.state.value, i32(6))
}

duplicate_step :: proc(s: ^Counter, input: Counter_Input, ctx: ^r.Step(i32)) {
    s.value += 1
    r.emit(ctx, 1, 7, 1)
    r.emit(ctx, 1, 7, 2)
}

@(test)
event_overflow_duplicates_and_short_output_do_not_leak :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    r.init(&tl, r.Frame(Counter){}, counter_step, cfg = {history_frames = 4, events_per_tick = 0})
    testing.expect_value(t, r.advance(&tl, Counter_Input{add = 1}).error, r.Error.Event_Capacity)
    f, _ := r.current(&tl)
    testing.expect_value(t, f.tick, u64(0))
    testing.expect_value(t, f.state.value, i32(0))
    r.destroy(&tl)
    r.init(&tl, r.Frame(Counter){}, duplicate_step)
    testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.Duplicate_Event)
    r.destroy(&tl)
    r.init(&tl, r.Frame(Counter){}, counter_step)
    defer r.destroy(&tl)
    r.advance(&tl, Counter_Input{add = 1})
    n, err := r.copy_events(&tl, 1, nil)
    testing.expect_value(t, n, 1)
    testing.expect_value(t, err, r.Error.Output_Too_Small)
}

@(test)
pool_handles_survive_restore_and_reject_recycled_slots :: proc(t: ^testing.T) {
    p: r.Pool(Counter, 2)
    a, ok := r.pool_insert(&p, Counter{value = 7})
    testing.expect(t, ok)
    saved := p
    testing.expect(t, r.pool_remove(&p, a))
    b, _ := r.pool_insert(&p, Counter{value = 8})
    testing.expect_value(t, a.index, b.index)
    testing.expect(t, a.generation != b.generation)
    _, stale := r.pool_get(&p, a)
    testing.expect(t, !stale)
    p = saved
    value, restored := r.pool_get(&p, a)
    testing.expect(t, restored)
    testing.expect_value(t, value.value, i32(7))
    _, future := r.pool_get(&p, b)
    testing.expect(t, !future)
    p.generations[1] = max(u32) // exhausted slot stays retired
    _, exhausted := r.pool_insert(&p, Counter{})
    testing.expect(t, !exhausted)
    _, invalid := r.pool_get(&p, r.Handle(Counter){index = max(u32), generation = 1})
    testing.expect(t, !invalid)
}

bad_step :: proc(s: ^[]i32, input: u8, ctx: ^r.Step(u8)) {}

@(test)
initialization_rejects_reference_state_and_invalid_contracts :: proc(t: ^testing.T) {
    testing.expect(t, r.value_supported(loot.World))
    testing.expect(t, r.value_supported(struct {
                tag:   u8,
                value: u64,
            })) // padding is legal
    testing.expect(t, !r.value_supported(struct {
                nested: [2]struct {
                    p: ^i32,
                },
            }))
    testing.expect(t, !r.value_supported([dynamic]i32))
    testing.expect(t, !r.value_supported(map[u32]u32))
    testing.expect(t, !r.value_supported(string))
    testing.expect(t, !r.value_supported(proc()))
    testing.expect(t, !r.value_supported(any))
    testing.expect(t, !r.value_supported(union {
                i32,
                ^i32,
            }))
    testing.expect(t, !r.value_supported(struct #raw_union {
                a: u32,
                b: f32,
            }))
    bad: r.Timeline([]i32, u8, u8)
    testing.expect_value(t, r.init(&bad, r.Frame([]i32){}, bad_step), r.Error.Unsupported_Value)
    r.destroy(&bad)
    tl: Counter_Timeline
    testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.Not_Initialized)
    testing.expect_value(t, r.init(&tl, r.Frame(Counter){}, counter_step, epoch = 0), r.Error.Invalid_Config)
    testing.expect_value(t, r.init(&tl, r.Frame(Counter){}, counter_step, cfg = {1, 0}), r.Error.Invalid_Config)
    testing.expect_value(t, r.init(&tl, r.Frame(Counter){tick = max(u64)}, counter_step), r.Error.None)
    defer r.destroy(&tl)
    testing.expect_value(t, r.init(&tl, r.Frame(Counter){}, counter_step), r.Error.Already_Initialized)
    testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.Tick_Overflow)
}

@(test)
runtime_keeps_allocator_ownership_and_replay_uses_preallocated_storage :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)
    owned_allocator := mem.tracking_allocator(&track)
    tl: Counter_Timeline
    testing.expect_value(t, r.init(&tl, r.Frame(Counter){}, counter_step, allocator = owned_allocator), r.Error.None)
    allocations := track.total_allocation_count

    // Catch accidental allocations from either the explicit or ambient allocator.
    {
        context.allocator = owned_allocator

        for _ in 0 ..< 6 {
            r.advance(&tl, Counter_Input{add = 1})
        }

        testing.expect_value(t, r.revise_input(&tl, 2, Counter_Input{add = 2}).error, r.Error.None)
        testing.expect_value(t, r.audit(&tl, 1).error, r.Error.None)
    }

    testing.expect_value(t, track.total_allocation_count, allocations)
    // Ambient context is back to the test allocator, different from init's owner.
    r.destroy(&tl)
    testing.expect_value(t, track.current_memory_allocated, i64(0))
    testing.expect_value(t, len(track.allocation_map), 0)
}

reentrant_timeline: ^Counter_Timeline

reentrant_step :: proc(s: ^Counter, input: Counter_Input, ctx: ^r.Step(i32)) {
    a := r.advance(reentrant_timeline, Counter_Input{})
    b := r.revise_input(reentrant_timeline, ctx.tick, Counter_Input{})
    c := r.rewind(reentrant_timeline, 0)

    if a.error == .Reentrant && b.error == .Reentrant && c == .Reentrant {
        s.value += 1
    }
}

@(test)
step_cannot_reenter_timeline_mutations :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    r.init(&tl, r.Frame(Counter){}, reentrant_step)
    defer r.destroy(&tl)
    reentrant_timeline = &tl
    defer reentrant_timeline = nil
    testing.expect_value(t, r.advance(&tl, Counter_Input{}).error, r.Error.None)
    f, _ := r.current(&tl)
    testing.expect_value(t, f.tick, u64(1))
    testing.expect_value(t, f.state.value, i32(1))
}

// Deliberately illegal hidden state proves audit sees a reproducibility failure.
hidden_value: i32

hidden_state_step :: proc(s: ^Counter, input: Counter_Input, ctx: ^r.Step(i32)) {
    s.value += hidden_value
}

hidden_event_step :: proc(s: ^Counter, input: Counter_Input, ctx: ^r.Step(i32)) {
    s.value += 1
    r.emit(ctx, 1, 1, hidden_value)
}

@(test)
audit_reports_state_and_event_divergence_without_committing :: proc(t: ^testing.T) {
    tl: Counter_Timeline
    hidden_value = 1
    r.init(&tl, r.Frame(Counter){}, hidden_state_step)
    r.advance(&tl, Counter_Input{})
    hidden_value = 2
    result := r.audit(&tl, 1)
    testing.expect_value(t, result.error, r.Error.Diverged_State)
    testing.expect_value(t, result.tick, u64(1))
    f, _ := r.current(&tl)
    testing.expect_value(t, f.state.value, i32(1))
    r.destroy(&tl)
    r.init(&tl, r.Frame(Counter){}, hidden_event_step)
    r.advance(&tl, Counter_Input{})
    hidden_value = 3
    testing.expect_value(t, r.audit(&tl, 1).error, r.Error.Diverged_Event)
    r.destroy(&tl)
}

@(test)
revised_corpus_matches_fresh_execution :: proc(t: ^testing.T) {
    rng := r.rng_make(12345)
    inputs: [24]loot.Input

    for &input, i in inputs {
        for &p in input.players {
            p.move = i8(r.rng_next(&rng) % 3) - 1
            p.fire = r.rng_next(&rng) % 3 == 0
            p.take = r.rng_next(&rng) % 2 == 0
            p.seq = u32(i + 1)
        }
    }

    tl: loot.Timeline
    r.init(&tl, r.Frame(loot.World){state = loot.initial()}, loot.step)
    defer r.destroy(&tl)

    for input in inputs {
        testing.expect_value(t, r.advance(&tl, input).error, r.Error.None)
    }

    for _ in 0 ..< 32 {
        at := int(r.rng_next(&rng) % u64(len(inputs)))
        inputs[at].players[0].take = !inputs[at].players[0].take
        inputs[at].players[1].fire = !inputs[at].players[1].fire
        testing.expect_value(t, r.revise_input(&tl, u64(at + 1), inputs[at]).error, r.Error.None)
        ref: loot.Timeline
        r.init(&ref, r.Frame(loot.World){state = loot.initial()}, loot.step)

        for input in inputs {
            r.advance(&ref, input)
        }

        got, _ := r.current(&tl)
        want, _ := r.current(&ref)
        testing.expect(t, reflect.equal(got, want))

        for tick in u64(1) ..= u64(len(inputs)) {
            a, b: [8]r.Occurrence(loot.Event)
            an, ae := r.copy_events(&tl, tick, a[:])
            bn, be := r.copy_events(&ref, tick, b[:])
            testing.expect_value(t, ae, r.Error.None)
            testing.expect_value(t, be, r.Error.None)
            testing.expect(t, reflect.equal(a[:an], b[:bn], true))
        }

        r.destroy(&ref)
    }
}
