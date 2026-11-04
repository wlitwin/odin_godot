package confirmed_controls_test

// PURE producer controls. Synthetic Runtime/World_History metadata only;
// no initialized world, accepted-row injection, Lane step, Native or SDK proof.
import "core:encoding/json"
import "core:os"
import "core:testing"
import app "godot:examples/kit_box3d/scripts"
import common "godot:examples/box3d_common"
import k "godot:kit/sim"

fixture :: proc(generation: u32, target: u64) -> (^app.Runtime, ^k.World_History) {
    rt := new(app.Runtime)
    world := new(k.World_History)
    rt.role = .Client
    rt.generation = generation
    rt.model_ready = true
    rt.target = target
    rt.players = {1, 2}
    rt.lane.world = world
    world.epoch = 1
    rt.controls.value.local_bytes = 4
    return rt, world
}

unmodified_simulation :: proc(t: ^testing.T, rt: ^app.Runtime, world: ^k.World_History) {
    testing.expect(
        t,
        !rt.failed && rt.error == .Ok && world.status == .Ok && rt.lane.ticker.tick == 0 && rt.lane.ticker.acc == 0,
    )
    testing.expect(
        t,
        rt.caller_credit.pending_seconds == 0 &&
        rt.caller_credit.unresolved_offer_seconds == 0 &&
        !rt.intents.initialized,
    )
}

@(test)
actual_copy_preserves_zero_negative_extremes_and_owned_value :: proc(t: ^testing.T) {
    values := []common.Control{{0, 0}, {-100, 100}, {min(i16), max(i16)}, {max(i16), min(i16)}}
    origins := []k.World_Input_Origin{.Submitted, .Held, .Authority}
    copies: [12]struct {
        expected, actual: common.Control,
        origin:           k.World_Input_Origin,
        valid:            bool,
    }
    count := 0

    for expected in values {
        for origin in origins {
            source := expected
            bytes := (cast([^]u8)&source)[:size_of(source)]
            value, valid := app.confirmed_control_copy(4, bytes, .Ok, origin)
            testing.expect(t, valid && value == expected)
            bytes[0] = bytes[0] == 0 ? 1 : 0
            testing.expect(t, value == expected, "Copy must own typed value independently of borrowed bytes")
            copies[count] = {expected, value, origin, valid}
            count += 1
        }
    }

    testing.expect(t, count == 12 && size_of(common.Control) == 4)
    bytes, error := json.marshal(copies)
    testing.expect(t, error == nil)

    if error != nil {
        return
    }

    defer delete(bytes)
    testing.expect(t, os.write_entire_file("copy-controls.json", bytes) == nil)
}

@(test)
malformed_status_width_length_and_origin_never_validate :: proc(t: ^testing.T) {
    bytes: [5]u8
    statuses := []k.World_Error{.History_Missing, .Unsupported, .Rejected}

    for status in statuses {
        _, valid := app.confirmed_control_copy(4, bytes[:4], status, .Held)
        testing.expect(t, !valid)
    }

    widths := []int{0, 3, 5}

    for width in widths {
        _, valid := app.confirmed_control_copy(width, bytes[:4], .Ok, .Held)
        testing.expect(t, !valid)
    }

    lengths := []int{0, 3, 5}

    for length in lengths {
        _, valid := app.confirmed_control_copy(4, bytes[:length], .Ok, .Held)
        testing.expect(t, !valid)
    }

    origins := []k.World_Input_Origin{.Unknown, k.World_Input_Origin(4)}

    for origin in origins {
        _, valid := app.confirmed_control_copy(4, bytes[:4], .Ok, origin)
        testing.expect(t, !valid)
    }
}

