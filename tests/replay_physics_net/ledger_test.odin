package replay_physics_net_test

import "core:testing"
import "core:mem"
import net "godot:replay/net"
import r "godot:replay"
import sc "godot:replay/schema"
import bd "godot:box3d/diagnostics"

State :: struct {
    value: i64,
}

Control :: struct {
    axis: i16,
    edge: bool,
}

Action :: struct {
    value: i16,
}

model :: proc() -> net.Model(State, Control, Action, u8, 2) {
    return {
        step = proc(_: ^State, _: [2]Control, _: u64, _: u64, _: ^r.Step(u8)) {},
        action = proc(_: ^State, _: u16, _: Action, _: ^r.Step(u8)) -> bool {
            return true
        },
        control_valid = proc(c: Control) -> bool {
            return c.axis >= -100 && c.axis <= 100
        },
        action_valid = proc(a: Action) -> bool {
            return a.value >= 0 && a.value <= 10
        },
    }
}

entry :: proc(tick: u64) -> net.Accepted_Input(Control, Action, 2) {
    return {
        version = 1,
        epoch = 1,
        tick = tick,
        batch = {controls = {{axis = 1}, {axis = 2}}},
        decisions = {origins = {.Local, .Sample}, drivers = {{}, {generation = 2, serial = 3, incarnation = 4}}},
    }
}

@(test)
accepted_ledger_scopes_conflicts_and_wrap_are_bounded :: proc(t: ^testing.T) {
    ledger: net.Accepted_Ledger(Control, Action, 2)
    testing.expect_value(t, net.accepted_ledger_init(&ledger, 1, 0), net.Error.None)
    defer net.accepted_ledger_destroy(&ledger)
    value := entry(1)
    testing.expect(t, net.accepted_validate(value, model()))
    testing.expect_value(t, net.accepted_note(&ledger, value, 0, 8, 8), net.Error.None)
    testing.expect_value(t, net.accepted_note(&ledger, value, 1, 8, 8), net.Error.None) // identical settled repeat
    value.batch.controls[0].axis = 5
    testing.expect_value(t, net.accepted_note(&ledger, value, 0, 8, 8), net.Error.Invalid_Input)
    original, found := net.accepted_read(&ledger, 1)
    testing.expect(t, found && original.batch.controls[0].axis == 1)
    wrong_epoch := entry(2)
    wrong_epoch.epoch = 2
    testing.expect_value(t, net.accepted_note(&ledger, wrong_epoch, 0, 8, 8), net.Error.Invalid_Input)
    testing.expect_value(t, net.accepted_note(&ledger, entry(9), 0, 8, 8), net.Error.Invalid_Time)
    testing.expect_value(t, net.accepted_note(&ledger, entry(129), 0, 0, 129), net.Error.Invalid_Time)

    for tick in 2 ..= 140 {
        testing.expect_value(
            t,
            net.accepted_note(&ledger, entry(u64(tick)), u64(tick - 1), u64(tick), u64(tick)),
            net.Error.None,
        )
    }

    _, old := net.accepted_read(&ledger, 1)
    testing.expect(t, !old)
    latest, valid := net.accepted_read(&ledger, 140)
    testing.expect(t, valid && latest.tick == 140)
    _, other := net.accepted_read(&ledger, 139 + 128)
    testing.expect(t, !other)
}

@(test)
accepted_decisions_cover_inputs_and_action_verdicts :: proc(t: ^testing.T) {
    m := model()
    value := entry(1)
    value.batch.has_action[1] = true
    value.batch.actions[1] = {
        value = 3,
    }
    value.batch.sequences[1] = 1
    value.decisions.applied[1] = true
    testing.expect(t, net.accepted_validate(value, m))
    value.decisions.applied[1] = false
    testing.expect(t, !net.accepted_validate(value, m))
    value.decisions.verdicts[1] = .Predicate
    testing.expect(t, net.accepted_validate(value, m))
    value.batch.rejections[1] = .Invalid
    testing.expect(t, !net.accepted_validate(value, m))
    value.decisions.verdicts[1] = .Invalid
    value.batch.actions[1] = {
        value = -1,
    }
    testing.expect(t, net.accepted_validate(value, m)) // invalid action is recorded as rejected, never executed
    value.batch.controls[0].axis = 101
    testing.expect(t, !net.accepted_validate(value, m))
    value = entry(1)
    value.batch.prediction_seat = 1
    testing.expect(t, !net.accepted_validate(value, m))
    value = entry(1)
    value.decisions.drivers[1].serial = 0
    testing.expect(t, !net.accepted_validate(value, m))
}

@(test)
ledger_preflight_rejects_without_allocating :: proc(t: ^testing.T) {
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    ledger: net.Accepted_Ledger(Control, Action, 2)
    testing.expect_value(
        t,
        net.accepted_ledger_init(&ledger, 1, 0, 1, mem.tracking_allocator(&tracker)),
        net.Error.Capacity,
    )
    testing.expect_value(t, tracker.total_allocation_count, i64(0))
    testing.expect(t, len(ledger.entries) == 0)
}

@(test)
game_and_input_identity_bind_all_meanings_without_local_typeids :: proc(t: ^testing.T) {
    state, event, other_event, accepted, control, action, decisions: sc.Schema
    defer sc.destroy(&state)
    defer sc.destroy(&event)
    defer sc.destroy(&other_event)
    defer sc.destroy(&accepted)
    defer sc.destroy(&control)
    defer sc.destroy(&action)
    defer sc.destroy(&decisions)
    testing.expect_value(t, sc.init(&state, State).error, sc.Error.None)
    testing.expect_value(t, sc.init(&event, r.Occurrence(u8)).error, sc.Error.None)
    testing.expect_value(t, sc.init(&other_event, r.Occurrence(i8)).error, sc.Error.None)
    rules := bd.hash_bytes([]u8{1, 2, 3})
    first, error := net.complete_game_schema(&state, &event, rules)
    testing.expect_value(t, error, net.Error.None)
    changed, changed_error := net.complete_game_schema(&state, &other_event, rules)
    testing.expect_value(t, changed_error, net.Error.None)
    testing.expect(t, first != changed) // same-width event, different signed meaning
    new_rules, rules_error := net.complete_game_schema(&state, &event, bd.hash_bytes([]u8{1, 2, 4}))
    testing.expect_value(t, rules_error, net.Error.None)
    testing.expect(t, first != new_rules)
    _, missing := net.complete_game_schema(&state, &event, bd.Digest{})
    testing.expect_value(t, missing, net.Error.Invalid_Model)
    testing.expect_value(t, sc.init(&accepted, net.Accepted_Input(Control, Action, 2)).error, sc.Error.None)
    testing.expect_value(t, sc.init(&control, Control).error, sc.Error.None)
    testing.expect_value(t, sc.init(&action, Action).error, sc.Error.None)
    testing.expect_value(t, sc.init(&decisions, net.Accepted_Decisions(2)).error, sc.Error.None)
    input, input_error := net.complete_input_schema(&accepted, &control, &action, &decisions)
    testing.expect_value(t, input_error, net.Error.None)
    testing.expect(t, input != bd.Digest{})
}

@(test)
accepted_action_sequence_includes_last_lossless_event_key_value :: proc(t: ^testing.T) {
    m := model()
    value := entry(1)
    value.batch.has_action[1] = true
    value.batch.actions[1] = {
        value = 3,
    }
    value.decisions.applied[1] = true
    value.batch.sequences[1] = max(u64) >> 8
    testing.expect(t, net.accepted_validate(value, m))
    value.batch.sequences[1] += 1
    testing.expect(t, !net.accepted_validate(value, m))
}
