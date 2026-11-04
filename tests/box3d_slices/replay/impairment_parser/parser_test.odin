package replay_impairment_parser_test

import "core:testing"
import scene "godot:examples/replay_box3d/scripts"

@(test)
actual_scene_parser_checks_small_bound_before_arithmetic :: proc(t: ^testing.T) {
    bounds := [?]u64{1, 100, 10000}

    for bound in bounds {
        zero, ok := scene.slice_impairment_decimal_value("0", bound)
        testing.expect(t, ok)
        testing.expect_value(t, zero, u32(0))
        maximum := bound == 1 ? "1" : bound == 100 ? "100" : "10000"
        above := bound == 1 ? "2" : bound == 100 ? "101" : "10001"
        value, valid := scene.slice_impairment_decimal_value(maximum, bound)
        testing.expect(t, valid)
        testing.expect_value(t, value, u32(bound))
        _, too_big := scene.slice_impairment_decimal_value(above, bound)
        testing.expect(t, !too_big)
        invalid := [?]string {
            "18446744073709551615",
            "18446744073709551616",
            "99999999999999999999",
            "000000000000000000000",
            "-1",
            "+1",
            "1.0",
            "1e1",
            " 1",
            "1 ",
            "0x1",
            "1_0",
            "a",
            "",
        }

        for text in invalid {
            _, accepted := scene.slice_impairment_decimal_value(text, bound)
            testing.expect(t, !accepted)
        }

        leading, leading_ok := scene.slice_impairment_decimal_value("00000000000000000001", bound)
        testing.expect(t, leading_ok)
        testing.expect_value(t, leading, u32(1))
    }
}
