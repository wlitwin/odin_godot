package presentation_native_test

import "core:mem"
import "core:testing"
import b "godot:box3d"
import p "godot:box3d/presentation"
import kp "godot:kit/physics"
import k "godot:kit/sim"
import r "godot:replay"
import rg "godot:replay/godot"
import ph "godot:replay/physics"
import v "godot:replay/view"

checkpoint_bytes :: proc(t: ^testing.T, cp: ^r.Complete_Checkpoint($S, $E)) -> []u8 {
    n, error := ph.dump(cp, nil)
    ok(t, error)
    data := make([]u8, int(n))
    _, fill := ph.dump(cp, data)
    ok(t, fill)
    return data
}

ok :: proc(t: ^testing.T, e: r.Error) {
    testing.expect_value(t, e, r.Error.None)
}

read_replay :: proc(t: ^testing.T, cp: ^r.Complete_Checkpoint(Game, Event), revision: u64) -> p.Frame {
    frame, ve, error := rg.physics_presentation_frame(cp, project, revision, .Predicted)
    ok(t, error)
    testing.expect_value(t, ve, p.Error.None)
    return frame
}

read_kit :: proc(t: ^testing.T, cp: ^k.World_Checkpoint, epoch, revision: u64) -> p.Frame {
    frame, ve, error := kp.presentation_frame(cp, epoch, Game, project, revision, .Predicted)
    testing.expect_value(t, error, k.World_Error.Ok)
    testing.expect_value(t, ve, p.Error.None)
    return frame
}

