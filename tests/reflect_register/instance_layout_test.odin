package reflect_register_test

import "core:testing"
import rt "godot:runtime"
import gd "godot:godot"
import boot "godot:kit/boot"
import sess "godot:kit/session"
import comms "godot:kit/comms"

@(test)
private_instance_layout_and_recursion :: proc(t: ^testing.T) {
    A :: struct {
        owner:         gd.Node,
        first, second: i64,
    }

    B :: struct {
        owner:         gd.Node,
        second, first: i64,
    }

    C :: struct {
        owner:         gd.Node,
        first, second: i64,
    }

    RA :: struct {
        next:  ^RA,
        value: i64,
    }

    RB :: struct {
        next:  ^RB,
        value: i64,
    }

    Nested_A :: struct {
        value: []A,
    }

    Nested_B :: struct {
        value: []B,
    }

    Enum_A :: enum {
        One = 1,
        Two = 2,
    }

    Enum_B :: enum {
        One = 1,
        Two = 3,
    }

    testing.expect_value(t, size_of(A), size_of(B))
    testing.expect(t, rt.instance_layout_fingerprint(A) != 0)
    testing.expect(t, rt.instance_layout_fingerprint(A) != rt.instance_layout_fingerprint(B))
    testing.expect(t, rt.instance_layout_fingerprint(A) != rt.instance_layout_fingerprint(C))
    testing.expect(t, rt.instance_layout_fingerprint(RA) != rt.instance_layout_fingerprint(RB))
    testing.expect(t, rt.instance_layout_fingerprint(RA) != 0)

    Union_AB :: union {
        A,
        C,
    }

    Union_BA :: union {
        C,
        A,
    }

    testing.expect(t, rt.instance_layout_fingerprint(Union_AB) != rt.instance_layout_fingerprint(Union_BA))
    testing.expect(t, rt.instance_layout_fingerprint(Nested_A) != rt.instance_layout_fingerprint(Nested_B))
    testing.expect(t, rt.instance_layout_fingerprint(Enum_A) != rt.instance_layout_fingerprint(Enum_B))
    testing.expect(t, rt.instance_layout_fingerprint(i64) != rt.instance_layout_fingerprint(u64))
    testing.expect(
        t,
        rt.instance_layout_fingerprint(proc "c" (_: i32)) != rt.instance_layout_fingerprint(proc "c" (_: i64)),
    )
}

@(test)
standard_stack_has_complete_private_layout :: proc(t: ^testing.T) {
    Game :: struct {
        owner: gd.Node,
        boot:  boot.Boot,
        ses:   sess.Session,
        comms: comms.Comms,
    }

    Reordered :: struct {
        owner: gd.Node,
        boot:  boot.Boot,
        comms: comms.Comms,
        ses:   sess.Session,
    }

    testing.expect_value(t, size_of(Game), size_of(Reordered))
    testing.expect(t, rt.instance_layout_fingerprint(Game) != 0)
    testing.expect(t, rt.instance_layout_fingerprint(Game) != rt.instance_layout_fingerprint(Reordered))
}
