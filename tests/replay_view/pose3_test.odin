package replay_view_test

import "core:testing"
import "core:math"
import "core:math/linalg"
import v "godot:replay/view"

@(test)
quaternion_interpolation_uses_the_short_arc_and_preserves_equivalent_signs :: proc(t: ^testing.T) {
    a := [4]f32{0, math.sin(f32(89 * math.PI / 180)), 0, math.cos(f32(89 * math.PI / 180))}
    b := [4]f32{0, -a[1], 0, a[3]}
    middle := v.quat_blend(a, b, 0.5)
    testing.expect(t, abs(linalg.length(middle) - 1) < 0.00001)
    testing.expect(t, abs(middle[1]) > 0.999 && abs(middle[3]) < 0.001)
    identical := v.quat_blend(a, -a, 0.5)
    testing.expect(t, abs(linalg.dot(a, identical)) > 0.99999)
    cut := v.pose3_blend(v.Pose3{rotation = a}, v.Pose3{position = {2, 3, 4}, rotation = b}, 0.5, true)
    testing.expect_value(t, cut.position, [3]f32{2, 3, 4})
    testing.expect_value(t, cut.rotation, b)
}

@(test)
three_dimensional_skin_correction_does_not_change_truth :: proc(t: ^testing.T) {
    s: v.Smoother3
    start := v.Pose3 {
        rotation = {0, 0, 0, 1},
    }
    v.smooth3_present(&s, start, 0)
    truth := v.Pose3 {
        position = {0.5, 0.5, 0},
        rotation = {0, 0, 0, 1},
    }
    v.smooth3_correct(&s, start.position, truth.position)
    shown := v.smooth3_present(&s, truth, 0)
    testing.expect_value(t, shown.position, start.position)
    shown = v.smooth3_present(&s, truth, 0.08)
    testing.expect(t, linalg.length(shown.position - [3]f32{0.25, 0.25, 0}) < 0.00001)
    testing.expect_value(t, truth.position, [3]f32{0.5, 0.5, 0})
    v.smooth3_correct(&s, start.position, truth.position, discontinuity = true)
    testing.expect_value(t, v.smooth3_present(&s, truth, 0).position, truth.position)
}