@(test)
replay_actual_revision_abort_epoch_and_source_destruction :: proc(t: ^testing.T) {
    seed, e := initial()
    ok(t, e)
    timeline: r.Timeline(Game, Input, Event)
    ok(t, r.init_complete(&timeline, &seed, replay_step, {128, 4}))
    r.complete_checkpoint_destroy(&seed)

    for _ in 0 ..< 6 {
        ok(t, r.advance(&timeline, Input{}).error)
    }

    cp, ce := r.capture_complete(&timeline, 6)
    ok(t, ce)
    before := read_replay(t, &cp, 0)
    journal: v.Journal(Event)
    testing.expect_value(t, v.journal_init(&journal, 1, 0, {128, 4, 64}), v.Error.None)
    defer v.journal_destroy(&journal)
    actual: [4]r.Occurrence(Event)
    delivered: [32]v.Change(Event)

    for tick in u64(1) ..= 6 {
        count, copy_error := r.copy_events(&timeline, tick, actual[:])
        ok(t, copy_error)
        testing.expect_value(t, v.sync_tick(&journal, tick, actual[:count]), v.Error.None)
    }

    testing.expect_value(t, v.drain(&journal, delivered[:]), 6)
    initial_fx := cp.events[0]
    change := v.Change(Event) {
        kind       = .Begin,
        occurrence = initial_fx,
        confirmed  = false,
    }
    observed, valid := rg.physics_effect_observation(change, effect_project)
    testing.expect(t, valid && observed.kind == .Begin && !observed.confirmed)
    // An aborted action/tick emits no published effect and no new image.
    testing.expect_value(t, r.revise_input(&timeline, 4, Input{impulse = 1, abort = true}).error, r.Error.Aborted)
    after_abort, ae := r.capture_complete(&timeline, 6)
    ok(t, ae)
    left, right := checkpoint_bytes(t, &cp), checkpoint_bytes(t, &after_abort)
    testing.expect(
        t,
        mem.compare(left, right) == 0 && cp.frame == after_abort.frame && len(cp.events) == len(after_abort.events),
    )
    delete(left)
    delete(right)
    r.complete_checkpoint_destroy(&after_abort)
    ok(t, r.revise_input(&timeline, 3, Input{impulse = 1}).error)
    revised, re := r.capture_complete(&timeline, 6)
    ok(t, re)
    corrected := read_replay(t, &revised, 1)
    testing.expect(t, corrected.rows[0].pose.position.x != before.rows[0].pose.position.x)
    view: p.View
    changes: [70]p.Change
    _, ve := p.present(&view, nil, &before, 1, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    _, ve = p.present(&view, &before, &corrected, .1, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    testing.expect(t, !changes[0].interpolated && changes[0].row.pose == corrected.rows[0].pose)

    // A real corrected payload updates its existing stable ID, without another Begin.
    for tick in u64(1) ..= 6 {
        count, copy_error := r.copy_events(&timeline, tick, actual[:])
        ok(t, copy_error)
        testing.expect_value(t, v.sync_tick(&journal, tick, actual[:count]), v.Error.None)
    }

    testing.expect_value(t, v.drain(&journal, delivered[:]), 1)
    update, update_valid := rg.physics_effect_observation(delivered[0], effect_project)
    testing.expect(
        t,
        update_valid && update.kind == .Update && !update.confirmed && delivered[0].occurrence.value.impulse == 1,
    )
    testing.expect_value(t, v.advance_time(&journal, 6, 6), v.Error.None)
    testing.expect_value(t, v.drain(&journal, delivered[:]), 6)

    for item in delivered[:6] {
        observation, valid := rg.physics_effect_observation(item, effect_project)
        testing.expect(t, valid && observation.kind == .Confirm && observation.confirmed)
    }

    testing.expect_value(t, v.advance_time(&journal, 6, 6), v.Error.None)
    testing.expect_value(t, v.drain(&journal, delivered[:]), 0)
    testing.expect_value(t, v.journal_reset(&journal, 2, 0), v.Error.None)
    testing.expect_value(t, v.drain(&journal, delivered[:]), 6)

    for item in delivered[:6] {
        observation, valid := rg.physics_effect_observation(item, effect_project)
        testing.expect(t, valid && observation.kind == .Cancel && observation.id.epoch == 1)
    }

    r.destroy(&timeline)
    stats_before, bs := b.engine_allocation_stats()
    testing.expect_value(t, bs, b.Status.Ok)
    wrap_before, ws := b.snapshot_allocation_stats()
    testing.expect_value(t, ws, b.Status.Ok)

    for _ in 0 ..< 128 {
        _ = read_replay(t, &revised, 1)
    }

    stats_after, _ := b.engine_allocation_stats()
    wrap_after, _ := b.snapshot_allocation_stats()
    testing.expect(
        t,
        stats_before.total_calls == stats_after.total_calls && wrap_before.total_calls == wrap_after.total_calls,
    )
    r.complete_checkpoint_destroy(&cp)
    r.complete_checkpoint_destroy(&revised)
    // Detached copied presentation survives every native/checkpoint/Timeline owner.
    _, ve = p.present(&view, nil, &corrected, 1, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    testing.expect(t, changes[0].row.id.lifetime == 1)
}

@(test)
kit_actual_reconcile_rejected_gate_and_detached_epoch_pair :: proc(t: ^testing.T) {
    authority, client: Kit_Fixture
    testing.expect_value(t, kit_init(&authority, 3, 1), k.World_Error.Ok)
    testing.expect_value(t, kit_init(&client), k.World_Error.Ok)

    for _ in 0 ..< 4 {
        testing.expect_value(t, k.lane_frame(&authority.lane, 1.0 / 60), 1)
        testing.expect_value(t, k.lane_frame(&client.lane, 1.0 / 60), 1)
    }

    epoch := k.lane_world_epoch(&client.lane)
    cp4, ce := k.lane_world_checkpoint(&authority.lane, 4)
    testing.expect_value(t, ce, k.World_Error.Ok)

    for _ in 0 ..< 3 {
        _ = k.lane_frame(&authority.lane, 1.0 / 60)
        _ = k.lane_frame(&client.lane, 1.0 / 60)
    }

    old, e := k.lane_world_checkpoint(&client.lane, 7)
    testing.expect_value(t, e, k.World_Error.Ok)
    old_frame := read_kit(t, &old, epoch, 0)
    effects := client.effects
    gate := k.World_Commit_Gate {
        allow = proc(_: rawptr, _: u64) -> bool {
            return false
        },
    }
    testing.expect_value(t, k.lane_world_reconcile(&client.lane, &cp4, gate).error, k.World_Error.Rejected)
    unchanged, ue := k.lane_world_checkpoint(&client.lane, 7)
    testing.expect_value(t, ue, k.World_Error.Ok)
    same, se := k.world_checkpoint_equal(&old, &unchanged)
    testing.expect_value(t, se, k.World_Error.Ok)
    testing.expect(t, same && client.effects == effects)
    k.world_checkpoint_destroy(&unchanged)
    testing.expect_value(t, k.lane_world_reconcile(&client.lane, &cp4).error, k.World_Error.Ok)
    revised, re := k.lane_world_checkpoint(&client.lane, 7)
    testing.expect_value(t, re, k.World_Error.Ok)
    frame := read_kit(t, &revised, epoch, 1)
    testing.expect(t, old_frame.rows[0].pose.position.x != frame.rows[0].pose.position.x && client.effects == effects)
    testing.expect(t, client.last.confirmed && client.last.kind == .Committed)
    k.world_checkpoint_destroy(&cp4)
    k.world_checkpoint_destroy(&old)
    kit_destroy(&authority)
    kit_destroy(&client)
    // Captured epoch stays paired with the retained CP even after source Lane dies.
    detached := read_kit(t, &revised, epoch, 1)
    testing.expect_value(t, detached, frame)
    k.world_checkpoint_destroy(&revised)
    view: p.View
    out: [70]p.Change
    _, ve := p.present(&view, nil, &detached, 1, out[:])
    testing.expect_value(t, ve, p.Error.None)
}

@(test)
actual_recycled_native_index_and_complete_epoch_reset_rebind_proxy :: proc(t: ^testing.T) {
    seed, error := initial()
    ok(t, error)
    timeline: r.Timeline(Game, Input, Event)
    ok(t, r.init_complete(&timeline, &seed, replay_step, {128, 4}))
    before := read_replay(t, &seed, 0)
    ok(t, r.advance(&timeline, Input{replace = true}).error)
    replaced, e := r.capture_complete(&timeline, 1)
    ok(t, e)
    after := read_replay(t, &replaced, 0)
    // The engine reuses the actual body allocation index, but the game's lifetime
    // changes and its generation-certified key never becomes a visual identity.
    testing.expect(t, (u64(before.rows[0].body) & 0xffffffff) == (u64(after.rows[0].body) & 0xffffffff))
    testing.expect(t, before.rows[0].id.lifetime == 1 && after.rows[0].id.lifetime == 2)
    view: p.View
    changes: [70]p.Change
    _, ve := p.present(&view, nil, &before, 1, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    token := changes[0].token
    _, ve = p.present(&view, &before, &after, .5, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    testing.expect(
        t,
        changes[0].kind == .Rebind && changes[0].token.generation > token.generation && !changes[0].interpolated,
    )
    ok(t, r.reset_complete(&timeline, &seed, 2))
    reset, reset_error := r.capture_complete(&timeline, 0)
    ok(t, reset_error)
    epoch_frame := read_replay(t, &reset, 0)
    testing.expect(t, epoch_frame.epoch == 2 && epoch_frame.tick == 0)
    _, ve = p.present(&view, &after, &epoch_frame, .5, changes[:])
    testing.expect_value(t, ve, p.Error.None)
    testing.expect(t, changes[0].kind == .Remove && changes[1].kind == .Spawn && !changes[1].interpolated)
    r.complete_checkpoint_destroy(&seed)
    r.complete_checkpoint_destroy(&replaced)
    r.complete_checkpoint_destroy(&reset)
    r.destroy(&timeline)
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    testing.expect(
        t,
        es == .Ok &&
        ws == .Ok &&
        engine.live_bytes == 0 &&
        wrapper.live_bytes == 0 &&
        ph.allocation_stats().live_bytes == 0,
    )
}

project_calls: u32

counting_project :: proc(game: Game, out: []p.Binding) -> (u32, p.Error) {
    project_calls += 1
    return project(game, out)
}

@(test)
missing_and_invalid_owners_are_rejected_before_game_projection :: proc(t: ^testing.T) {
    missing: r.Complete_Checkpoint(Game, Event)
    _, ve, error := rg.physics_presentation_frame(&missing, counting_project)
    testing.expect(t, error == .Incomplete_State && ve == .None && project_calls == 0)
    // This malformed capability fails the existing public owner check before any
    // typed image/cache/Game access. No fake allocation/context is retained.
    invalid := r.Complete_Checkpoint(Game, Event) {
        owner = {realm = 9},
    }
    _, ve, error = rg.physics_presentation_frame(&invalid, counting_project)
    testing.expect(t, error != .None && project_calls == 0)
    kit_missing: k.World_Checkpoint
    _, kve, ke := kp.presentation_frame(&kit_missing, 1, Game, counting_project)
    testing.expect(t, ke != .Ok && kve == .None && project_calls == 0)
}

@(test)
status_and_impairment_helpers_observe_existing_public_contracts :: proc(t: ^testing.T) {
    lane_status := kp.presentation_status(
        1,
        8,
        4,
        k.World_Network_Status{ready = true, head = 8, confirmed = 4},
        k.World_Work_Stats{normal_latest_ns = 10, normal_peak_ns = 20},
    )
    testing.expect(
        t,
        lane_status.predicted_frontier_available &&
        !lane_status.accepted_frontier_available &&
        lane_status.normal_ns == 10,
    )
    latency, jitter, loss, ie := kp.presentation_impairment({latency_ms = 120, jitter_ms = 30, loss_permyriad = 200})
    testing.expect(t, ie == .None && latency == 120 && jitter == 30 && loss == 2)
    _, _, _, ie = kp.presentation_impairment({duplicate_permyriad = 1})
    testing.expect_value(t, ie, p.Error.Unsupported)
    session := new(rg.Session(Game, Input, Input, Event, 2))
    defer free(session)
    _, status_error := rg.physics_presentation_status(session)
    testing.expect_value(t, status_error, r.Error.Not_Initialized)
    session.ready = true
    session.authority = true
    session.server.cfg.epoch = 2
    session.server.timeline.head = 9
    session.server.timeline.confirmed = 9
    status, read_status := rg.physics_presentation_status(session)
    testing.expect(
        t,
        read_status == .None &&
        status.epoch == 2 &&
        status.accepted_frontier_available &&
        status.accepted_frontier == 9,
    )
    session.authority = false
    session.client.has_world = true
    session.client.phase = .Running
    session.client.cfg.epoch = 2
    session.client.cfg.max_prediction = 8
    session.client.timeline.head = 8
    session.client.timeline.confirmed = 4
    session.client.facts_contiguous = 12
    status, read_status = rg.physics_presentation_status(session)
    testing.expect(
        t,
        read_status == .None &&
        status.accepted_frontier == 12 &&
        status.accepted_frontier_available &&
        p.status_valid(status),
    )
    options, oe := rg.physics_impairment_options(
        rg.SESSION_OPTIONS,
        {latency_ms = 100, jitter_ms = 20, loss_permyriad = 100, duplicate_permyriad = 25, reorder = true},
    )
    testing.expect(
        t,
        oe == .None && options.latency_ms == 100 && options.jitter_ms == 20 && options.duplicate_permyriad == 25,
    )
    _, oe = rg.physics_impairment_options(options, {reorder = true})
    testing.expect_value(t, oe, p.Error.Unsupported)
}
