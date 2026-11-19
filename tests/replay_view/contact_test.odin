package replay_view_test

import "core:testing"
import v "godot:replay/view"
import sc "godot:replay/schema"

@(test)
contact_frames_retain_final_pose_and_cut_rounds_in_3d :: proc(t: ^testing.T) {
    a, b: v.Contact_Bodies(3, 2)
    a.group, b.group = 6, 6
    a.bodies[0] = {
        position = {1, 0, 0},
        life     = 8,
        visible  = true,
    }
    b.bodies[0] = {
        position          = {5, 0, 0},
        life              = 8,
        last_visible_tick = 12,
    }
    hit := v.Contact(3) {
        kind    = .Hit,
        group   = 6,
        subject = {0, 8, {4, 2, 0}},
        other   = v.Contact_Point(3){1, 1, {4, 3, 0}},
        retires = true,
    }
    p := v.contact_paths(&a, &b, 10, 14, 12, 0)
    v.contact_apply(&p, 12, hit)
    testing.expect_value(t, v.motion_sample(p.paths[0]).position, [3]f32{4, 2, 0})
    testing.expect_value(t, v.motion_sample(p.paths[1]).position, [3]f32{4, 3, 0})
    p = v.contact_paths(&a, &b, 10, 14, 13, 0)
    v.contact_apply(&p, 12, hit)
    testing.expect(t, !v.motion_sample(p.paths[0]).visible)
    replacement := v.Contact(3) {
        kind    = .Motion,
        group   = 6,
        subject = {0, 9, {8, 0, 0}},
    }
    v.contact_apply(&p, 13, replacement)
    testing.expect_value(t, v.motion_sample(p.paths[0]).life, u64(9))
    testing.expect(t, v.motion_sample(p.paths[0]).visible)
    b.group = 7; b.bodies[0] = {
        position = {40, 0, 0},
        life     = 1,
        visible  = true,
    }
    p = v.contact_paths(&a, &b, 10, 14, 13, .9)
    v.contact_apply(&p, 12, hit)
    testing.expect_value(t, v.motion_sample(p.paths[0]).position, a.bodies[0].position)
    p = v.contact_paths(&a, &b, 10, 14, 14, 0)
    v.contact_apply(&p, 14, hit)
    testing.expect_value(t, v.motion_sample(p.paths[0]).position, b.bodies[0].position)

    // The same declaration is a portable network event for games that choose it.
    codec: sc.Schema
    layout := sc.init(&codec, v.Contact(3))
    defer sc.destroy(&codec)
    testing.expect_value(t, layout.error, sc.Error.None)
    bytes := make([]u8, codec.wire_size); defer delete(bytes)
    decoded: v.Contact(3)
    testing.expect_value(t, sc.encode(&codec, hit, bytes).error, sc.Error.None)
    testing.expect_value(t, sc.decode(&codec, &decoded, bytes).error, sc.Error.None)
    testing.expect_value(t, decoded, hit)
}
