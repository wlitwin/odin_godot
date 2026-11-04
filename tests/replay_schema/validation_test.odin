package replay_schema_test

import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"

Small_Set :: enum u8 {
    Zero = 0,
    Gap  = 7,
    Top  = 63,
}

High_Range :: enum u16 {
    First  = 1000,
    Second = 1001,
    Third  = 1002,
}

Sparse_Wide :: enum u64 {
    First  = 0x10000000000,
    Second = 0x10000000003,
}

Signed_Set :: enum i16 {
    Low   = -32768,
    Minus = -1,
    Zero  = 0,
    High  = 32767,
}

check_scalar :: proc(t: ^testing.T, $T: typeid, values: []u64, allowed: []bool) {
    codec: sc.Schema
    testing.expect_value(t, sc.init(&codec, T).error, sc.Error.None)
    defer sc.destroy(&codec)

    for value, i in values {
        bytes: [8]u8

        for j in 0 ..< codec.wire_size {
            bytes[j] = u8(value >> uint(j * 8))
        }

        decoded: T
        before := decoded
        report := sc.decode(&codec, &decoded, bytes[:codec.wire_size])
        testing.expect_value(t, report.error == .None, allowed[i])

        if !allowed[i] {
            testing.expect(t, reflect.equal(decoded, before))
        } else {
            encoded: [8]u8
            testing.expect_value(t, sc.encode(&codec, decoded, encoded[:codec.wire_size]).error, sc.Error.None)
            testing.expect_value(t, encoded, bytes)
        }
    }
}

@(test)
compiled_enum_checks_preserve_gaps_signed_values_and_wide_ranges :: proc(t: ^testing.T) {
    check_scalar(t, Small_Set, []u64{0, 1, 7, 62, 63, 64, 255}, []bool{true, false, true, false, true, false, false})
    check_scalar(
        t,
        High_Range,
        []u64{999, 1000, 1001, 1002, 1003, 65535},
        []bool{false, true, true, true, false, false},
    )
    check_scalar(
        t,
        Sparse_Wide,
        []u64{0, 0x10000000000, 0x10000000001, 0x10000000003, max(u64)},
        []bool{false, true, false, true, false},
    )
    check_scalar(t, Signed_Set, []u64{0, 1, 32767, 32768, 65534, 65535}, []bool{true, false, true, true, false, true})
}

@(test)
compiled_checks_preserve_supported_boolean_and_ieee_boundaries :: proc(t: ^testing.T) {
    check_scalar(t, b8, []u64{0, 1, 2, 255}, []bool{true, true, false, false})

    for kind in ([3]typeid{b16, b32, b64}) {
        codec: sc.Schema
        testing.expect_value(t, sc.init(&codec, kind).error, sc.Error.Unsupported_Type)
        sc.destroy(&codec)
    }

    check_scalar(
        t,
        f16,
        []u64{0, 0x8000, 0x7bff, 0x7c00, 0x7c01, 0xfc00},
        []bool{true, true, true, false, false, false},
    )
    check_scalar(
        t,
        f32,
        []u64{0, 0x80000000, 0x7f7fffff, 0x7f800000, 0x7f800001, 0xff800000},
        []bool{true, true, true, false, false, false},
    )
    check_scalar(
        t,
        f64,
        []u64{0, 0x8000000000000000, 0x7fefffffffffffff, 0x7ff0000000000000, 0x7ff0000000000001, 0xfff0000000000000},
        []bool{true, true, true, false, false, false},
    )
}

@(test)
late_check_failure_preserves_destination_and_first_field_path :: proc(t: ^testing.T) {
    Value :: struct #packed {
        flags:       [1024]bool,
        coordinates: [1024][2]f32be,
        mode:        High_Range,
    }

    codec: sc.Schema
    testing.expect_value(t, sc.init(&codec, Value).error, sc.Error.None)
    defer sc.destroy(&codec)
    value := Value {
        mode = .Second,
    }
    value.coordinates[1023] = {3.5, -7}
    bytes := make([]u8, codec.wire_size)
    defer delete(bytes)
    testing.expect_value(t, sc.encode(&codec, value, bytes).error, sc.Error.None)
    bad := make([]u8, len(bytes))
    defer delete(bad)
    copy(bad, bytes)

    for field in codec.fields {
        if field.path == "$.coordinates[1023][1]" {
            bad[field.wire_offset + 2] = 0x80
            bad[field.wire_offset + 3] = 0x7f
        }
    }

    decoded := value
    report := sc.decode(&codec, &decoded, bad)
    testing.expect_value(t, report.error, sc.Error.Invalid_Value)
    testing.expect_value(t, report.path, "$.coordinates[1023][1]")
    testing.expect(t, reflect.equal(decoded, value))
    bad[0] = 2
    report = sc.decode(&codec, &decoded, bad)
    testing.expect_value(t, report.path, "$.flags[0]")
}
