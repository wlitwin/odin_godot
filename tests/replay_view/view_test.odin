package replay_view_test

import "core:math"
import "core:testing"
import r "godot:replay"
import v "godot:replay/view"
import p "godot:replay/play"

Event :: struct {
    mode:     v.Policy,
    amount:   i32,
    position: [2]f32,
}

policy :: proc(e: Event) -> v.Policy {
    return e.mode
}

occ :: proc(tick, key: u64, mode := v.Policy.Speculative, amount: i32 = 1) -> r.Occurrence(Event) {
    return {{epoch = 1, tick = tick, source = 1, key = key}, {mode = mode, amount = amount}}
}

@(test)
speculation_updates_cancels_and_confirms_without_restarting :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    testing.expect_value(t, v.journal_init(&j), v.Error.None)
    v.journal_set_policy(&j, policy)
    defer v.journal_destroy(&j)
    batch := [2]r.Occurrence(Event){occ(1, 10), occ(1, 20)}
    out: [8]v.Change(Event)
    testing.expect_value(t, v.sync_tick(&j, 1, batch[:]), v.Error.None)
    testing.expect_value(t, v.drain(&j, out[:]), 2)
    testing.expect_value(t, out[0].kind, v.Change_Kind.Begin)
    v.sync_tick(&j, 1, batch[:])
    testing.expect_value(t, v.drain(&j, out[:]), 0)
    batch[1].value.amount = 9
    v.sync_tick(&j, 1, batch[1:])
    testing.expect_value(t, v.drain(&j, out[:]), 2)
    testing.expect_value(t, out[0].kind, v.Change_Kind.Cancel)
    testing.expect_value(t, out[0].occurrence.id.key, u64(10))
    testing.expect_value(t, out[1].kind, v.Change_Kind.Update)
    testing.expect_value(t, out[1].previous.amount, i32(1))
    testing.expect_value(t, out[1].occurrence.value.amount, i32(9))
    v.advance_time(&j, 1, 1)
    testing.expect_value(t, v.drain(&j, out[:]), 1)
    testing.expect_value(t, out[0].kind, v.Change_Kind.Confirm)
    testing.expect(t, out[0].confirmed)
    testing.expect_value(t, v.sync_tick(&j, 1, nil), v.Error.Confirmed_Changed)
    testing.expect_value(t, v.drain(&j, out[:]), 0)
}

@(test)
confirmed_and_watched_effects_wait_for_their_own_clock :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    v.journal_init(&j)
    v.journal_set_policy(&j, policy)
    defer v.journal_destroy(&j)
    batch := [2]r.Occurrence(Event){occ(1, 1, .Confirmed), occ(1, 2, .Watched)}
    out: [8]v.Change(Event)
    v.sync_tick(&j, 1, batch[:])
    testing.expect_value(t, v.drain(&j, out[:]), 0)
    testing.expect_value(t, v.advance_time(&j, 1, 0), v.Error.None)
    testing.expect_value(t, v.drain(&j, out[:]), 1)
    testing.expect_value(t, out[0].kind, v.Change_Kind.Begin)
    testing.expect(t, out[0].confirmed)
    testing.expect_value(t, out[0].occurrence.id.key, u64(1))
    // Source payload is retained even if the gameplay entity/source has died.
    batch[1].value.amount = 100
    v.advance_time(&j, 1, 1)
    testing.expect_value(t, v.drain(&j, out[:]), 1)
    testing.expect_value(t, out[0].occurrence.value.amount, i32(1))
    testing.expect_value(t, out[0].occurrence.id.key, u64(2))
    testing.expect_value(t, v.advance_time(&j, 0, 1), v.Error.Time_Reversed)
}

@(test)
queue_backpressure_never_partially_changes_the_journal :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    v.journal_init(&j, cfg = {history_ticks = 4, events_per_tick = 1, queue_capacity = 2})
    defer v.journal_destroy(&j)
    a := [1]r.Occurrence(Event){occ(1, 1)}
    b := [1]r.Occurrence(Event){occ(2, 1)}
    v.sync_tick(&j, 1, a[:])
    v.sync_tick(&j, 2, b[:])
    a[0].value.amount = 5
    testing.expect_value(t, v.sync_tick(&j, 1, a[:]), v.Error.Output_Full)
    testing.expect_value(t, v.advance_time(&j, 2, 2), v.Error.Output_Full)
    testing.expect_value(t, j.confirmed, u64(0))
    out: [2]v.Change(Event)
    testing.expect_value(t, v.drain(&j, out[:1]), 1)
    testing.expect_value(t, v.sync_tick(&j, 1, a[:]), v.Error.None)
    testing.expect_value(t, v.drain(&j, out[:]), 2)
    testing.expect_value(t, out[1].kind, v.Change_Kind.Update)
    testing.expect_value(t, out[1].previous.amount, i32(1))
    testing.expect_value(t, v.advance_time(&j, 2, 2), v.Error.None)
    testing.expect_value(t, v.drain(&j, out[:]), 2)
}

