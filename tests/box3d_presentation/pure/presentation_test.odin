package presentation_test

import "core:math"
import "core:testing"
import p "godot:box3d/presentation"

frame :: proc(t: ^testing.T, epoch, tick, revision, life: u64, key: u64, x: f32) -> p.Frame {
    bindings := [1]p.Binding{{id = {1, life}, body = p.Body_Key(key), asset = 1, seat = 1, alive = true}}
    samples := [1]p.Body_Sample{{body = p.Body_Key(key), pose = {{x, 1, 2}, {0, 0, 0, 1}}, awake = true}}
    value, error := p.frame_make(epoch, tick, revision, .Predicted, bindings[:], samples[:])
    testing.expect_value(t, error, p.Error.None)
    return value
}

@(test)
interpolation_cuts_lifetimes_and_epoch_pool_identity :: proc(t: ^testing.T) {
    a := frame(t, 1, 3, 0, 7, 99, 0)
    b := frame(t, 1, 4, 0, 7, 99, 10)
    view: p.View
    changes: [p.MAX_CHANGES]p.Change
    n, error := p.present(&view, &a, &b, .25, changes[:])
    testing.expect_value(t, error, p.Error.None)
    testing.expect(
        t,
        n == 1 && changes[0].kind == .Spawn && changes[0].interpolated && changes[0].row.pose.position.x == 2.5,
    )
    token := changes[0].token
    // A complete correction at the SAME tick must cut old predicted interpolation.
    corrected := frame(t, 1, 4, 1, 7, 99, -20)
    _, error = p.present(&view, &b, &corrected, .5, changes[:])
    testing.expect_value(t, error, p.Error.None)
    testing.expect(t, !changes[0].interpolated && changes[0].row.pose.position.x == -20 && changes[0].token == token)
    // Recycled numerical body key still represents a distinct game lifetime.
    recycled := frame(t, 1, 5, 1, 8, 99, 30)
    _, error = p.present(&view, &corrected, &recycled, .1, changes[:])
    testing.expect_value(t, error, p.Error.None)
    testing.expect(
        t,
        changes[0].kind == .Rebind &&
        changes[0].previous.id.lifetime == 7 &&
        changes[0].row.id.lifetime == 8 &&
        changes[0].token.generation > token.generation &&
        !changes[0].interpolated,
    )
    // New epoch may begin at tick zero, never retaining a prior epoch proxy token.
    reset := frame(t, 2, 0, 0, 8, 99, 50)
    n, error = p.present(&view, &recycled, &reset, .3, changes[:])
    testing.expect_value(t, error, p.Error.None)
    testing.expect(
        t,
        n == 2 &&
        changes[0].kind == .Remove &&
        changes[1].kind == .Spawn &&
        !changes[1].interpolated &&
        changes[1].row.pose.position.x == 50,
    )
    snapshot := view
    _, error = p.present(&view, nil, &recycled, 0, changes[:])
    testing.expect_value(t, error, p.Error.Stale)
    testing.expect_value(t, view, snapshot)
}

@(test)
capacity_and_invalid_projection_preserve_existing_view_and_outputs :: proc(t: ^testing.T) {
    current := frame(t, 1, 0, 0, 1, 1, 0)
    view: p.View
    output: [p.MAX_CHANGES]p.Change
    output[0].row.id = {123, 456}
    saved := output
    n, error := p.present(&view, nil, &current, .5, output[:0])
    testing.expect(t, n == 1 && error == .Capacity && !view.ready)
    testing.expect_value(t, output, saved)
    _, error = p.present(&view, nil, &current, .5, output[:])
    testing.expect_value(t, error, p.Error.None)
    before := view
    old_output := output
    invalid := current
    invalid.rows[0].pose.rotation = {}
    _, error = p.present(&view, nil, &invalid, .5, output[:])
    testing.expect_value(t, error, p.Error.Invalid)
    testing.expect_value(t, view, before)
    testing.expect_value(t, output, old_output)
    n, error = p.view_clear(&view, output[:0])
    testing.expect(t, n == 1 && error == .Capacity)
    testing.expect_value(t, view, before)
    n, error = p.view_clear(&view, output[:])
    testing.expect(t, n == 1 && error == .None && !view.ready && output[0].kind == .Remove)
    // Builder cannot pair a live game binding with a different/cache-stale key.
    bindings := [1]p.Binding{{id = {1, 1}, body = 7, asset = 1, alive = true}}
    samples := [1]p.Body_Sample{{body = 8, pose = {{}, {0, 0, 0, 1}}}}
    _, build_error := p.frame_make(1, 0, 0, .Confirmed, bindings[:], samples[:])
    testing.expect_value(t, build_error, p.Error.Missing_Body)
}

