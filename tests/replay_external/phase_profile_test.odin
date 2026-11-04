package replay_external_test

import "core:testing"
import r "godot:replay"
import f "fixture"

@(private)
@(thread_local)
phase_now: u64
@(private)
@(thread_local)
phase_reads: u64
@(private)
@(thread_local)
phase_backward_open: bool

phase_clock :: proc() -> u64 {
    phase_reads += 1
    return phase_now
}

phase_open :: proc(pointer: rawptr) -> (rawptr, r.Error) {
    if phase_backward_open {
        phase_now = 0
    } else {
        phase_now += 11
    }

    return f.open(pointer)
}

phase_close :: proc(pointer: rawptr) {
    phase_now += 17
    f.close(pointer)
}

phase_release :: proc(pointer: rawptr) {
    phase_now += 13
    f.release(pointer)
}

phase_capture :: proc(pointer: rawptr) -> (rawptr, u64, r.Error) {
    phase_now += 37
    return f.capture(pointer)
}

phase_step :: proc(game: ^f.Game, input: f.Input, ctx: ^r.Step(i64)) {
    phase_now += 23
    f.step(game, input, ctx)
}

phase_initial :: proc(t: ^testing.T, stats: ^f.Stats) -> (r.Complete_Checkpoint(f.Game, i64), ^f.Domain) {
    domain := new(f.Domain)
    domain^ = {
        refs      = 1,
        allocator = context.allocator,
        stats     = stats,
    }
    stats.domains += 1
    external := r.External {
        identity = f.IDENTITY,
        contract = f.CONTRACT,
        clone = f.clone,
        release = phase_release,
        open = phase_open,
        close = phase_close,
        capture = phase_capture,
        equal = f.equal,
        admit = f.admit,
        clock = phase_clock,
        limits = {history_frames = 2},
    }
    checkpoint, error := r.complete_checkpoint_adopt(
        r.Frame(f.Game){},
        i64,
        external,
        f.image_make(domain, 0),
        size_of(f.Image),
    )
    testing.expect_value(t, error, r.Error.None)
    return checkpoint, domain
}

@(test)
transaction_phases_have_independent_work_durations_and_include_cleanup_only_in_total :: proc(t: ^testing.T) {
    phase_now = 0
    phase_reads = 0
    phase_backward_open = false
    stats: f.Stats
    initial, domain := phase_initial(t, &stats)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, phase_step, {2, 4}), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 3}).error, r.Error.None)
    p := timeline.external_profile
    testing.expect_value(t, p.open.total_ns, u64(11))
    testing.expect_value(t, p.model.total_ns, u64(23))
    testing.expect_value(t, p.capture.total_ns, u64(37))
    testing.expect_value(t, p.open.samples, u64(1))
    testing.expect_value(t, p.model.samples, u64(1))
    testing.expect_value(t, p.capture.samples, u64(1))
    testing.expect_value(t, p.last_work_ns, u64(71))
    testing.expect_value(t, p.last_total_ns, u64(88))
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 4}).error, r.Error.None)
    p = timeline.external_profile
    // Ring replacement releases the old image; publication retires the old
    // execution. Their13+17 units belong to total, not preparation or phases.
    testing.expect_value(t, p.last_work_ns, u64(71))
    testing.expect_value(t, p.last_total_ns, u64(101))
    testing.expect_value(t, p.capture.samples, u64(1))
    saved, error := r.capture_complete(&timeline, timeline.head)
    testing.expect_value(t, error, r.Error.None)
    testing.expect_value(t, saved.frame.state.sum, i64(7))
    testing.expect_value(t, f.value(&saved), i64(7))
    r.complete_checkpoint_destroy(&saved)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    f.drop(domain)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}

@(test)
disabled_clock_has_no_reads_or_stale_phase_samples :: proc(t: ^testing.T) {
    phase_now = 0
    phase_reads = 0
    phase_backward_open = false
    stats: f.Stats
    initial, domain := phase_initial(t, &stats)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, phase_step, {2, 4}), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 3}).error, r.Error.None)
    timeline.external.clock = nil
    reads := phase_reads
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 4}).error, r.Error.None)
    testing.expect_value(t, phase_reads, reads)
    p := timeline.external_profile
    testing.expect(t, p.open.samples == 0 && p.model.samples == 0 && p.capture.samples == 0)
    testing.expect(t, p.open.total_ns == 0 && p.model.total_ns == 0 && p.capture.total_ns == 0)
    saved, error := r.capture_complete(&timeline, timeline.head)
    testing.expect_value(t, error, r.Error.None)
    testing.expect_value(t, saved.frame.state.sum, i64(7))
    testing.expect_value(t, f.value(&saved), i64(7))
    r.complete_checkpoint_destroy(&saved)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    f.drop(domain)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}

@(test)
failed_capture_records_attempt_duration_without_publishing_candidate :: proc(t: ^testing.T) {
    phase_now = 0
    phase_reads = 0
    phase_backward_open = false
    stats: f.Stats
    initial, domain := phase_initial(t, &stats)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, phase_step, {2, 4}), r.Error.None)
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 3}).error, r.Error.None)
    domain.fail_at[.Capture] = domain.calls[.Capture] + 1
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 100}).error, r.Error.External_State)
    testing.expect_value(t, timeline.head, u64(1))
    testing.expect_value(t, timeline.external_profile.capture.total_ns, u64(37))
    testing.expect_value(t, timeline.external_profile.capture.samples, u64(1))
    testing.expect_value(t, timeline.external_profile.capture.errors, u64(0))
    saved, error := r.capture_complete(&timeline, timeline.head)
    testing.expect_value(t, error, r.Error.None)
    testing.expect_value(t, saved.frame.state.sum, i64(3))
    testing.expect_value(t, f.value(&saved), i64(3))
    r.complete_checkpoint_destroy(&saved)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    f.drop(domain)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}

@(test)
backward_phase_clock_is_diagnostic_and_does_not_abort_simulation :: proc(t: ^testing.T) {
    phase_now = 0
    phase_reads = 0
    phase_backward_open = false
    stats: f.Stats
    initial, domain := phase_initial(t, &stats)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &initial, phase_step, {2, 4}), r.Error.None)
    phase_now = 100
    phase_backward_open = true
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 3}).error, r.Error.None)
    testing.expect_value(t, timeline.external_profile.open.samples, u64(0))
    testing.expect_value(t, timeline.external_profile.open.errors, u64(1))
    saved, error := r.capture_complete(&timeline, timeline.head)
    testing.expect_value(t, error, r.Error.None)
    testing.expect_value(t, saved.frame.state.sum, i64(3))
    testing.expect_value(t, f.value(&saved), i64(3))
    phase_backward_open = false
    r.complete_checkpoint_destroy(&saved)
    r.destroy(&timeline)
    r.complete_checkpoint_destroy(&initial)
    f.drop(domain)
    testing.expect(t, stats.images == 0 && stats.executions == 0 && stats.domains == 0)
}