@(test)
cursor_duplicates_gap_and_missing_checkpoint_are_explicit :: proc(t: ^testing.T) {
    rt, world := fixture(701, 10)
    defer free(rt)
    defer free(world)
    testing.expect(t, app.confirmed_control_advance(rt, 1))
    testing.expect(t, !app.confirmed_control_advance(rt, 1) && rt.control_evidence.duplicates_suppressed == 1)
    testing.expect(t, app.confirmed_control_advance(rt, 4) && rt.control_evidence.unavailable == 4)
    app.confirmed_control_missing_checkpoint(rt, 5, .History_Missing)
    testing.expect(
        t,
        rt.control_evidence.unavailable == 6 && rt.control_evidence.through == 5 && rt.control_evidence.emitted == 0,
    )
    app.confirmed_control_summary(rt)
    app.confirmed_control_summary(rt)
    testing.expect(t, rt.control_evidence.summary_emitted)
    unmodified_simulation(t, rt, world)
}

@(test)
unavailable_getter_is_bounded_STATUS_never_INPUT :: proc(t: ^testing.T) {
    rt, world := fixture(702, 100)
    defer free(rt)
    defer free(world)

    // Public getter returns Unsupported for this explicit nil-network metadata.
    // No private accepted ledger is created or forged for a positive row.
    for tick in 1 ..= 20 {
        app.confirmed_control_inputs(rt, u64(tick))
    }

    testing.expect(t, rt.control_evidence.emitted == 0 && rt.control_evidence.unavailable == 40)
    testing.expect(t, rt.control_evidence.unavailable_statuses == 8)
    app.confirmed_control_summary(rt)
    app.confirmed_control_summary(rt)
    unmodified_simulation(t, rt, world)
}

@(test)
synthetic_row_cap_and_absolute_target_cap_are_honest :: proc(t: ^testing.T) {
    rt, world := fixture(703, 65535)
    defer free(rt)
    defer free(world)
    app.confirmed_control_declare(rt)
    // Synthetic counter boundary only: this does NOT claim131070 actual rows.
    rt.control_evidence.emitted = app.CONTROL_EVIDENCE_MAX_ROWS
    rt.control_evidence.through = 65534
    app.confirmed_control_inputs(rt, 65535)
    testing.expect(t, rt.control_evidence.emitted == 131070 && rt.control_evidence.capped == 2)
    app.confirmed_control_summary(rt)
    unmodified_simulation(t, rt, world)
    over, over_world := fixture(704, 2)
    defer free(over)
    defer free(over_world)
    app.confirmed_control_inputs(over, 3)
    testing.expect(
        t,
        over.control_evidence.emitted == 0 &&
        over.control_evidence.capped == 2 &&
        over.control_evidence.unavailable == 4,
    )
    app.confirmed_control_summary(over)
    unmodified_simulation(t, over, over_world)
}

@(test)
invalid_changed_domains_summary_and_layout :: proc(t: ^testing.T) {
    for generation in 705 ..= 707 {
        rt, world := fixture(u32(generation), generation == 705 ? 0 : (generation == 706 ? 65536 : 2))

        if generation == 707 {
            app.confirmed_control_declare(rt)
            rt.target = 3
        } // synthetic observed-domain change

        app.confirmed_control_inputs(rt, 1)
        testing.expect(
            t,
            rt.control_evidence.domain_invalid &&
            rt.control_evidence.emitted == 0 &&
            rt.control_evidence.unavailable == 2,
        )
        app.confirmed_control_summary(rt)
        app.confirmed_control_summary(rt)
        unmodified_simulation(t, rt, world)
        free(rt)
        free(world)
    }

    bytes, error := json.marshal(struct {
        scope:                                     string,
        control_size, evidence_size, runtime_size: int,
    } {
        "PURE sizeof only; actual constructor Meter charge remains separate",
        size_of(common.Control),
        size_of(app.Confirmed_Control_Evidence),
        size_of(app.Runtime),
    })
    testing.expect(t, error == nil)

    if error != nil {
        return
    }

    defer delete(bytes)
    testing.expect(t, os.write_entire_file("layout.json", bytes) == nil)
}
