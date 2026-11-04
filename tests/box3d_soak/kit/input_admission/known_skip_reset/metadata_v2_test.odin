package known_skip_reset_test

// PURE actual-helper metadata controls, not Lane/Native/reset publication proof.
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import k "godot:kit/sim"
import legacy "godot:tests/box3d_slices/kit/intents"

metadata :: proc(rt: ^app.Runtime, world: ^k.World_History) {
    rt^ = {}
    rt.scripted = true
    rt.seat = 2
    rt.target = 300
    rt.ses.me = 2
    rt.generation = 200
    rt.intents.initialized = true
    rt.intents.armed = true
    rt.intents.active = 0
    rt.intents.plans[0] = {
        original = 40,
        due      = 40,
    }
    rt.lane.world = world
    world.epoch = 1
}

@(test)
pure_attempt_packet_and_publication_identities_are_pinned :: proc(t: ^testing.T) {
    rt := new(app.Runtime)
    defer free(rt)
    world := new(k.World_History)
    defer free(world)

    for mode in 0 ..< 9 {
        metadata(rt, world)
        rt.generation = u32(100 + mode)
        plan := &rt.intents.plans[0]

        switch mode {
        case 0:
            plan.attempted = true
            plan.attempt_tick = 41
            plan.attempt_head = 40 // aborted candidate
        case 1:
            plan.published = true
            plan.attempt_tick = 100 // published-only, outside old failure frontier
        case 2:
            plan.transported = true
        case 3:
            plan.attempt_tick = 41
        case 4:
            plan.attempt_head = 40
        case 5:
            plan.packet_head = 41
        case 6:
            plan.row_sequence = 41
        case 7:
            plan.attempted = true
            plan.published = true
            plan.transported = true
            plan.attempt_tick = 41
            plan.attempt_head = 40
            plan.packet_head = 41
            plan.row_sequence = 41
        case 8:
            plan.published = true // preserve old missing-packet failure at tick0
        }

        prior := plan^
        app.intent_rebase(rt, 40, 45, 14, 17)
        testing.expect(t, plan^ == prior, "No attempted/packet/publication identity may be retargeted")
        testing.expect(
            t,
            rt.failed == (mode == 7 || mode == 8),
            "Only existing published-without-packet failure applies",
        )
    }
}

@(test)
pure_multiple_pending_and_repeated_older_frontiers :: proc(t: ^testing.T) {
    rt := new(app.Runtime)
    defer free(rt)
    world := new(k.World_History)
    defer free(world)
    metadata(rt, world)
    rt.intents.plans[0].recovery_serial = 3
    rt.intents.plans[1] = {
        original        = 160,
        due             = 160,
        recovery_serial = 5,
    }
    rt.intents.plans[2] = {
        original = 280,
        due      = 280,
    }
    app.intent_rebase(rt, 180, 200, 7, 9)
    testing.expect(
        t,
        rt.intents.plans[0].original == 40 &&
        rt.intents.plans[0].due == 201 &&
        rt.intents.plans[0].recovery_serial == 9,
    )
    testing.expect(
        t,
        rt.intents.plans[1].original == 160 &&
        rt.intents.plans[1].due == 201 &&
        rt.intents.plans[1].recovery_serial == 9,
    )
    testing.expect(
        t,
        rt.intents.plans[2].original == 280 && rt.intents.plans[2].due == 280 && !rt.intents.plans[2].rebased,
    )
    testing.expect(t, rt.intents.active == 0 && rt.intents.armed && !rt.failed)
    before := rt.intents
    app.intent_rebase(rt, 200, 200, 9, 10)
    testing.expect(t, rt.intents == before)
    app.intent_rebase(rt, 200, 199, 10, 11)
    testing.expect(t, rt.intents == before)
    app.intent_rebase(rt, 203, 205, 11, 12)
    testing.expect(
        t,
        rt.intents.plans[0].due == 206 &&
        rt.intents.plans[1].due == 206 &&
        rt.intents.plans[0].original == 40 &&
        rt.intents.plans[1].original == 160,
    )
    testing.expect(t, !rt.intents.plans[0].attempted && !rt.intents.plans[1].attempted && !rt.failed)
}

@(test)
pure_future_and_irrelevant_plans_remain_unchanged :: proc(t: ^testing.T) {
    rt := new(app.Runtime)
    defer free(rt)
    world := new(k.World_History)
    defer free(world)
    metadata(rt, world)
    rt.intents.plans[0].due = 46
    rt.intents.plans[1] = {
        original = 0,
        due      = 0,
    } // no relevant scripted action
    before := rt.intents
    app.intent_rebase(rt, 40, 45, 14, 17)
    testing.expect(t, rt.intents == before && !rt.failed)
}

@(test)
pure_target_failure_and_checked_overflow :: proc(t: ^testing.T) {
    rt := new(app.Runtime)
    defer free(rt)
    world := new(k.World_History)
    defer free(world)
    metadata(rt, world)
    rt.target = 45
    app.intent_rebase(rt, 40, 45, 14, 17)
    testing.expect(
        t,
        rt.failed &&
        rt.intents.plans[0].original == 40 &&
        rt.intents.plans[0].due == 46 &&
        !rt.intents.plans[0].attempted,
    )
    metadata(rt, world)
    rt.target = 0
    prior := rt.intents
    app.intent_rebase(rt, 40, max(u64), 14, 17)
    testing.expect(t, rt.failed && rt.intents == prior, "Overflow must fail before any intent mutation")
}

@(test)
legacy_prefetch_abort_once :: proc(t: ^testing.T) {
    legacy.prefetch_never_emits_early_and_abort_keeps_same_attempt(t)
}

@(test)
legacy_reset_links_once :: proc(t: ^testing.T) {
    legacy.two_unsampled_reset_links_keep_original_due(t)
}

@(test)
legacy_published_identity_once :: proc(t: ^testing.T) {
    legacy.published_sample_without_packet_is_not_retargeted(t)
}

@(test)
legacy_end_once :: proc(t: ^testing.T) {
    legacy.no_tick_after_end_is_explicit_failure(t)
}

@(test)
legacy_catalog_once :: proc(t: ^testing.T) {
    legacy.fresh_source_catalog_does_not_recreate_retired_scenario_inputs(t)
}
