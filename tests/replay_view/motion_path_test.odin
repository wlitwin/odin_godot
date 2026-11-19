package replay_view_test

import "core:testing"
import v "godot:replay/view"

@(test)
turns_and_lifetimes_are_render_keys :: proc(t: ^testing.T) {
    Key :: v.Motion_Key(2)
    // The straight line between snapshots misses a turn at tick 12.
    a := Key{10, {0, 0}, 7, true}
    b := Key{14, {0, 0}, 7, true}
    for tick in u64(10) ..= 14 {
        p := v.motion_path(a, b, tick, 0)
        v.motion_key(&p, Key{12, {4, 0}, 7, true})
        draw := v.motion_sample(p)
        testing.expect_value(t, draw.position.x, f32(4) - 2 * abs(f32(tick) - 12))
    }
    p := v.motion_path(a, b, 12, .5)
    v.motion_key(&p, Key{12, {4, 0}, 7, true})
    v.motion_key(&p, Key{13, {4, 0}, 7, false})
    testing.expect_value(t, v.motion_sample(p).position.x, f32(4))
    p = v.motion_path(a, b, 13, 0)
    v.motion_key(&p, Key{13, {4, 0}, 7, false})
    testing.expect(t, !v.motion_sample(p).visible)
    p = v.motion_path(a, Key{14, {20, 0}, 8, true}, 13, .9)
    testing.expect_value(t, v.motion_sample(p), a)
    p = v.motion_path(Key{10, {}, 0, false}, b, 10, .9)
    v.motion_key(&p, Key{11, {8, 0}, 7, true})
    testing.expect(t, !v.motion_sample(p).visible)
}
