package authoring_test

import "core:strings"
import "core:testing"
import a "godot:authoring"
import gd "godot:godot"

Source :: struct {
    hp:      i64,
    speed:   f64,
    enabled: bool,
    mag:     u32,
    tint:    [4]f32,
}
Mechanism :: struct {
    mag: u16,
}
Row :: struct {
    health:    u8,
    speed:     f32,
    enabled:   bool,
    mechanism: Mechanism,
    tint:      [4]f32,
    name:      string,
}

@(test)
maps_checked_fields_without_taking_ownership :: proc(t: ^testing.T) {
    source := Source{120, 3.25, true, 500, {1, 0.5, 0, 1}}
    row := Row {
        name = "caller owns this",
    }
    report := a.map_fields(
        &source,
        &row,
        []a.Field {
            a.integer("hp", 1, 255, "health"),
            a.number("speed", 0, 100),
            a.field("enabled"),
            a.integer("mag", 1, 65535, "mechanism.mag"),
            a.field("tint"),
        },
        "res://mob.tres",
    )
    testing.expect_value(t, report.error, a.Error.None)
    testing.expect_value(t, row, Row{120, 3.25, true, {500}, {1, 0.5, 0, 1}, "caller owns this"})
}

@(test)
failures_preserve_the_entire_previous_value :: proc(t: ^testing.T) {
    before := Row{2, 8, false, {7}, {0, 0, 1, 1}, "admitted"}
    source := Source{120, 3.25, true, 500, {1, 0.5, 0, 1}}
    invalid := []a.Field {
        a.integer("mag", 1, 10, "mechanism.mag"),
        a.integer("hp", 0, 256, "health"), // Bad declaration even though 120 fits.
        a.integer("hp", 200, 100, "health"),
        a.integer("hp", -1, 10, "health"),
        a.field("hp", "health"), // Copy must not narrow.
        a.field("missing", "health"),
        a.field("enabled", "mechanism.missing"),
        a.number("hp", 0, 255, "health"),
        a.field("tint", "enabled"),
    }
    for bad in invalid {
        row := before
        report := a.map_fields(&source, &row, []a.Field{a.field("enabled"), bad}, "res://mob.tres")
        testing.expect_value(t, report.error, a.Error.Invalid)
        testing.expect_value(t, row, before)
        testing.expect(t, strings.has_prefix(a.report_path(&report), "res://mob.tres."))
        testing.expect(t, len(a.report_message(&report)) > 0)
    }
}

@(test)
rejects_aliases_and_owned_copies :: proc(t: ^testing.T) {
    source := Row {
        name      = "borrowed",
        mechanism = {50},
    }
    destination := Row {
        name      = "owned",
        mechanism = {20},
    }
    invalid := [][]a.Field {
        {a.field("mechanism"), a.field("mechanism.mag")},
        {a.field("mechanism.mag"), a.field("mechanism")},
        {a.field("enabled"), a.field("enabled")},
        {a.field("name")},
        {a.field("name.unknown")},
    }
    for fields in invalid {
        report := a.map_fields(&source, &destination, fields)
        testing.expect_value(t, report.error, a.Error.Invalid)
        testing.expect_value(t, destination.name, "owned")
        testing.expect_value(t, destination.mechanism.mag, u16(20))
    }
    Ref :: struct {
        value: ^i64,
    }
    n := i64(4)
    reference := Ref{&n}
    target: Ref
    testing.expect_value(t, a.map_fields(&reference, &target, []a.Field{a.field("value")}).error, a.Error.Invalid)
    testing.expect_value(
        t,
        a.map_fields(&reference, &target, []a.Field{a.integer("value.foo", 0, 10)}).error,
        a.Error.Invalid,
    )
}

@(test)
checks_nonfinite_overflow_and_integer_extremes :: proc(t: ^testing.T) {
    source := Source{}
    row := Row {
        speed = 5,
    }
    values := []f64{transmute(f64)u64(0x7ff0000000000000), transmute(f64)u64(0x7ff8000000000000), 1e100, -1}
    for value in values {
        source.speed = value
        report := a.map_fields(&source, &row, []a.Field{a.number("speed", 0, 1e200)})
        testing.expect_value(t, report.error, a.Error.Invalid)
        testing.expect_value(t, row.speed, f32(5))
    }
    Wide :: struct {
        value: u64,
    }
    wide := Wide{max(u64)}
    copied: Wide
    testing.expect_value(t, a.map_fields(&wide, &copied, []a.Field{a.field("value")}).error, a.Error.None)
    testing.expect_value(t, copied.value, max(u64))
    testing.expect_value(
        t,
        a.map_fields(&wide, &copied, []a.Field{a.integer("value", 0, max(i64))}).error,
        a.Error.Invalid,
    )
    Signed :: struct {
        value: i64,
    }
    signed := Signed{min(i64)}
    signed_copy: Signed
    testing.expect_value(
        t,
        a.map_fields(&signed, &signed_copy, []a.Field{a.integer("value", min(i64), max(i64))}).error,
        a.Error.None,
    )
    testing.expect_value(t, signed_copy.value, min(i64))
}

@(test)
reports_own_their_text_and_expose_truncation :: proc(t: ^testing.T) {
    path := strings.clone("res://test.tres.hp")
    report := a.problem(.Invalid, path, "outside bounds")
    delete(path)
    testing.expect_value(t, a.report_path(&report), "res://test.tres.hp")
    testing.expect_value(t, a.report_message(&report), "outside bounds")
    testing.expect(t, !report.truncated)
    large: [1100]u8
    for &byte in large {byte = 'x'}
    report = a.problem(.Invalid, string(large[:]), string(large[:]))
    testing.expect(t, report.truncated)
}

@(test)
rejects_opaque_engine_ownership_even_inside_value_wrappers :: proc(t: ^testing.T) {
    Label :: distinct gd.String
    Values :: struct {
        label:   Label,
        variant: gd.Variant,
        array:   gd.Typed_Array(gd.Int),
    }
    source, destination: Values
    paths := []string{"label", "label.opaque", "variant", "variant.opaque", "array", "array.untyped"}
    for path in paths {
        report := a.map_fields(&source, &destination, []a.Field{a.field(path)})
        testing.expect_value(t, report.error, a.Error.Invalid)
    }
}
