package definitions_test

import "core:math"
import "core:testing"
import d "godot:replay/definitions"

Definition :: struct {
    speed: f32,
    count: u16,
}

@(test)
versions_are_immutable_bounded_and_pinned_until_dependencies_retire :: proc(t: ^testing.T) {
    store: d.Store(Definition)
    assert(d.init(&store, 2).error == .None)
    defer d.destroy(&store)
    first, report := d.publish(&store, Definition{3, 4}, 1)
    testing.expect_value(t, report.error, d.Error.None)
    same, _ := d.publish(&store, Definition{3, 4}, 1)
    testing.expect_value(t, same, first)
    second, _ := d.publish(&store, Definition{5, 4}, 1)
    testing.expect(t, second != first)
    testing.expect_value(t, d.pin(&store, first), d.Error.None)
    testing.expect_value(t, d.remove(&store, first), d.Error.In_Use)
    testing.expect_value(t, d.destroy(&store), d.Error.In_Use)
    _, report = d.publish(&store, Definition{7, 4}, 1)
    testing.expect_value(t, report.error, d.Error.Capacity)
    value, found := d.get(&store, first)
    value.speed = 99
    original, _ := d.get(&store, first)
    testing.expect(t, found && original.speed == 3)
    testing.expect_value(t, d.unpin(&store, first), d.Error.None)
    testing.expect_value(t, d.remove(&store, first), d.Error.None)
    _, found = d.get(&store, first)
    testing.expect(t, !found)
    third, _ := d.publish(&store, Definition{3, 4}, 2)
    testing.expect(t, third != first && third.semantic == 2)
}

@(test)
bad_values_and_game_validation_publish_nothing_and_keep_owned_diagnostics :: proc(t: ^testing.T) {
    store: d.Store(Definition)
    assert(d.init(&store, 2).error == .None)
    defer d.destroy(&store)
    _, report := d.publish(&store, Definition{math.inf_f32(1), 4}, 1)
    testing.expect(t, report.error == .Schema && d.report_path(&report) == "$.speed")
    _, report = d.publish(&store, Definition{3, 4}, 1, proc(value: Definition) -> d.Report {
        return d.problem(.Invalid, "$.count", "too many")
    })
    testing.expect(t, report.error == .Invalid && d.report_message(&report) == "too many")

    for entry in store.entries {
        testing.expect(t, !entry.live)
    }

    bad: d.Store(string)
    report = d.init(&bad, 1)
    testing.expect_value(t, report.error, d.Error.Schema)
    testing.expect_value(t, d.destroy(&bad), d.Error.None)
    testing.expect(t, len(d.report_message(&report)) > 0)
}