@(test)
no_allocator_per_body_and_quaternion_hemisphere :: proc(t: ^testing.T) {
    bindings: [35]p.Binding
    samples: [35]p.Body_Sample

    for &binding, i in bindings {
        binding = {
            id    = {u64(i + 1), u64(i + 20)},
            body  = p.Body_Key(i + 1),
            asset = 1,
            alive = true,
        }
        samples[i] = {
            body = binding.body,
            pose = {{f32(i), 0, 0}, {0, 0, 0, 1}},
        }
    }

    a, error := p.frame_make(1, 0, 0, .Observed, bindings[:], samples[:])
    testing.expect_value(t, error, p.Error.None)

    for &sample in samples {
        sample.pose.position.x += 10
        sample.pose.rotation = {0, 0, 0, -1}
    }

    b, be := p.frame_make(1, 1, 0, .Observed, bindings[:], samples[:])
    testing.expect_value(t, be, p.Error.None)
    view: p.View
    out: [70]p.Change
    previous_context := context
    context.allocator = {}
    context.temp_allocator = {}
    n, pe := p.present(&view, &a, &b, .5, out[:])
    context = previous_context
    testing.expect(t, n == 35 && pe == .None)

    for change in out[:n] {
        testing.expect(t, change.interpolated && abs(change.row.pose.rotation.w) == 1)
    }

    // Independent copied values remain usable after all source scratch is cleared.
    a = {}
    bindings = {}
    samples = {}
    n, pe = p.present(&view, nil, &b, 1, out[:])
    testing.expect(t, n == 35 && pe == .None)
}

@(test)
status_and_effects_keep_unknown_frontiers_and_framework_semantics :: proc(t: ^testing.T) {
    unknown := p.Status {
        epoch        = 1,
        head         = 5,
        confirmed    = 4,
        ready        = true,
        repair_depth = 20,
        resync       = true,
        hold         = true,
    }
    testing.expect(t, p.status_valid(unknown) && !unknown.accepted_frontier_available && !unknown.complete_available)
    ahead := unknown
    ahead.accepted_frontier_available = true
    ahead.accepted_frontier = 100
    testing.expect(t, p.status_valid(ahead)) // accepted fact frontier may exceed held prediction
    committed := p.Effect_Observation {
        id        = {1, 4, 1, 9},
        game      = {3, 7},
        kind      = .Committed,
        confirmed = true,
    }
    testing.expect(t, p.effect_valid(committed))
    committed.confirmed = false
    testing.expect(t, !p.effect_valid(committed))
    committed.confirmed = true
    committed.game.lifetime = 0
    testing.expect(t, !p.effect_valid(committed))
    testing.expect(
        t,
        p.impairment_valid(
            {latency_ms = 120, jitter_ms = 30, loss_permyriad = 100, duplicate_permyriad = 25, reorder = true},
        ),
    )
    testing.expect(t, !p.impairment_valid({loss_permyriad = 10_001}))
}

@(test)
pooled_overlay_and_transport_capabilities_do_not_invent_frontiers :: proc(t: ^testing.T) {
    status := p.Status {
        epoch                  = 1,
        head                   = 5,
        confirmed              = 3,
        complete_solver_digest = 7,
        complete_available     = true,
        motion_digest          = 7,
        motion_available       = true,
    }
    bytes: [2048]u8
    n, error := p.status_text(status, bytes[:0])
    testing.expect(t, n > 0 && error == .Capacity)

    for &v in bytes {
        v = 0x7f
    }

    saved := bytes
    _, error = p.status_text(status, bytes[:4])
    testing.expect_value(t, error, p.Error.Capacity)
    testing.expect_value(t, bytes, saved)
    previous := context
    context.allocator = {}
    context.temp_allocator = {}
    actual, filled := p.status_text(status, bytes[:])
    context = previous
    testing.expect(t, actual == n && filled == .None)
    text := string(bytes[:actual])
    testing.expect(
        t,
        contains(text, "Accepted frontier unknown") &&
        contains(text, "Complete solver digest 7") &&
        contains(text, "motion-only digest 7") &&
        contains(text, "Motion is not complete equality") &&
        contains(text, "Tracked bytes unavailable"),
    )
    testing.expect_value(t, p.impairment_supported({duplicate_permyriad = 1}, {.Latency, .Loss}), p.Error.Unsupported)
}

contains :: proc(a, b: string) -> bool {
    if len(b) > len(a) {
        return false
    }

    limit := len(a) - len(b)

    for i in 0 ..= limit {
        if a[i:i + len(b)] == b {
            return true
        }
    }

    return false
}

@(test)
full_pool_replacement_and_raw_frame_quaternion_are_bounded :: proc(t: ^testing.T) {
    bindings: [35]p.Binding
    samples: [35]p.Body_Sample

    for &binding, i in bindings {
        binding = {
            id    = {u64(i + 1), 1},
            body  = p.Body_Key(i + 1),
            asset = 1,
            alive = true,
        }
        samples[i] = {
            body = binding.body,
            pose = {{f32(i), 0, 0}, {0, 0, 0, 1}},
        }
    }

    a, ae := p.frame_make(1, 0, 0, .Observed, bindings[:], samples[:])
    testing.expect_value(t, ae, p.Error.None)
    b := a
    b.epoch = 2
    b.rows[0].pose.rotation = {0, 0, 0, max(f32)}
    view: p.View
    changes: [70]p.Change
    _, error := p.present(&view, nil, &a, 1, changes[:])
    testing.expect_value(t, error, p.Error.None)
    old_view, old_output := view, changes
    n: u32
    n, error = p.present(&view, &a, &b, .5, changes[:69])
    testing.expect(t, n == 70 && error == .Capacity && view == old_view && changes == old_output)
    n, error = p.present(&view, &a, &b, .5, changes[:])
    testing.expect(t, n == 70 && error == .None)

    for change in changes[35:] {
        testing.expect(t, change.kind == .Spawn && !change.interpolated && change.row.pose.rotation.w == 1)
    }

    for change, i in changes[35:] {
        testing.expect(t, change.token.generation > old_output[i].token.generation)
    }
}