@(test)
history_bounds_duplicates_epochs_and_confirmed_changes_are_explicit :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    v.journal_init(&j, cfg = {2, 2, 8})
    v.journal_set_policy(&j, policy)
    defer v.journal_destroy(&j)
    x := [2]r.Occurrence(Event){occ(1, 1, .Watched), occ(1, 1, .Watched)}
    testing.expect_value(t, v.sync_tick(&j, 1, x[:]), v.Error.Duplicate_Event)
    x[0].id.epoch = 2
    testing.expect_value(t, v.sync_tick(&j, 1, x[:1]), v.Error.Bad_Epoch)
    x[0] = occ(1, 1, .Watched)
    v.sync_tick(&j, 1, x[:1])
    testing.expect_value(t, v.advance_time(&j, 2, 0), v.Error.Missing_History)
    v.sync_tick(&j, 2, nil)
    v.advance_time(&j, 2, 0)
    testing.expect_value(t, v.sync_tick(&j, 3, nil), v.Error.Capacity) // pending watched event
    v.advance_time(&j, 2, 2)
    testing.expect_value(t, v.sync_tick(&j, 3, nil), v.Error.None)
    testing.expect_value(t, v.sync_tick(&j, 1, x[:1]), v.Error.Expired)
    testing.expect_value(t, v.sync_tick(&j, 20, nil), v.Error.Capacity)
    testing.expect_value(t, v.sync_tick(&j, 2, x[:1]), v.Error.Bad_Tick)
}

@(test)
maximum_tick_and_rejoin_baseline_do_not_replay_old_effects :: proc(t: ^testing.T) {
    j: v.Journal(Event)
    v.journal_init(&j, baseline = max(u64) - 1)
    v.journal_set_policy(&j, policy)
    defer v.journal_destroy(&j)
    x := [1]r.Occurrence(Event){occ(max(u64), 1, .Confirmed)}
    testing.expect_value(t, v.sync_tick(&j, max(u64) - 1, nil), v.Error.Expired)
    testing.expect_value(t, v.sync_tick(&j, max(u64), x[:]), v.Error.None)
    testing.expect_value(t, v.advance_time(&j, max(u64), max(u64)), v.Error.None)
    out: [2]v.Change(Event)
    testing.expect_value(t, v.drain(&j, out[:]), 1)
    testing.expect_value(t, out[0].kind, v.Change_Kind.Begin)
}

@(test)
fixed_step_clock_preserves_short_presses_and_bounds_stalls :: proc(t: ^testing.T) {
    c: r.Clock
    testing.expect(t, r.clock_init(&c, 60, 4))
    b: r.Buttons
    r.buttons_set(&b, 1)
    n, ok := r.clock_add(&c, 1.0 / 120)
    testing.expect(t, ok)
    testing.expect_value(t, n, u32(0))
    r.buttons_set(&b, 0) // down and up before a tick: preserve both transitions
    n, _ = r.clock_add(&c, 1.0 / 120)
    testing.expect_value(t, n, u32(1))
    testing.expect_value(t, b.pressed, u64(1))
    testing.expect_value(t, b.released, u64(1))
    testing.expect(t, r.clock_consume(&c))
    r.buttons_consume(&b)
    testing.expect_value(t, b.pressed, u64(0))
    n, _ = r.clock_add(&c, 30)
    testing.expect_value(t, n, u32(4))
    testing.expect(t, c.dropped_seconds > 29)

    for _ in 0 ..< 4 {
        testing.expect(t, r.clock_consume(&c))
    }

    testing.expect(t, !r.clock_consume(&c))
    c.paused = true
    n, _ = r.clock_add(&c, 10)
    testing.expect_value(t, n, u32(0))
    c.paused = false
    n, _ = r.clock_add(&c, 0)
    testing.expect_value(t, n, u32(0))
    _, ok = r.clock_add(&c, -1)
    testing.expect(t, !ok)
}

@(test)
render_rates_deliver_the_same_number_of_simulation_ticks :: proc(t: ^testing.T) {
    rates := [4]u32{30, 60, 120, 144}

    for fps in rates {
        c: r.Clock
        r.clock_init(&c)
        total := 0

        for _ in 0 ..< fps * 10 {
            n, _ := r.clock_add(&c, 1.0 / f64(fps))

            for _ in 0 ..< n {
                r.clock_consume(&c)
                total += 1
            }
        }

        testing.expect_value(t, total, 600)
    }
}

@(test)
presentation_smooths_only_its_own_copy_and_cuts_teleports :: proc(t: ^testing.T) {
    truth := v.Pose2 {
        position = {10, 0},
    }
    s: v.Smoother2
    v.smooth_present(&s, truth, 0)
    truth.position[0] = 20
    v.smooth_rebase(&s, truth)
    shown := v.smooth_present(&s, truth, 0.08)
    testing.expect(t, abs(shown.position[0] - 15) < 0.001)
    testing.expect_value(t, truth.position[0], f32(20))
    truth.position[0] = 200
    v.smooth_rebase(&s, truth)
    shown = v.smooth_present(&s, truth, 0)
    testing.expect_value(t, shown.position[0], f32(200))
    a := v.Pose2 {
        angle = math.PI - 0.1,
    }
    b := v.Pose2 {
        angle    = -math.PI + 0.1,
        position = {50, 0},
    }
    blend := v.pose_blend(a, b, 0.5)
    testing.expect(t, abs(blend.angle - math.PI) < 0.001)
    testing.expect_value(t, v.pose_blend(a, b, 0.1, true), b)
}

@(test)
kinematic_movement_sweeps_static_walls_and_slides :: proc(t: ^testing.T) {
    b := p.Body2 {
        position  = {0, 0},
        half_size = {1, 1},
    }
    walls := [1]p.Aabb2{{min = {10, -20}, max = {12, 20}}}
    hit := p.move(&b, {100, 5}, walls[:])
    testing.expect(t, hit[0] && !hit[1])
    testing.expect_value(t, b.position, [2]f32{9, 5})
    p.move(&b, {-4, 1}, walls[:])
    testing.expect_value(t, b.position, [2]f32{5, 6})
    c := p.Cooldown{}
    testing.expect(t, p.cooldown_ready(&c))
    p.cooldown_arm(&c, 2)
    p.cooldown_tick(&c)
    testing.expect(t, !p.cooldown_ready(&c))
    p.cooldown_tick(&c)
    testing.expect(t, p.cooldown_ready(&c))
}
